# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "tmpdir"
require "yaml"
require_relative "../lib/notification_profile_bootstrap"

class NotificationProfileBootstrapTest < Minitest::Test
  Bootstrap = NotificationProfileBootstrap
  NOW = Time.utc(2026, 11, 25, 0, 0, 0)

  def self.signer
    @signer ||= begin
      # Disposable, in-memory CMS fixture; never contacts Apple or exports a key.
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.parse("/CN=Apple Distribution: Isolated Fixture/OU=#{Bootstrap::TEAM}")
      cert.issuer = cert.subject
      cert.public_key = key.public_key
      cert.not_before = NOW - 60
      cert.not_after = NOW + 86_400
      cert.sign(key, OpenSSL::Digest::SHA256.new)
      [key, cert]
    end
  end

  def environment
    { "GITHUB_ACTIONS" => "true", "GITHUB_EVENT_NAME" => "workflow_dispatch",
      "GITHUB_REF" => "refs/heads/main", "GITHUB_REPOSITORY" => "shigorefu/thruflow",
      "APPLE_TEAM_ID" => Bootstrap::TEAM, "ASC_KEY_ID" => "fixture",
      "ASC_ISSUER_ID" => "fixture", "ASC_KEY_CONTENT_BASE64" => "fixture",
      "MATCH_PASSWORD" => "isolated-test-password" }
  end

  def setup
    @certificate_bytes = self.class.signer.last.to_der
    @certificate = { id: Bootstrap::CERTIFICATE_ID, type: "DISTRIBUTION", platform: nil,
      expires: (NOW + 3600).iso8601, content: Base64.strict_encode64(@certificate_bytes) }
    @documents = {}
    @profiles = Bootstrap::TARGETS.map.with_index do |target, index|
      bytes = "isolated-profile-#{index}"
      groups = [Bootstrap::APP_GROUP]
      groups << "#{Bootstrap::TEAM}.*" if target[:platform] == "MAC_OS"
      @documents[bytes] = {
        "TeamIdentifier" => [Bootstrap::TEAM], "ApplicationIdentifierPrefix" => [Bootstrap::TEAM],
        "Platform" => target[:decoded_platforms], "ExpirationDate" => NOW + 3600,
        "DeveloperCertificates" => [@certificate_bytes], "Entitlements" => {
          target[:identifier_key] => "#{Bootstrap::TEAM}.#{Bootstrap::BUNDLE_ID}",
          "com.apple.developer.team-identifier" => Bootstrap::TEAM,
          "com.apple.security.application-groups" => groups, "get-task-allow" => false }
      }
      { id: "profile-#{index}", identifier: Bootstrap::BUNDLE_ID, type: target[:type],
        platform: target[:platform], state: "ACTIVE", expires: (NOW + 3600).iso8601,
        certificate_ids: [Bootstrap::CERTIFICATE_ID], content: Base64.strict_encode64(bytes) }
    end
    @api = FakeAPI.new(@certificate, @profiles)
  end

  def run_in(directory, **options)
    Bootstrap.run(env: environment, output_dir: directory, api: @api, now: NOW,
      decoder: ->(bytes) { @documents.fetch(bytes) }, **options)
  end

  def test_guard_rejects_nonmanual_nonmain_wrong_repository_and_missing_secrets
    { "GITHUB_ACTIONS" => "false", "GITHUB_EVENT_NAME" => "push", "GITHUB_REF" => "refs/heads/other",
      "GITHUB_REPOSITORY" => "other/repo", "APPLE_TEAM_ID" => "OTHERTEAM00", "MATCH_PASSWORD" => "",
      "ASC_KEY_CONTENT_BASE64" => "", "SPACESHIP_DEBUG" => "1", "VERBOSE" => "1",
      "DEBUG" => "1", "SPACESHIP_PROXY" => "https://proxy.invalid", "SPACESHIP_PROXY_SSL_VERIFY_NONE" => "1" }.each do |key, value|
      assert_raises(Bootstrap::Error) { Bootstrap.guard!(environment.merge(key => value)) }
    end
  end

  def test_existing_valid_profiles_are_reused_and_only_two_v2_ciphertexts_are_written
    Dir.mktmpdir do |directory|
      result = run_in(directory)
      assert_empty @api.created
      assert_equal %w[reused reused], result[:profiles].map { |item| item[:action] }
      assert_equal Bootstrap::TARGETS.map { |target| target[:file] }.sort, Dir.children(directory).sort
      require "match/encryption/encryption"
      crypto = Match::Encryption::MatchDataEncryption.new
      Bootstrap::TARGETS.each_with_index do |target, index|
        content = File.read(File.join(directory, target[:file]))
        assert Base64.decode64(content).start_with?("match_encrypted_v2__")
        assert_equal "isolated-profile-#{index}", crypto.decrypt(base64encoded_encrypted: content, password: environment["MATCH_PASSWORD"])
        assert_equal 0o600, File.stat(File.join(directory, target[:file])).mode & 0o777
      end
    end
  end

  def test_missing_profiles_create_only_exact_two_types_for_existing_nse_and_certificate
    @api.existing = []
    Dir.mktmpdir do |directory|
      result = run_in(directory)
      assert_equal %w[created created], result[:profiles].map { |item| item[:action] }
      assert_equal Bootstrap::TARGETS.map { |target| target[:type] }, @api.created.map { |item| item[:type] }
      assert @api.created.all? { |item| item[:bundle][:identifier] == Bootstrap::BUNDLE_ID && item[:bundle][:seed] == Bootstrap::TEAM }
    end
  end

  def test_conflicting_existing_profile_aborts_before_creating_missing_other_platform
    @api.existing = [@profiles.first.merge(certificate_ids: ["OTHER"])]
    Dir.mktmpdir do |directory|
      assert_raises(Bootstrap::Error) { run_in(directory) }
      assert_empty @api.created
      assert_empty Dir.children(directory)
    end
  end

  def test_wrong_certificate_type_id_team_or_expiry_cannot_trigger_profile_creation
    [@certificate.merge(id: "OTHER"), @certificate.merge(type: "DEVELOPMENT"),
     @certificate.merge(expires: (NOW - 1).iso8601)].each do |certificate|
      assert_raises(Bootstrap::Error) { Bootstrap.validate_certificate!(certificate, NOW) }
    end
    assert_raises(Bootstrap::Error) { Bootstrap.validate_certificate!(@certificate, NOW + 86_401) }
  end

  def test_distribution_validation_rejects_devices_development_wrong_platform_and_capability_widening
    original = Marshal.dump(@documents)
    mutations = [
      ->(doc) { doc["ProvisionedDevices"] = [] }, ->(doc) { doc["ProvisionsAllDevices"] = true },
      ->(doc) { doc["TeamIdentifier"] = ["OTHERTEAM00"] }, ->(doc) { doc["Platform"] = ["OSX"] },
      ->(doc) { doc["ExpirationDate"] = NOW - 1 },
      ->(doc) { doc["DeveloperCertificates"] = ["different-public-certificate"] },
      ->(doc) { doc["Entitlements"]["get-task-allow"] = true },
      ->(doc) { doc["Entitlements"]["application-identifier"] = "#{Bootstrap::TEAM}.other" },
      ->(doc) { doc["Entitlements"]["com.apple.security.application-groups"] = ["unrelated"] },
      ->(doc) { doc["Entitlements"]["com.apple.developer.icloud-services"] = ["CloudKit"] },
      ->(doc) { doc["Entitlements"]["aps-environment"] = "production" }
    ]
    mutations.each do |mutate|
      @documents = Marshal.load(original)
      mutate.call(@documents.fetch("isolated-profile-0"))
      Dir.mktmpdir do |directory|
        assert_raises(Bootstrap::Error) { run_in(directory) }
        assert_empty @api.created
        assert_empty Dir.children(directory)
      end
    end
  end

  def test_macos_uses_its_identifier_key_and_rejects_unrelated_group_or_ios_platform
    target = Bootstrap::TARGETS.last
    bytes = Base64.decode64(@profiles.last[:content])
    doc = @documents.fetch(bytes)
    assert Bootstrap.validate_profile!(@profiles.last, target, @certificate_bytes, NOW, ->(_) { doc })
    original = Marshal.dump(doc)
    doc["Entitlements"]["com.apple.security.application-groups"] << "other.group"
    assert_raises(Bootstrap::Error) { Bootstrap.validate_profile!(@profiles.last, target, @certificate_bytes, NOW, ->(_) { doc }) }
    doc = Marshal.load(original)
    doc["Platform"] = ["iOS"]
    assert_raises(Bootstrap::Error) { Bootstrap.validate_profile!(@profiles.last, target, @certificate_bytes, NOW, ->(_) { doc }) }
    doc = Marshal.load(original)
    doc["Entitlements"]["application-identifier"] = doc["Entitlements"].delete("com.apple.application-identifier")
    assert_raises(Bootstrap::Error) { Bootstrap.validate_profile!(@profiles.last, target, @certificate_bytes, NOW, ->(_) { doc }) }
  end

  def test_later_creation_failure_produces_no_partial_artifact
    @api.existing = []
    @api.fail_macos = true
    Dir.mktmpdir do |directory|
      error = assert_raises(Bootstrap::Error) { run_in(directory) }
      refute_includes error.message, "sensitive-fixture-response"
      assert_empty Dir.children(directory)
    end
  end

  def test_output_refuses_stale_files_symlinks_and_plaintext_encryption_results
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "unexpected"), "existing")
      assert_raises(Bootstrap::Error) { run_in(directory) }
      File.delete(File.join(directory, "unexpected"))
      assert_raises(Bootstrap::Error) { run_in(directory, encryptor: ->(bytes, _) { bytes }) }
      assert_empty Dir.children(directory)
      link = "#{directory}-link"
      File.symlink(directory, link)
      begin
        assert_raises(Bootstrap::Error) { run_in(link) }
      ensure
        File.delete(link)
      end
    end
  end

  def test_cms_signature_decoding_keeps_binary_certificate_in_memory_and_rejects_tampering
    require "plist"
    xml = %(<?xml version="1.0"?><plist version="1.0"><dict><key>DeveloperCertificates</key><array><data>#{Base64.strict_encode64(@certificate_bytes)}</data></array></dict></plist>)
    key, certificate = self.class.signer
    cms = OpenSSL::PKCS7.sign(certificate, key, xml, [], OpenSSL::PKCS7::BINARY).to_der
    result = Bootstrap.decode_profile(cms)
    assert_instance_of StringIO, result["DeveloperCertificates"].first
    assert_equal @certificate_bytes, result["DeveloperCertificates"].first.string.b
    corrupted = cms.dup
    corrupted.setbyte(corrupted.bytesize - 8, corrupted.getbyte(corrupted.bytesize - 8) ^ 1)
    assert_raises(Bootstrap::Error) { Bootstrap.decode_profile(corrupted) }
  end

  def test_both_platforms_validate_real_signed_cms_profile_and_binary_certificate
    key, certificate = self.class.signer
    strings = ->(values) { values.map { |value| "<string>#{value}</string>" }.join }
    Bootstrap::TARGETS.each_with_index do |target, index|
      xml = <<~XML
        <?xml version="1.0"?><plist version="1.0"><dict>
        <key>TeamIdentifier</key><array><string>#{Bootstrap::TEAM}</string></array>
        <key>ApplicationIdentifierPrefix</key><array><string>#{Bootstrap::TEAM}</string></array>
        <key>Platform</key><array>#{strings.call(target[:decoded_platforms])}</array>
        <key>ExpirationDate</key><date>#{(NOW + 3600).iso8601}</date>
        <key>DeveloperCertificates</key><array><data>#{Base64.strict_encode64(@certificate_bytes)}</data></array>
        <key>Entitlements</key><dict>
        <key>#{target[:identifier_key]}</key><string>#{Bootstrap::TEAM}.#{Bootstrap::BUNDLE_ID}</string>
        <key>com.apple.developer.team-identifier</key><string>#{Bootstrap::TEAM}</string>
        <key>com.apple.security.application-groups</key><array><string>#{Bootstrap::APP_GROUP}</string></array>
        <key>get-task-allow</key><false/>
        </dict></dict></plist>
      XML
      cms = OpenSSL::PKCS7.sign(certificate, key, xml, [], OpenSSL::PKCS7::BINARY).to_der
      profile = @profiles[index].merge(content: Base64.strict_encode64(cms))
      decoded = Bootstrap.validate_profile!(profile, target, @certificate_bytes, NOW, Bootstrap.method(:decode_profile))
      assert_equal cms, decoded
      assert Bootstrap.encrypt_profile(decoded, environment["MATCH_PASSWORD"])
    end
  end

  def test_all_actual_spaceship_subclients_discard_payload_logs_before_requests
    key = OpenSSL::PKey::EC.generate("prime256v1")
    env = environment.merge("ASC_KEY_CONTENT_BASE64" => Base64.strict_encode64(key.to_pem))
    Dir.mktmpdir do |directory|
      previous_tmpdir = ENV["TMPDIR"]
      ENV["TMPDIR"] = directory
      begin
        api = Bootstrap::AppleAPI.new(env)
        client = api.instance_variable_get(:@client)
        out, err = capture_io do
          %i[provisioning_request_client test_flight_request_client tunes_request_client users_request_client].each do |name|
            logger = client.public_send(name).logger
            assert_instance_of Logger, logger
            logger.info("sensitive-fixture-response")
          end
        end
        assert_empty out
        assert_empty err
        assert_empty Dir.children(directory), "API payload logging must not create a temporary file"
      ensure
        previous_tmpdir ? ENV["TMPDIR"] = previous_tmpdir : ENV.delete("TMPDIR")
      end
    end
  end

  def test_workflow_uploads_only_ciphertext_allowlist_without_deploy_key_or_write_permission
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/signing-profiles.yml", __dir__))
    assert_equal({ "contents" => "read" }, workflow.fetch("permissions"))
    job = workflow.fetch("jobs").fetch("bootstrap")
    assert_equal "testflight", job.fetch("environment")
    steps = job.fetch("steps")
    secret_step = steps.find { |step| step["env"]&.key?("MATCH_PASSWORD") }
    assert_equal %w[APPLE_TEAM_ID ASC_ISSUER_ID ASC_KEY_CONTENT_BASE64 ASC_KEY_ID MATCH_PASSWORD], secret_step.fetch("env").keys.sort
    assert_operator steps.index(steps.find { |step| step["name"].to_s.include?("offline") }), :<, steps.index(secret_step)
    artifact = steps.find { |step| step["uses"].to_s.start_with?("actions/upload-artifact@") }.fetch("with")
    assert_equal Bootstrap::TARGETS.map { |target| "build/signing-profiles/#{target[:file]}" }.sort, artifact.fetch("path").lines.map(&:strip).sort
    assert_equal 1, artifact.fetch("retention-days")
  end

  class FakeAPI
    attr_accessor :existing, :fail_macos
    attr_reader :created
    def initialize(certificate, profiles)
      @certificate, @generated, @existing, @created = certificate, profiles, profiles, []
    end
    def certificate = @certificate
    def bundles = [{ id: "existing-bundle", identifier: Bootstrap::BUNDLE_ID, platform: "UNIVERSAL", seed: Bootstrap::TEAM }]
    def profiles = existing
    def existing_builds = { status: "checked", builds: [] }
    def create_profile(target, bundle)
      @created << { type: target[:type], bundle: bundle }
      raise "sensitive-fixture-response" if fail_macos && target[:platform] == "MAC_OS"
      @generated.find { |profile| profile[:type] == target[:type] }
    end
  end
end
