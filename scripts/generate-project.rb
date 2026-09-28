#!/usr/bin/env ruby
# frozen_string_literal: true

# Deterministically generates the small native Xcode project. The source tree
# is deliberately authoritative: App/**/*.swift and Helper/**/*.swift are
# discovered at generation time, while package and release configuration is
# kept explicit below.

require "fileutils"
require "pathname"
require "xcodeproj"

ROOT = Pathname(__dir__).parent
PROJECT_PATH = ROOT.join("LidPilot.xcodeproj")
PROJECT_RELATIVE_PATH = Pathname("LidPilot.xcodeproj")
APP_IDENTIFIER = "com.lidpilot.app"
HELPER_IDENTIFIER = "com.lidpilot.app.helper"
DEVELOPMENT_APP_IDENTIFIER = "com.lidpilot.app.dev"
DEVELOPMENT_HELPER_IDENTIFIER = "com.lidpilot.app.dev.helper"
APP_TEST_IDENTIFIER = "com.lidpilot.app.tests"
APP_TEST_SOURCES = [
  "App/UpdateCoordinator.swift",
  "App/UpdateOwnership.swift",
  "App/GlobalShortcuts.swift",
  "App/HelperManager.swift",
  "App/AppModel.swift",
  "App/DiagnosticsStore.swift",
  "App/StateObserver.swift",
  "AppTests/UpdateCoordinatorTests.swift"
].freeze
IDENTITIES = {
  "Debug" => {
    "app" => DEVELOPMENT_APP_IDENTIFIER,
    "helper" => DEVELOPMENT_HELPER_IDENTIFIER,
    "daemon_plist" => "#{DEVELOPMENT_HELPER_IDENTIFIER}.plist",
    "daemon_template" => "Config/LaunchDaemons/#{DEVELOPMENT_HELPER_IDENTIFIER}.plist"
  },
  "Release" => {
    "app" => APP_IDENTIFIER,
    "helper" => HELPER_IDENTIFIER,
    "daemon_plist" => "#{HELPER_IDENTIFIER}.plist",
    "daemon_template" => "Config/LaunchDaemons/#{HELPER_IDENTIFIER}.plist"
  }
}.freeze
DAEMON_TEMPLATE_PATHS = IDENTITIES.values.map { |identity| identity.fetch("daemon_template") }.uniq.freeze
SPARKLE_URL = "https://github.com/sparkle-project/Sparkle"
SPARKLE_VERSION = "2.10.0"

def relative_files(relative_dir, extension)
  directory = ROOT.join(relative_dir)
  return [] unless directory.directory?

  Dir.glob(directory.join("**", "*#{extension}").to_s).select { |path| File.file?(path) }
     .map { |path| Pathname(path).relative_path_from(ROOT).to_s }
     .sort
end

def add_group_files(project, target, name, path, extension)
  group = project.main_group.find_subpath(path, true)
  group.name = name
  files = relative_files(path, extension)
  references = files.map { |file| group.new_file(file) }
  target.add_file_references(references) unless references.empty?
  references
end

def add_package_reference(project, relative_path)
  reference = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  reference.relative_path = relative_path
  project.root_object.package_references << reference
  reference
end

def add_package_product(target, package_reference, product_name)
  dependency = target.project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package_reference
  dependency.product_name = product_name
  target.package_product_dependencies << dependency
  link_file = target.project.new(Xcodeproj::Project::Object::PBXBuildFile)
  link_file.product_ref = dependency
  target.frameworks_build_phase.files << link_file
  dependency
end

def add_copy_file(project, phase, file_reference, attributes = [])
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.file_ref = file_reference
  build_file.settings = { "ATTRIBUTES" => attributes } unless attributes.empty?
  phase.files << build_file
  build_file
end

