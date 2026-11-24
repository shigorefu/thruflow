# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "logger"
require "openssl"
require "pathname"
require "stringio"
require "time"

# The only Apple mutation is Profile.create for a missing NSE App Store profile.
# No match runner, certificate operation, capability edit or signing-repo write.
module NotificationProfileBootstrap
  class Error < StandardError; end

  TEAM = "BR727PS795"
  CERTIFICATE_ID = "YY8BUKDCAR"
  BUNDLE_ID = "com.shigorefu.thruflow.notifications"
  APP_GROUP = "group.com.shigorefu.thruflow"
  TARGETS = [
    { platform: "IOS", decoded_platforms: %w[iOS xrOS visionOS], required_platform: "iOS",
      type: "IOS_APP_STORE", name: "match AppStore #{BUNDLE_ID}",
      identifier_key: "application-identifier", file: "AppStore_#{BUNDLE_ID}.mobileprovision" },
    { platform: "MAC_OS", decoded_platforms: ["OSX"], required_platform: "OSX",
      type: "MAC_APP_STORE", name: "match AppStore #{BUNDLE_ID} macos",
      identifier_key: "com.apple.application-identifier", file: "AppStore_#{BUNDLE_ID}.provisionprofile" }
  ].freeze

  def self.guard!(env)
    unless env["GITHUB_ACTIONS"] == "true" && env["GITHUB_EVENT_NAME"] == "workflow_dispatch" &&
           env["GITHUB_REF"] == "refs/heads/main" && env["GITHUB_REPOSITORY"] == "shigorefu/thruflow"
      raise Error, "Bootstrap requires manual execution on this repository's main branch"
    end
    raise Error, "Unexpected Apple team" unless env["APPLE_TEAM_ID"] == TEAM
    %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT_BASE64 MATCH_PASSWORD].each do |key|
      raise Error, "Missing #{key}" if env[key].to_s.empty?
    end
    if %w[SPACESHIP_DEBUG SPACESHIP_PROXY SPACESHIP_PROXY_SSL_VERIFY_NONE DEBUG VERBOSE].any? { |key| !env[key].to_s.empty? }
      raise Error, "Spaceship debug, verbose and proxy overrides must be disabled"
    end
  end

  def self.stage(label)
    yield
  rescue Error
    raise
  rescue StandardError => error
    # API exceptions may contain response bodies. Never echo their messages.
    raise Error, "#{label} failed (#{error.class.name})"
  end

  def self.decode64(value)
    raise Error, "Missing or oversized profile/certificate data" unless value.is_a?(String) && value.bytesize.between?(1, 2_000_000)
    Base64.strict_decode64(value.gsub(/\s+/, ""))
  rescue ArgumentError
    raise Error, "Invalid profile/certificate encoding"
  end

  def self.decode_profile(bytes)
    require "plist"
    stage("Signed profile decoding") do
      cms = OpenSSL::PKCS7.new(bytes)
      # NOVERIFY skips chain trust lookup, not the cryptographic CMS signature.
      unless cms.type == :signed && cms.verify([], OpenSSL::X509::Store.new, nil, OpenSSL::PKCS7::NOVERIFY)
        raise Error, "Profile CMS signature is invalid"
      end
      document = Plist.parse_xml(StringIO.new(cms.data), marshal: false)
      raise Error, "Profile is not a plist dictionary" unless document.is_a?(Hash)
      document
    end
  end

  def self.expiry(value)
    value.respond_to?(:to_time) ? value.to_time.utc : Time.parse(value.to_s).utc
  rescue ArgumentError
    raise Error, "Invalid expiration metadata"
  end

  def self.validate_certificate!(certificate, now)
    unless certificate[:id] == CERTIFICATE_ID && certificate[:type] == "DISTRIBUTION" && expiry(certificate[:expires]) > now
      raise Error, "Expected existing, unexpired Apple Distribution certificate"
    end
    bytes = decode64(certificate[:content])
    parsed = stage("Certificate metadata decoding") { OpenSSL::X509::Certificate.new(bytes) }
    subject = parsed.subject.to_a
    unless subject.select { |key, _, _| key == "OU" }.map { |_, value, _| value } == [TEAM] &&
           subject.any? { |key, value, _| key == "CN" && value.start_with?("Apple Distribution:") } &&
           parsed.not_before <= now && parsed.not_after > now
      raise Error, "Certificate team, class or validity does not match"
    end
    # Fastlane 2.241.1 accepts unified DISTRIBUTION for both App Store platforms.
    bytes
  end

  def self.bundle_for!(bundles, target)
    candidates = bundles.select do |bundle|
      bundle[:identifier] == BUNDLE_ID && bundle[:seed] == TEAM &&
        [target[:platform], "UNIVERSAL"].include?(bundle[:platform])
    end
    exact = candidates.select { |bundle| bundle[:platform] == target[:platform] }
    candidates = exact unless exact.empty?
    raise Error, "Expected one existing NSE bundle registration for #{target[:platform]}" unless candidates.length == 1
    candidates.first
  end

  def self.validate_profile!(profile, target, certificate_bytes, now, decoder)
    unless profile[:type] == target[:type] && profile[:platform] == target[:platform] &&
           profile[:state] == "ACTIVE" && expiry(profile[:expires]) > now &&
           profile[:identifier] == BUNDLE_ID && profile[:certificate_ids] == [CERTIFICATE_ID]
      raise Error, "Conflicting or invalid #{target[:platform]} NSE App Store profile"
    end
    bytes = decode64(profile[:content])
    document = decoder.call(bytes)
    rights = document["Entitlements"]
    platforms = document["Platform"]
    unless rights.is_a?(Hash) && platforms.is_a?(Array) && platforms.include?(target[:required_platform]) &&
           (platforms - target[:decoded_platforms]).empty? && document["TeamIdentifier"] == [TEAM] &&
           document["ApplicationIdentifierPrefix"] == [TEAM] && expiry(document["ExpirationDate"]) > now &&
           rights["com.apple.developer.team-identifier"] == TEAM &&
           rights[target[:identifier_key]] == "#{TEAM}.#{BUNDLE_ID}"
      raise Error, "Decoded profile team, identifier, platform or expiry mismatch"
    end
    %w[application-identifier com.apple.application-identifier].each do |key|
      if rights.key?(key) && rights[key] != "#{TEAM}.#{BUNDLE_ID}"
        raise Error, "Conflicting profile application identifier"
      end
    end
    if document.key?("ProvisionedDevices") || document.fetch("ProvisionsAllDevices", false) != false ||
       %w[get-task-allow com.apple.security.get-task-allow].any? { |key| rights.fetch(key, false) != false }
      raise Error, "Device-bound, enterprise or development profile is not permitted"
    end
    groups = rights["com.apple.security.application-groups"]
    allowed_groups = target[:platform] == "MAC_OS" ? [APP_GROUP, "#{TEAM}.*"] : [APP_GROUP]
    unless groups.is_a?(Array) && groups.include?(APP_GROUP) && (groups - allowed_groups).empty?
      raise Error, "Profile App Group does not match the NSE"
    end
    if rights.keys.any? { |key| key.include?("icloud") || key.include?("ubiquity") || key.include?("aps-environment") }
      raise Error, "Unexpected CloudKit or push entitlement in NSE profile"
    end
    certificates = document["DeveloperCertificates"]
    embedded = certificates&.first
    embedded = embedded.string if embedded.is_a?(StringIO)
    unless certificates.is_a?(Array) && certificates.length == 1 && embedded.is_a?(String) &&
           embedded.b == certificate_bytes.b
      raise Error, "Profile embeds a different distribution certificate"
    end
    bytes
  end

  def self.encrypt_profile(bytes, password)
    require "match/encryption/encryption"
    crypto = Match::Encryption::MatchDataEncryption.new
    encrypted = crypto.encrypt(data: bytes, password: password, version: 2)
    unless decode64(encrypted).start_with?("match_encrypted_v2__") &&
           crypto.decrypt(base64encoded_encrypted: encrypted, password: password) == bytes
      raise Error, "Match v2 encryption verification failed"
    end
    encrypted
  end

  def self.run(env:, output_dir:, api: nil, now: Time.now.utc, decoder: method(:decode_profile), encryptor: method(:encrypt_profile))
    guard!(env)
    output = Pathname.new(output_dir).expand_path
    if output.symlink? || (output.exist? && (!output.directory? || !output.children.empty?))
      raise Error, "Ciphertext output directory must be empty and not a symlink"
    end
    api ||= stage("ASC authentication") { AppleAPI.new(env) }
    certificate = stage("Certificate lookup") { api.certificate }
    certificate_bytes = validate_certificate!(certificate, now)
    bundles = stage("Bundle registration lookup") { api.bundles }
    profiles = stage("Existing profile lookup") { api.profiles }
    if profiles.any? { |profile| profile[:identifier].to_s.empty? }
      raise Error, "Existing profile bundle relationship metadata is incomplete"
    end
    # Inspect both platforms before the first mutation; conflicts never trigger renewal.
    plan = TARGETS.map do |target|
      bundle = bundle_for!(bundles, target)
      existing = profiles.select { |profile| profile[:identifier] == BUNDLE_ID && profile[:type] == target[:type] }
      raise Error, "Multiple existing #{target[:platform]} NSE App Store profiles" if existing.length > 1
      bytes = validate_profile!(existing.first, target, certificate_bytes, now, decoder) unless existing.empty?
      { target: target, bundle: bundle, profile: existing.first, bytes: bytes }
    end
    build_status = stage("Build metadata lookup") { api.existing_builds }
    report = []
    ciphertexts = plan.to_h do |item|
      target = item[:target]
      profile = item[:profile] || stage("#{target[:platform]} profile creation") { api.create_profile(target, item[:bundle]) }
      bytes = item[:bytes] || validate_profile!(profile, target, certificate_bytes, now, decoder)
      encrypted = stage("Profile encryption") { encryptor.call(bytes, env.fetch("MATCH_PASSWORD")) }
      unless encrypted.is_a?(String) && decode64(encrypted).start_with?("match_encrypted_v2__")
        raise Error, "Only Match v2 ciphertext may be written"
      end
      report << { platform: target[:platform], profile_type: target[:type], profile_id: profile[:id],
                  certificate_id: CERTIFICATE_ID, action: item[:profile] ? "reused" : "created" }
      [target[:file], encrypted]
    end
    # No plaintext profile, certificate or API key is written to disk.
    FileUtils.mkdir_p(output, mode: 0o700)
    written = []
    begin
      ciphertexts.each do |name, bytes|
        path = output.join(name)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(bytes) }
        written << path
      end
      unless output.children.map { |path| path.basename.to_s }.sort == TARGETS.map { |target| target[:file] }.sort
        raise Error, "Unexpected file in ciphertext output"
      end
    rescue StandardError
      written.each(&:delete)
      raise
    end
    { profiles: report, existing_build_16: build_status }
  end

  class AppleAPI
    def initialize(env)
      require "spaceship"
      token = Spaceship::ConnectAPI::Token.create(key_id: env.fetch("ASC_KEY_ID"), issuer_id: env.fetch("ASC_ISSUER_ID"),
        key: env.fetch("ASC_KEY_CONTENT_BASE64"), is_key_content_base64: true, duration: 1200, in_house: false)
      @client = Spaceship::ConnectAPI::Client.new(token: token)
      # Spaceship otherwise persists complete API request/response bodies to /tmp.
      logger = Logger.new(File::NULL)
      %i[provisioning_request_client test_flight_request_client tunes_request_client users_request_client].each do |name|
        @client.public_send(name).logger = logger
      end
    end

    def certificate
      model = Spaceship::ConnectAPI::Certificate.get(client: @client, certificate_id: CERTIFICATE_ID)
      { id: model.id, type: model.certificate_type, platform: model.platform,
        expires: model.expiration_date, content: model.certificate_content }
    end

    def bundles
      Spaceship::ConnectAPI::BundleId.all(client: @client, filter: { identifier: BUNDLE_ID }).map do |model|
        { id: model.id, identifier: model.identifier, platform: model.platform, seed: model.seed_id }
      end
    end

    def profiles(id: nil)
      filter = id ? { id: id } : { profileType: TARGETS.map { |target| target[:type] }.join(",") }
      Spaceship::ConnectAPI::Profile.all(client: @client, filter: filter, includes: "bundleId,certificates").map do |model|
        { id: model.id, identifier: model.bundle_id&.identifier, type: model.profile_type,
          platform: model.platform, state: model.profile_state, expires: model.expiration_date,
          certificate_ids: Array(model.certificates).map(&:id), content: model.profile_content }
      end
    end

    def create_profile(target, bundle)
      model = Spaceship::ConnectAPI::Profile.create(client: @client, name: target[:name], profile_type: target[:type],
        bundle_id_id: bundle[:id], certificate_ids: [CERTIFICATE_ID], device_ids: nil)
      4.times do |attempt|
        profile = profiles(id: model.id).find { |candidate| candidate[:id] == model.id }
        return profile if profile
        sleep(1) if attempt < 3
      end
      raise Error, "Created profile metadata is not available; rerun to reuse it"
    end

    def existing_builds
      models = Spaceship::ConnectAPI::Build.all(client: @client, app_id: "6798609191", version: "1.5.0",
        build_number: "16", includes: "preReleaseVersion", limit: 200)
      { status: "checked", builds: models.map do |model|
        { platform: model.pre_release_version&.platform, version: model.pre_release_version&.version,
          build: model.version, processing_state: model.processing_state }
      end }
    rescue StandardError
      { status: "unavailable", builds: nil }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    result = NotificationProfileBootstrap.run(env: ENV, output_dir: ARGV.fetch(0, "build/signing-profiles"))
    puts(JSON.generate(result))
  rescue StandardError => error
    message = error.is_a?(NotificationProfileBootstrap::Error) ? error.message : "Bootstrap failed (#{error.class.name})"
    warn(message)
    exit(1)
  end
end
