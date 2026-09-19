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
HELPER_LABEL = "com.lidpilot.app.helper"
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

def configure_target_settings(target, identifier, info_plist, helper: false)
  target.build_configurations.each do |config|
    release = config.name == "Release"
    configure_common_settings(config, release: release)
    config.build_settings.merge!(
      "CODE_SIGN_ENTITLEMENTS" => "",
      "INFOPLIST_FILE" => info_plist,
      "INSTALL_PATH" => helper ? "$(CONTENTS_FOLDER_PATH)" : "$(LOCAL_APPS_DIR)",
      "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/../Frameworks"],
      "PRODUCT_BUNDLE_IDENTIFIER" => identifier,
      "PRODUCT_NAME" => helper ? "LidPilotHelper" : "LidPilot",
      "SKIP_INSTALL" => helper ? "YES" : "NO"
    )
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

def project_invariants(project)
  targets = project.targets.to_h { |target| [target.name, target] }
  app = targets["LidPilot"]
  helper = targets["LidPilotHelper"]
  raise "missing LidPilot application target" unless app
  raise "missing LidPilotHelper tool target" unless helper

  app_id = app.build_configurations.first.build_settings["PRODUCT_BUNDLE_IDENTIFIER"]
  helper_id = helper.build_configurations.first.build_settings["PRODUCT_BUNDLE_IDENTIFIER"]
  raise "unexpected app bundle identifier: #{app_id.inspect}" unless app_id == APP_IDENTIFIER
  raise "unexpected helper bundle identifier: #{helper_id.inspect}" unless helper_id == HELPER_IDENTIFIER

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

  daemon = ROOT.join("Config/LaunchDaemons/#{HELPER_LABEL}.plist")
  raise "LaunchDaemon template missing: #{daemon}" unless daemon.file?
  true
end

def generate
  project = Xcodeproj::Project.new(PROJECT_RELATIVE_PATH.to_s)
  project.root_object.attributes["LastUpgradeCheck"] = "2700"
  project.root_object.development_region = "en"
  project.root_object.known_regions = ["en", "Base"]

  app = project.new_target(:application, "LidPilot", :osx, "15.0")
  helper = project.new_target(:tool, "LidPilotHelper", :osx, "15.0")
  helper.product_type = "com.apple.product-type.tool"
  app.product_reference.name = "LidPilot.app"
  helper.product_reference.name = "LidPilotHelper"

  xcconfig_reference = project.main_group.new_file("Version.xcconfig")
  project.build_configurations.each do |config|
    config.base_configuration_reference = xcconfig_reference
  end
  configure_target_settings(app, APP_IDENTIFIER, "Config/App-Info.plist")
  configure_target_settings(helper, HELPER_IDENTIFIER, "Config/Helper-Info.plist", helper: true)

  add_group_files(project, app, "App", "App", ".swift")
  add_group_files(project, helper, "Helper", "Helper", ".swift")
  ["App/Assets.xcassets", "LICENSE", "THIRD_PARTY_NOTICES.md"].each do |path|
    app.resources_build_phase.add_file_reference(project.main_group.new_file(path))
  end

  root_package = add_package_reference(project, ".")
  core_package = add_package_reference(project, "Core")
  [app, helper].each do |target|
    add_package_product(target, root_package, "LidPilotRuntime")
    add_package_product(target, core_package, "LidPilotCore")
  end

  sparkle_package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  sparkle_package.repositoryURL = SPARKLE_URL
  sparkle_package.requirement = { "kind" => "exactVersion", "version" => SPARKLE_VERSION }
  project.root_object.package_references << sparkle_package
  add_package_product(app, sparkle_package, "Sparkle")

  # xcodeproj's UUID generator includes PBXContainerItemProxy references in
  # the dependency path.  Those references contain the target/root UUIDs, so
  # generating the dependency in the same pass would hash random UUIDs.  Give
  # the targets and their existing graph stable UUIDs before creating the
  # proxy, then run the normal generator again after the dependency exists.
  project.predictabilize_uuids
  app.add_dependency(helper)
  embed_helper = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_helper.name = "Embed LidPilotHelper"
  embed_helper.dst_subfolder_spec = "1"
  embed_helper.dst_path = "Contents/Library/HelperTools"
  app.build_phases << embed_helper
  add_copy_file(project, embed_helper, helper.product_reference, ["CodeSignOnCopy"])

  daemon_reference = project.main_group.new_file("Config/LaunchDaemons/#{HELPER_LABEL}.plist")
  launch_daemon_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  launch_daemon_phase.name = "Embed LaunchDaemon"
  launch_daemon_phase.dst_subfolder_spec = "1"
  launch_daemon_phase.dst_path = "Contents/Library/LaunchDaemons"
  app.build_phases << launch_daemon_phase
  add_copy_file(project, launch_daemon_phase, daemon_reference)

  # Make the app target's dependency graph explicit even when the helper has
  # no source files yet. Xcode will build the helper before the copy phase.
  app.dependencies << project.new(Xcodeproj::Project::Object::PBXTargetDependency) do |dependency|
    dependency.target = helper
  end unless app.dependencies.any? { |dependency| dependency.target == helper }

  project.predictabilize_uuids
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(app, nil)
  scheme.add_build_target(helper)
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
    SPARKLE_URL,
    "exactVersion",
    SPARKLE_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER = #{APP_IDENTIFIER}",
    "PRODUCT_BUNDLE_IDENTIFIER = #{HELPER_IDENTIFIER}",
    "Config/App-Info.plist",
    "Config/Helper-Info.plist",
    "Config/LaunchDaemons/#{HELPER_LABEL}.plist",
    "Contents/Library/HelperTools",
    "Contents/Library/LaunchDaemons",
    "CREATE_INFOPLIST_SECTION_IN_BINARY = YES"
  ]
  missing = required_fragments.reject { |fragment| pbx.include?(fragment) }
  raise "project is missing expected settings: #{missing.join(", ")}" unless missing.empty?
  expected_app_sources = relative_files("App", ".swift")
  expected_helper_sources = relative_files("Helper", ".swift")
  source_fragments = (expected_app_sources + expected_helper_sources)
  missing_sources = source_fragments.reject { |source| pbx.include?(source) }
  raise "project is missing source references: #{missing_sources.join(", ")}" unless missing_sources.empty?
  ["Config/App-Info.plist", "Config/Helper-Info.plist", "Config/LaunchDaemons/#{HELPER_LABEL}.plist", "Version.xcconfig"].each do |path|
    raise "missing project input: #{path}" unless ROOT.join(path).file?
  end
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