def configure_common_settings(config, release: false)
  config.build_settings.merge!(
    "ARCHS" => "arm64",
    "CLANG_ENABLE_MODULES" => "YES",
    "CODE_SIGN_INJECT_BASE_ENTITLEMENTS" => "NO",
    "CODE_SIGN_STYLE" => release ? "Manual" : "Manual",
    "CURRENT_PROJECT_VERSION" => "$(inherited)",
    "ENABLE_APP_SANDBOX" => "NO",
    "ENABLE_HARDENED_RUNTIME" => "YES",
    "GCC_C_LANGUAGE_STANDARD" => "gnu17",
    "MACOSX_DEPLOYMENT_TARGET" => "15.0",
    "ONLY_ACTIVE_ARCH" => release ? "NO" : "YES",
    "SDKROOT" => "macosx",
    "SWIFT_STRICT_CONCURRENCY" => "complete",
    "SWIFT_VERSION" => "6.0",
    "VERSIONING_SYSTEM" => "apple-generic"
  )
  config.build_settings["CODE_SIGN_IDENTITY"] = release ? "Developer ID Application" : "-"
end

def configure_target_settings(target, info_plist, helper: false)
  target.build_configurations.each do |config|
    release = config.name == "Release"
    identity = IDENTITIES.fetch(config.name)
    configure_common_settings(config, release: release)
    config.build_settings.merge!(
      "CODE_SIGN_ENTITLEMENTS" => "",
      "INFOPLIST_FILE" => info_plist,
      "INSTALL_PATH" => helper ? "$(CONTENTS_FOLDER_PATH)" : "$(LOCAL_APPS_DIR)",
      "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/../Frameworks"],
      "PRODUCT_BUNDLE_IDENTIFIER" => helper ? identity.fetch("helper") : identity.fetch("app"),
      "PRODUCT_NAME" => helper ? "LidPilotHelper" : "LidPilot",
      "LIDPILOT_APP_IDENTIFIER" => identity.fetch("app"),
      "LIDPILOT_HELPER_IDENTIFIER" => identity.fetch("helper"),
      "LIDPILOT_DAEMON_LABEL" => identity.fetch("helper"),
      "LIDPILOT_DAEMON_PLIST_NAME" => identity.fetch("daemon_plist"),
      "LIDPILOT_SERVICE_IDENTIFIER" => identity.fetch("helper"),
      "SKIP_INSTALL" => helper ? "YES" : "NO"
    )
    # Release tooling supplies its feed and key explicitly. Never inherit a
    # developer shell's values into either ordinary build configuration.
    config.build_settings["SUFeedURL"] = ""
    config.build_settings["SUPublicEDKey"] = ""
    if helper
      # A command-line tool has no wrapper by default. Embed the generated
      # Info.plist in its binary so the peer identity/team/version contract is
      # available to the authenticated helper without manufacturing a .app.
      config.build_settings["CREATE_INFOPLIST_SECTION_IN_BINARY"] = "YES"
      config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
      config.build_settings["MACH_O_TYPE"] = "mh_execute"
    else
      config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
      config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    end
  end
end

def configure_app_test_target(target)
  target.build_configurations.each do |config|
    configure_common_settings(config)
    config.build_settings.merge!(
      "CODE_SIGN_ENTITLEMENTS" => "",
      "CODE_SIGN_IDENTITY" => "-",
      "CODE_SIGN_STYLE" => "Manual",
      "GENERATE_INFOPLIST_FILE" => "YES",
      "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks"],
      "PRODUCT_BUNDLE_IDENTIFIER" => APP_TEST_IDENTIFIER,
      "PRODUCT_NAME" => "LidPilotAppTests",
      "SKIP_INSTALL" => "YES",
      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "LIDPILOT_TESTING",
      "ENABLE_TESTABILITY" => "YES"
    )
    # This is a hostless XCTest bundle containing only explicit coordinator
    # sources. In particular, no app launch invokes AppModel or ServiceManagement.
    config.build_settings.delete("TEST_HOST")
    config.build_settings.delete("BUNDLE_LOADER")
  end
