# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/testflight_support"

class TestFlightSupportTest < Minitest::Test
  def environment
    { "GITHUB_ACTIONS" => "true", "RELEASE_VERSION" => "1.4.0", "RELEASE_BUILD" => "13",
      "APPLE_TEAM_ID" => "BR727PS795", "MATCH_GIT_URL" => "https://github.com/example/signing.git",
      "MATCH_GIT_BRANCH" => "main", "MATCH_PASSWORD" => "fixture",
      "MATCH_GIT_BASIC_AUTHORIZATION" => "fixture", "ASC_KEY_ID" => "fixture",
      "ASC_ISSUER_ID" => "fixture", "ASC_KEY_CONTENT_BASE64" => "fixture",
      "MAC_INSTALLER_CERT_NAME" => "3rd Party Mac Developer Installer: Fixture (BR727PS795)" }
  end

  def configuration(platform = "ios")
    TestFlightSupport.configuration(environment, platform)
  end

  def records(platform = "ios")
    TestFlightSupport::TARGETS.fetch(platform).values.map do |id|
      { info: { "CFBundleIdentifier" => id, "CFBundleShortVersionString" => "1.4.0", "CFBundleVersion" => "13" },
        entitlements: { "com.apple.developer.team-identifier" => "BR727PS795",
                        "com.apple.developer.icloud-container-environment" => "Production",
                        "com.apple.developer.icloud-container-identifiers" => [TestFlightSupport::CLOUD_CONTAINER] } }
    end
  end

  def test_lanes_reject_local_runs_before_any_signing
    assert_raises(RuntimeError) { TestFlightSupport.configuration(environment.merge("GITHUB_ACTIONS" => nil), "ios") }
  end

  def test_exact_metadata_and_clean_git_url_required
    %w[RELEASE_VERSION RELEASE_BUILD APPLE_TEAM_ID MATCH_GIT_BRANCH ASC_KEY_ID].each do |key|
      assert_raises(RuntimeError) { TestFlightSupport.configuration(environment.merge(key => ""), "ios") }
    end
    assert_raises(RuntimeError) { TestFlightSupport.configuration(environment.merge("MATCH_GIT_URL" => "https://token@github.com/example/signing.git"), "ios") }
    assert_raises(RuntimeError) { TestFlightSupport.configuration(environment.merge("RELEASE_BUILD" => "13;echo bad"), "ios") }
  end

  def test_mac_installer_certificate_is_required_and_team_bound
    assert configuration("macos")[:installer].include?("Installer")
    assert_raises(RuntimeError) { TestFlightSupport.configuration(environment.merge("MAC_INSTALLER_CERT_NAME" => nil), "macos") }
    assert_raises(RuntimeError) { TestFlightSupport.configuration(environment.merge("MAC_INSTALLER_CERT_NAME" => "Developer ID Installer: Fixture (BR727PS795)"), "macos") }
  end

  def test_match_mapping_uses_platform_specific_keys
    env = {}
    %w[ios macos].each do |platform|
      TestFlightSupport::TARGETS.fetch(platform).each_value do |id|
        suffix = platform == "ios" ? "" : "_macos"
        env["sigh_#{id}_appstore#{suffix}_profile-name"] = "#{platform} profile"
        env["sigh_#{id}_appstore#{suffix}_certificate-name"] = "#{platform} certificate"
      end
    end
    assert_equal "ios profile", TestFlightSupport.signing_settings(env, "ios").fetch("ThruFlow iOS")[:profile]
    assert_equal "macos profile", TestFlightSupport.signing_settings(env, "macos").fetch("ThruFlow")[:profile]
    env.delete("sigh_#{TestFlightSupport::APP_ID}_appstore_macos_profile-name")
    assert_raises(RuntimeError) { TestFlightSupport.signing_settings(env, "macos") }
  end

  def test_all_platform_bundles_accept_matching_production_metadata
    %w[ios macos].each do |platform|
      TestFlightSupport.validate_records!(records(platform), configuration(platform), signed: true)
    end
  end

  def test_missing_watch_or_duplicate_bundle_is_rejected
    assert_raises(RuntimeError) { TestFlightSupport.validate_records!(records[0..1], configuration, signed: true) }
    duplicate = records
    duplicate << duplicate.first
    assert_raises(RuntimeError) { TestFlightSupport.validate_records!(duplicate, configuration, signed: true) }
  end

  def test_nested_version_drift_is_rejected
    values = records
    values.last[:info]["CFBundleVersion"] = "12"
    assert_raises(RuntimeError) { TestFlightSupport.validate_records!(values, configuration, signed: false) }
  end

  def test_production_cloudkit_required_on_watch_but_not_widget
    values = records
    values[1][:entitlements].delete("com.apple.developer.icloud-container-environment")
    TestFlightSupport.validate_records!(values, configuration, signed: true)
    values.last[:entitlements]["com.apple.developer.icloud-container-environment"] = "Development"
    assert_raises(RuntimeError) { TestFlightSupport.validate_records!(values, configuration, signed: true) }
  end

  def test_wrong_team_or_debuggable_binary_rejected
    values = records
    values.first[:entitlements]["com.apple.developer.team-identifier"] = "OTHERTEAM00"
    assert_raises(RuntimeError) { TestFlightSupport.validate_records!(values, configuration, signed: true) }
    values = records
    values.first[:entitlements]["get-task-allow"] = true
    assert_raises(RuntimeError) { TestFlightSupport.validate_records!(values, configuration, signed: true) }
  end

  def test_project_copy_rewrites_scheme_then_cleans_up_even_on_failure
    Dir.mktmpdir do |root|
      original = File.join(root, "ThruFlow.xcodeproj")
      FileUtils.mkdir_p(File.join(original, "xcshareddata", "xcschemes"))
      scheme = File.join(original, "xcshareddata", "xcschemes", "ThruFlow.xcscheme")
      contents = '<BuildableReference ReferencedContainer="container:ThruFlow.xcodeproj" />'
      File.write(scheme, contents)
      path = nil
      assert_raises(RuntimeError) do
        TestFlightSupport.with_project_copy(root) do |copy|
          path = copy
          text = File.read(File.join(copy, "xcshareddata", "xcschemes", "ThruFlow.xcscheme"))
          assert_includes text, "container:#{File.basename(copy)}"
          refute_equal contents, text
          raise "simulated build failure"
        end
      end
      refute File.exist?(path)
      assert_equal contents, File.read(scheme)
    end
  end
end
