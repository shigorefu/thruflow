# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "securerandom"

module TestFlightSupport
  APP_ID = "com.shigorefu.thruflow"
  CLOUD_CONTAINER = "iCloud.com.shigorefu.thruflow"
  TARGETS = {
    "ios" => { "ThruFlow iOS" => APP_ID,
               "ThruFlowLiveActivityExtension" => "#{APP_ID}.liveactivity",
               "ThruFlow Watch App" => "#{APP_ID}.watchapp" },
    "macos" => { "ThruFlow" => APP_ID,
                 "ThruFlowLiveActivityExtension" => "#{APP_ID}.liveactivity" }
  }.freeze

  def self.required(env, name)
    value = env[name].to_s.strip
    raise "Missing #{name}" if value.empty?
    value
  end

  def self.configuration(env, platform)
    raise "Unsupported platform" unless TARGETS.key?(platform)
    raise "These upload lanes run only on GitHub Actions" unless env["GITHUB_ACTIONS"] == "true"
    version = required(env, "RELEASE_VERSION")
    build = required(env, "RELEASE_BUILD")
    raise "Invalid release version" unless version.match?(/\A\d+\.\d+\.\d+\z/)
    raise "Invalid release build" unless build.match?(/\A[1-9]\d*\z/)
    team = required(env, "APPLE_TEAM_ID")
    raise "Invalid Apple team" unless team.match?(/\A[A-Z0-9]{10}\z/)
    %w[MATCH_GIT_URL MATCH_GIT_BRANCH MATCH_PASSWORD
       ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT_BASE64].each { |name| required(env, name) }
    git_url = required(env, "MATCH_GIT_URL")
    https = git_url.match?(%r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?\z})
    ssh = git_url.match?(%r{\Agit@github\.com:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?\z})
    raise "Use a credential-free GitHub HTTPS or SSH signing repository URL" unless https || ssh
    required(env, ssh ? "MATCH_GIT_PRIVATE_KEY" : "MATCH_GIT_BASIC_AUTHORIZATION")
    other = ssh ? "MATCH_GIT_BASIC_AUTHORIZATION" : "MATCH_GIT_PRIVATE_KEY"
    raise "Configure only the signing repository's selected authentication method" unless env[other].to_s.empty?
    installer = platform == "macos" ? required(env, "MAC_INSTALLER_CERT_NAME") : nil
    if installer && !(installer.start_with?("3rd Party Mac Developer Installer: ") && installer.end_with?("(#{team})"))
      raise "MAC_INSTALLER_CERT_NAME must be this team's Mac App Store installer certificate"
    end
    { platform: platform, version: version, build: build, team: team, installer: installer }
  end

  # Match omits the platform suffix for iOS, but includes it for macOS.
  def self.signing_settings(env, platform)
    TARGETS.fetch(platform).transform_values do |identifier|
      prefix = ["sigh", identifier, "appstore", (platform unless platform == "ios")].compact.join("_")
      { identifier: identifier, profile: required(env, "#{prefix}_profile-name"),
        certificate: required(env, "#{prefix}_certificate-name") }
    end
  end

  # A sibling project keeps SOURCE_ROOT unchanged; scheme references must follow it.
  def self.with_project_copy(root)
    original = File.join(root, "ThruFlow.xcodeproj")
    copy = File.join(root, "ThruFlow-TestFlight-#{SecureRandom.hex(6)}.xcodeproj")
    FileUtils.cp_r(original, copy)
    Dir[File.join(copy, "**", "*.xcscheme")].each do |path|
      File.write(path, File.read(path).gsub("container:ThruFlow.xcodeproj", "container:#{File.basename(copy)}"))
    end
    yield copy
  ensure
    FileUtils.rm_rf(copy) if copy
  end

  def self.command!(*arguments, stdin_data: "")
    out, err, status = Open3.capture3(*arguments, stdin_data: stdin_data)
    raise "#{File.basename(arguments.first)} failed: #{err}" unless status.success?
    out
  end

  def self.plist(path)
    JSON.parse(command!("/usr/bin/plutil", "-convert", "json", "-o", "-", path))
  end

  def self.entitlements(bundle)
    xml = command!("/usr/bin/codesign", "--display", "--entitlements", ":-", bundle)
    JSON.parse(command!("/usr/bin/plutil", "-convert", "json", "-o", "-", "-", stdin_data: xml))
  end

  def self.validate_records!(records, config, signed:)
    expected = TARGETS.fetch(config[:platform]).values.sort
    raise "Unexpected or missing embedded app/extension" unless records.map { |r| r[:info]["CFBundleIdentifier"] }.sort == expected
    records.each do |record|
      info = record[:info]
      id = info.fetch("CFBundleIdentifier")
      unless info["CFBundleShortVersionString"] == config[:version] && info["CFBundleVersion"] == config[:build]
        raise "Version/build mismatch in #{id}"
      end
      next unless signed
      rights = record.fetch(:entitlements)
      raise "Wrong signing team in #{id}" unless rights["com.apple.developer.team-identifier"] == config[:team]
      raise "Development signing in #{id}" if rights["get-task-allow"] == true || rights["com.apple.security.get-task-allow"] == true
      next if id.end_with?(".liveactivity")
      unless rights["com.apple.developer.icloud-container-environment"] == "Production" &&
             Array(rights["com.apple.developer.icloud-container-identifiers"]).include?(CLOUD_CONTAINER)
        raise "CloudKit Production entitlement missing in #{id}"
      end
    end
  end

  def self.validate_bundles!(directory, config, signed:)
    bundles = Dir[File.join(directory, "**", "*")].select { |path| File.directory?(path) && %w[.app .appex].include?(File.extname(path)) }
    records = bundles.map do |bundle|
      path = File.join(bundle, "Info.plist")
      path = File.join(bundle, "Contents", "Info.plist") unless File.exist?(path)
      record = { info: plist(path) }
      if signed
        command!("/usr/bin/codesign", "--verify", "--strict", bundle)
        record[:entitlements] = entitlements(bundle)
      end
      record
    end
    validate_records!(records, config, signed: signed)
  end

  def self.validate_export!(artifact, config)
    raise "Exported artifact is missing" unless artifact && File.file?(artifact)
    Dir.mktmpdir("thruflow-export-") do |temporary|
      expanded = File.join(temporary, "expanded")
      if config[:platform] == "ios"
        command!("/usr/bin/ditto", "-x", "-k", artifact, expanded)
      else
        command!("/usr/sbin/pkgutil", "--check-signature", artifact)
        command!("/usr/sbin/pkgutil", "--expand-full", artifact, expanded)
      end
      validate_bundles!(expanded, config, signed: true)
    end
  end
end