end

def project_invariants(project)
  targets = project.targets.to_h { |target| [target.name, target] }
  app = targets["LidPilot"]
  helper = targets["LidPilotHelper"]
  cli = targets["LidPilotCLI"]
  app_tests = targets["LidPilotAppTests"]
  raise "missing LidPilot application target" unless app
  raise "missing LidPilotHelper tool target" unless helper
  raise "missing lidpilot command-line tool" unless cli && cli.product_type == "com.apple.product-type.tool" && cli.product_reference.path == "lidpilot-cli"
  cli_phase = app&.copy_files_build_phases&.find { |phase| phase.name == "Embed lidpilot CLI" }
  raise "CLI must be embedded in Contents/MacOS" unless cli_phase && cli_phase.dst_path == "Contents/MacOS" && cli_phase.dst_subfolder_spec == "1"
  raise "embedded CLI must be signed" unless cli_phase.files.any? { |file| file.file_ref == cli.product_reference && file.settings&.fetch("ATTRIBUTES", [])&.include?("CodeSignOnCopy") }
  raise "CLI source set is stale" unless cli.source_build_phase.files_references.map(&:path).sort == relative_files("CLI", ".swift").sort
  raise "missing hostless LidPilotAppTests bundle target" unless app_tests
  raise "LidPilotAppTests is not a unit-test bundle" unless app_tests.product_type == "com.apple.product-type.bundle.unit-test"
  app_tests.build_configurations.each do |config|
    settings = config.build_settings
    raise "#{config.name} app tests must use the dedicated bundle identifier" unless settings["PRODUCT_BUNDLE_IDENTIFIER"] == APP_TEST_IDENTIFIER
    raise "#{config.name} app tests must compile the coordinator injection seam" unless settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] == "LIDPILOT_TESTING"
    raise "#{config.name} app tests must generate an Info.plist" unless settings["GENERATE_INFOPLIST_FILE"] == "YES"
    raise "#{config.name} app test bundle must be hostless" if settings.key?("TEST_HOST") || settings.key?("BUNDLE_LOADER")
  end
  test_source_paths = app_tests.source_build_phase.files_references.map(&:path)
  raise "LidPilotAppTests source set changed: #{test_source_paths.sort.inspect}" unless test_source_paths.sort == APP_TEST_SOURCES.sort
  raise "LidPilotAppTests source leaked into the shipping app target" if
    app.source_build_phase.files_references.any? { |reference| reference.path == "AppTests/UpdateCoordinatorTests.swift" }

  app_id = app.build_configurations.first.build_settings["PRODUCT_BUNDLE_IDENTIFIER"]
  raise "unexpected first app bundle identifier: #{app_id.inspect}" unless IDENTITIES.values.any? { |identity| identity.fetch("app") == app_id }
  IDENTITIES.each do |configuration_name, identity|
    app_config = app.build_configurations.find { |config| config.name == configuration_name }
    helper_config = helper.build_configurations.find { |config| config.name == configuration_name }
    raise "missing #{configuration_name} app build configuration" unless app_config
    raise "missing #{configuration_name} helper build configuration" unless helper_config
    raise "unexpected #{configuration_name} app bundle identifier" unless app_config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] == identity.fetch("app")
    raise "unexpected #{configuration_name} helper bundle identifier" unless helper_config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] == identity.fetch("helper")
    [app_config, helper_config].each do |config|
      raise "#{configuration_name} app/helper identity settings disagree" unless
        config.build_settings["LIDPILOT_APP_IDENTIFIER"] == identity.fetch("app") &&
        config.build_settings["LIDPILOT_HELPER_IDENTIFIER"] == identity.fetch("helper")
      raise "#{configuration_name} daemon settings disagree" unless
        config.build_settings["LIDPILOT_DAEMON_LABEL"] == identity.fetch("helper") &&
        config.build_settings["LIDPILOT_DAEMON_PLIST_NAME"] == identity.fetch("daemon_plist") &&
        config.build_settings["LIDPILOT_SERVICE_IDENTIFIER"] == identity.fetch("helper")
      raise "developer update feed defaults must be empty" unless
        config.build_settings["SUFeedURL"].to_s.empty? && config.build_settings["SUPublicEDKey"].to_s.empty?
    end
    template = ROOT.join(identity.fetch("daemon_template"))
    raise "LaunchDaemon template missing: #{template}" unless template.file?
    contents = File.read(template)
    raise "LaunchDaemon template label is wrong: #{template}" unless contents.include?("<string>#{identity.fetch("helper")}</string>")
    raise "LaunchDaemon template service is wrong: #{template}" unless contents.include?("<key>#{identity.fetch("helper")}</key>")
  end
  daemon_phase = app.shell_script_build_phases.find { |phase| phase.name == "Embed Configuration LaunchDaemon" }
  raise "configuration-specific LaunchDaemon embed phase is missing" unless daemon_phase
  expected_inputs = DAEMON_TEMPLATE_PATHS.map { |path| "$(SRCROOT)/#{path}" }
  raise "LaunchDaemon embed inputs are wrong" unless daemon_phase.input_paths.sort == expected_inputs.sort
  expected_output = "$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchDaemons/$(LIDPILOT_DAEMON_PLIST_NAME)"
  raise "LaunchDaemon embed output is wrong" unless daemon_phase.output_paths == [expected_output]
  IDENTITIES.each_value do |identity|
    [identity.fetch("app"), identity.fetch("helper"), identity.fetch("daemon_plist"), identity.fetch("daemon_template")].each do |value|
      raise "LaunchDaemon embed script is missing #{value}" unless daemon_phase.shell_script.include?(value)
    end
  end
  raise "stale unconditional LaunchDaemon copy phase remains" if app.shell_script_build_phases.any? { |phase| phase.name == "Embed LaunchDaemon" }

  local_paths = project.root_object.package_references
    .select { |reference| reference.respond_to?(:relative_path) }
    .map(&:relative_path)
    .compact
  raise "root local package reference is missing" unless local_paths.include?(".")
  raise "Core local package reference is missing" unless local_paths.include?("Core")
  sparkle = project.root_object.package_references.find do |ref|
    ref.respond_to?(:repositoryURL) && ref.repositoryURL == SPARKLE_URL
  end
  raise "Sparkle remote package reference is missing" unless sparkle
  requirement = sparkle.requirement
  unless requirement && requirement["kind"] == "exactVersion" && requirement["version"] == SPARKLE_VERSION
    raise "Sparkle must be pinned to exact version #{SPARKLE_VERSION}: #{requirement.inspect}"
  end
  ["LidPilotRuntime", "LidPilotCore", "Sparkle"].each do |product_name|
    raise "LidPilotAppTests is missing #{product_name}" unless
      app_tests.package_product_dependencies.any? { |dependency| dependency.product_name == product_name }
  end

  true
end

def daemon_embedding_script
  <<~SH
    set -eu
    case "${CONFIGURATION:-}" in
      Debug)
        expected_app="#{IDENTITIES.fetch("Debug").fetch("app")}";
        expected_helper="#{IDENTITIES.fetch("Debug").fetch("helper")}";
        expected_plist="#{IDENTITIES.fetch("Debug").fetch("daemon_plist")}";
        source_plist="${SRCROOT}/#{IDENTITIES.fetch("Debug").fetch("daemon_template")}" ;;
      Release)
        expected_app="#{IDENTITIES.fetch("Release").fetch("app")}";
        expected_helper="#{IDENTITIES.fetch("Release").fetch("helper")}";
        expected_plist="#{IDENTITIES.fetch("Release").fetch("daemon_plist")}";
        source_plist="${SRCROOT}/#{IDENTITIES.fetch("Release").fetch("daemon_template")}" ;;
      *) echo "Unsupported LidPilot configuration: ${CONFIGURATION:-missing}" >&2; exit 64 ;;
    esac

    [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" = "$expected_app" ] || { echo "App identity does not match $CONFIGURATION" >&2; exit 1; }
    [ "${LIDPILOT_APP_IDENTIFIER:-}" = "$expected_app" ] || { echo "Host identity does not match $CONFIGURATION" >&2; exit 1; }
    [ "${LIDPILOT_HELPER_IDENTIFIER:-}" = "$expected_helper" ] || { echo "Helper identity does not match $CONFIGURATION" >&2; exit 1; }
    [ "${LIDPILOT_DAEMON_LABEL:-}" = "$expected_helper" ] || { echo "Daemon label does not match $CONFIGURATION" >&2; exit 1; }
    [ "${LIDPILOT_DAEMON_PLIST_NAME:-}" = "$expected_plist" ] || { echo "Daemon plist name does not match $CONFIGURATION" >&2; exit 1; }
    [ "${LIDPILOT_SERVICE_IDENTIFIER:-}" = "$expected_helper" ] || { echo "XPC service identity does not match $CONFIGURATION" >&2; exit 1; }

    destination_dir="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Library/LaunchDaemons"
    destination="${destination_dir}/${expected_plist}"
    /bin/mkdir -p "$destination_dir"
    for stale_plist in "#{IDENTITIES.fetch("Debug").fetch("daemon_plist")}" "#{IDENTITIES.fetch("Release").fetch("daemon_plist")}"; do
      if [ "$stale_plist" != "$expected_plist" ] && [ -e "${destination_dir}/${stale_plist}" ]; then
        /bin/rm -f "${destination_dir}/${stale_plist}"
      fi
    done
    /bin/cp "$source_plist" "$destination"
    /usr/bin/plutil -lint "$destination" >/dev/null
    actual_label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$destination")
    actual_service=$(/usr/libexec/PlistBuddy -c "Print :MachServices:$expected_helper" "$destination")
    [ "$actual_label" = "$expected_helper" ] && [ "$actual_service" = "true" ] || {
      echo "Embedded LaunchDaemon identity does not match $CONFIGURATION" >&2
      exit 1
    }
  SH
end

def generate
  project = Xcodeproj::Project.new(PROJECT_RELATIVE_PATH.to_s)
  project.root_object.attributes["LastUpgradeCheck"] = "2700"
  project.root_object.development_region = "en"
  project.root_object.known_regions = ["en", "Base"]

  app = project.new_target(:application, "LidPilot", :osx, "15.0")
  helper = project.new_target(:tool, "LidPilotHelper", :osx, "15.0")
  cli = project.new_target(:tool, "LidPilotCLI", :osx, "15.0")
  app_tests = project.new_target(:unit_test_bundle, "LidPilotAppTests", :osx, "15.0")
  helper.product_type = "com.apple.product-type.tool"
  cli.product_type = "com.apple.product-type.tool"
  # The embedded filename must differ beyond case from the app's LidPilot
  # executable on ordinary case-insensitive APFS volumes.
  cli.product_reference.path = "lidpilot-cli"
  cli.product_reference.name = "lidpilot-cli"
  app.product_reference.name = "LidPilot.app"
  helper.product_reference.name = "LidPilotHelper"
  app_tests.product_reference.name = "LidPilotAppTests.xctest"

  xcconfig_reference = project.main_group.new_file("Version.xcconfig")
  project.build_configurations.each do |config|
    config.base_configuration_reference = xcconfig_reference
  end
  configure_target_settings(app, "Config/App-Info.plist")
  configure_target_settings(helper, "Config/Helper-Info.plist", helper: true)
  configure_app_test_target(app_tests)
  cli.build_configurations.each do |config|
    configure_common_settings(config, release: config.name == "Release")
    config.base_configuration_reference = xcconfig_reference
    config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = IDENTITIES.fetch(config.name).fetch("app") + ".cli"
    config.build_settings["PRODUCT_NAME"] = "lidpilot-cli"
    config.build_settings["SWIFT_VERSION"] = "6.0"
    config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = config.name == "Debug" ? "DEBUG" : ""
    config.build_settings["SKIP_INSTALL"] = "YES"
  end

  add_group_files(project, app, "App", "App", ".swift")
  add_group_files(project, helper, "Helper", "Helper", ".swift")
  add_group_files(project, cli, "CLI", "CLI", ".swift")
  app_test_group = project.main_group.find_subpath("AppTests", true)
  app_test_group.name = "AppTests"
  app_references = app.source_build_phase.files_references.to_h { |reference| [reference.path, reference] }
  test_references = APP_TEST_SOURCES.map do |path|
    app_references[path] || app_test_group.new_file(path)
  end
  app_tests.add_file_references(test_references)
  ["App/Assets.xcassets", "LICENSE", "THIRD_PARTY_NOTICES.md"].each do |path|
    app.resources_build_phase.add_file_reference(project.main_group.new_file(path))
  end

  root_package = add_package_reference(project, ".")
  core_package = add_package_reference(project, "Core")
  [app, helper, cli].each do |target|
    add_package_product(target, root_package, "LidPilotRuntime")
    add_package_product(target, core_package, "LidPilotCore")
  end

  sparkle_package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  sparkle_package.repositoryURL = SPARKLE_URL
  sparkle_package.requirement = { "kind" => "exactVersion", "version" => SPARKLE_VERSION }
  project.root_object.package_references << sparkle_package
  add_package_product(app, sparkle_package, "Sparkle")
  ["LidPilotRuntime", "LidPilotCore", "Sparkle"].zip([root_package, core_package, sparkle_package]).each do |product_name, package|
    add_package_product(app_tests, package, product_name)
  end

  # xcodeproj's UUID generator includes PBXContainerItemProxy references in
  # the dependency path.  Those references contain the target/root UUIDs, so
  # generating the dependency in the same pass would hash random UUIDs.  Give
  # the targets and their existing graph stable UUIDs before creating the
  # proxy, then run the normal generator again after the dependency exists.
  project.predictabilize_uuids
  app.add_dependency(helper)
  app.add_dependency(cli)
  embed_cli = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_cli.name = "Embed lidpilot CLI"
  embed_cli.dst_subfolder_spec = "1"
  embed_cli.dst_path = "Contents/MacOS"
  app.build_phases << embed_cli
  add_copy_file(project, embed_cli, cli.product_reference, ["CodeSignOnCopy"])
  embed_helper = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_helper.name = "Embed LidPilotHelper"
  embed_helper.dst_subfolder_spec = "1"
  embed_helper.dst_path = "Contents/Library/HelperTools"
  app.build_phases << embed_helper
  add_copy_file(project, embed_helper, helper.product_reference, ["CodeSignOnCopy"])

  DAEMON_TEMPLATE_PATHS.each { |path| project.main_group.new_file(path) }
  launch_daemon_phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  launch_daemon_phase.name = "Embed Configuration LaunchDaemon"
  launch_daemon_phase.shell_path = "/bin/sh"
  launch_daemon_phase.shell_script = daemon_embedding_script
  launch_daemon_phase.input_paths = DAEMON_TEMPLATE_PATHS.map { |path| "$(SRCROOT)/#{path}" }
  launch_daemon_phase.output_paths = [
    "$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchDaemons/$(LIDPILOT_DAEMON_PLIST_NAME)"
  ]
  launch_daemon_phase.always_out_of_date = "1"
  app.build_phases << launch_daemon_phase

  # Make the app target's dependency graph explicit even when the helper has
  # no source files yet. Xcode will build the helper before the copy phase.
  app.dependencies << project.new(Xcodeproj::Project::Object::PBXTargetDependency) do |dependency|
    dependency.target = helper
  end unless app.dependencies.any? { |dependency| dependency.target == helper }

  project.predictabilize_uuids
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(app, app_tests)
  scheme.add_build_target(helper)
  scheme.add_build_target(cli)
  PROJECT_PATH.mkpath
  scheme.save_as(PROJECT_RELATIVE_PATH.to_s, "LidPilot", true)

  project_invariants(project)
  project.save
  puts "generated #{PROJECT_PATH}"
end

def check
  raise "project is missing: #{PROJECT_PATH}" unless PROJECT_PATH.directory?
  pbx_path = PROJECT_PATH.join("project.pbxproj")
  raise "project file is missing: #{pbx_path}" unless pbx_path.file?
  pbx = File.read(pbx_path)
  required_fragments = [
    "LidPilotRuntime",
    "LidPilotCore",
    APP_TEST_IDENTIFIER,
    "LidPilotAppTests.xctest",
    "LIDPILOT_TESTING",
    SPARKLE_URL,
    "exactVersion",
    SPARKLE_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER = #{APP_IDENTIFIER}",
    "PRODUCT_BUNDLE_IDENTIFIER = #{HELPER_IDENTIFIER}",
    "PRODUCT_BUNDLE_IDENTIFIER = #{DEVELOPMENT_APP_IDENTIFIER}",
    "PRODUCT_BUNDLE_IDENTIFIER = #{DEVELOPMENT_HELPER_IDENTIFIER}",
    "LIDPILOT_DAEMON_PLIST_NAME = #{IDENTITIES.fetch("Debug").fetch("daemon_plist")}",
    "LIDPILOT_DAEMON_PLIST_NAME = #{IDENTITIES.fetch("Release").fetch("daemon_plist")}",
    "Config/App-Info.plist",
    "Config/Helper-Info.plist",
    "Config/LaunchDaemons/#{IDENTITIES.fetch("Debug").fetch("daemon_plist")}",
    "Config/LaunchDaemons/#{IDENTITIES.fetch("Release").fetch("daemon_plist")}",
    "Contents/Library/HelperTools",
    "Library/LaunchDaemons",
    "Embed Configuration LaunchDaemon",
    "CONFIGURATION:-}",
    "actual_label=$(/usr/libexec/PlistBuddy",
    "CREATE_INFOPLIST_SECTION_IN_BINARY = YES"
  ]
  missing = required_fragments.reject { |fragment| pbx.include?(fragment) }
  raise "project is missing expected settings: #{missing.join(", ")}" unless missing.empty?
  expected_app_sources = relative_files("App", ".swift")
  expected_helper_sources = relative_files("Helper", ".swift")
  source_fragments = (expected_app_sources + expected_helper_sources + relative_files("CLI", ".swift") + APP_TEST_SOURCES)
  missing_sources = source_fragments.reject { |source| pbx.include?(source) }
  raise "project is missing source references: #{missing_sources.join(", ")}" unless missing_sources.empty?
  config_inputs = [
    "Config/App-Info.plist",
    "Config/Helper-Info.plist",
    *DAEMON_TEMPLATE_PATHS,
    "Version.xcconfig"
  ]
  config_inputs.each do |path|
    raise "missing project input: #{path}" unless ROOT.join(path).file?
  end
  raise "hostless app test target unexpectedly has a test host" if pbx.include?("TEST_HOST =") || pbx.include?("BUNDLE_LOADER =")
  scheme = PROJECT_PATH.join("xcshareddata/xcschemes/LidPilot.xcscheme")
  raise "LidPilotAppTests is missing from the shared test scheme" unless
    scheme.file? && File.read(scheme).include?("LidPilotAppTests.xctest")
  puts "project configuration is valid"
end

Dir.chdir(ROOT.to_s) do
  if ARGV == ["--check"]
    check
  elsif ARGV.empty?
    generate
  else
    warn "usage: #{File.basename($PROGRAM_NAME)} [--check]"
    exit 64
  end
end
