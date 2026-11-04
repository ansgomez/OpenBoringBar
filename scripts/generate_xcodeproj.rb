#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

module OpenBoringBarProjectGenerator
    PROJECT_NAME = 'OpenBoringBar'
    ROOT_PATH = File.expand_path('..', __dir__)
    PROJECT_PATH = File.expand_path("../#{PROJECT_NAME}.xcodeproj", __dir__)
    INFO_PLIST_PATH = 'OpenBoringBar/Resources/Info.plist'
    SOURCE_GLOBS = [
        'OpenBoringBar/App/**/*.swift',
        'OpenBoringBar/Core/**/*.swift'
    ].freeze
    RESOURCE_GLOBS = [
        'OpenBoringBar/Resources/**/*.xcassets'
    ].freeze
    TEST_TARGET_NAME = 'OpenBoringBarTests'
    TEST_SOURCE_GLOBS = [
        'OpenBoringBarTests/**/*.swift'
    ].freeze
    # App sources compiled straight into the test bundle. The bundle has no
    # TEST_HOST, so running tests never launches the bar app. Keep this list
    # to code without app-wide side effects.
    APP_SOURCES_UNDER_TEST = [
        'OpenBoringBar/Core/Domain/Models/PinnedApp.swift',
        'OpenBoringBar/Core/Domain/Models/PinDisplayMode.swift',
        'OpenBoringBar/Core/Domain/Models/PinMove.swift',
        'OpenBoringBar/Core/Domain/Models/PinnedAppsSnapshot.swift',
        'OpenBoringBar/Core/Domain/Models/RunningAppDescriptor.swift',
        'OpenBoringBar/Core/Bar/BottomGuardFramePolicy.swift',
        'OpenBoringBar/Core/Bar/OffScreenWindowRule.swift',
        'OpenBoringBar/Core/Bar/PinnedAppMatcher.swift',
        'OpenBoringBar/Core/Bar/PinnedAppManager.swift',
        'OpenBoringBar/Core/Infrastructure/Application/AeroSpaceOutputParser.swift',
        'OpenBoringBar/Core/Infrastructure/Application/ApplicationLocationProvider.swift',
        'OpenBoringBar/Core/Infrastructure/Persistence/PinnedAppStorageProvider.swift'
    ].freeze

    module_function

    def ensure!
        FileUtils.rm_rf(PROJECT_PATH) if File.exist?(PROJECT_PATH)

        project = Xcodeproj::Project.new(PROJECT_PATH)
        target = project.new_target(:application, PROJECT_NAME, :osx, '14.0')

        file_refs_by_path = {}
        source_files.each do |relative_path|
            group = group_for_file_path(project.main_group, relative_path)
            file_ref = group.new_file(File.basename(relative_path))
            target.add_file_references([file_ref])
            file_refs_by_path[relative_path] = file_ref
        end

        resource_files.each do |relative_path|
            group = group_for_file_path(project.main_group, relative_path)
            file_ref = group.new_file(File.basename(relative_path))
            target.resources_build_phase.add_file_reference(file_ref, true)
        end

        target.build_configurations.each do |config|
            config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.openboringbar.app'
            config.build_settings['SWIFT_VERSION'] = '5.0'
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
            config.build_settings['INFOPLIST_FILE'] = INFO_PLIST_PATH
            config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
            config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
            config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
            config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
        end

        test_target = add_test_target(project, file_refs_by_path)

        project.root_object.attributes['LastUpgradeCheck'] = '1600'
        project.root_object.attributes['LastSwiftUpdateCheck'] = '1600'
        project.save

        # Shared scheme: builds/runs the app, and `xcodebuild test` runs the
        # unit tests. Saved after `project.save` because ensure! recreates
        # the whole project directory.
        scheme = Xcodeproj::XCScheme.new
        scheme.configure_with_targets(target, test_target, launch_target: true)
        scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)
    end

    def add_test_target(project, app_file_refs_by_path)
        test_target = project.new_target(:unit_test_bundle, TEST_TARGET_NAME, :osx, '14.0')

        APP_SOURCES_UNDER_TEST.each do |relative_path|
            file_ref = app_file_refs_by_path.fetch(relative_path) do
                raise "APP_SOURCES_UNDER_TEST lists a missing file: #{relative_path}"
            end
            test_target.add_file_references([file_ref])
        end

        files_matching(TEST_SOURCE_GLOBS).each do |relative_path|
            group = group_for_file_path(project.main_group, relative_path)
            file_ref = group.new_file(File.basename(relative_path))
            test_target.add_file_references([file_ref])
        end

        test_target.build_configurations.each do |config|
            config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.openboringbar.tests'
            config.build_settings['SWIFT_VERSION'] = '5.0'
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
            config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
            config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
        end

        test_target
    end

    def files_matching(patterns)
        patterns
            .flat_map { |pattern| Dir.glob(File.join(ROOT_PATH, pattern)) }
            .select { |path| File.file?(path) }
            .sort
            .map { |path| Pathname.new(path).relative_path_from(Pathname.new(ROOT_PATH)).to_s }
    end

    def source_files
        SOURCE_GLOBS
            .flat_map { |pattern| Dir.glob(File.join(ROOT_PATH, pattern)) }
            .select { |path| File.file?(path) }
            .sort
            .map { |path| Pathname.new(path).relative_path_from(Pathname.new(ROOT_PATH)).to_s }
    end

    def resource_files
        RESOURCE_GLOBS
            .flat_map { |pattern| Dir.glob(File.join(ROOT_PATH, pattern)) }
            .select { |path| File.directory?(path) }
            .sort
            .map { |path| Pathname.new(path).relative_path_from(Pathname.new(ROOT_PATH)).to_s }
    end

    def group_for_file_path(root_group, relative_path)
        directory = File.dirname(relative_path)
        return root_group if directory == '.'

        directory
            .split(File::SEPARATOR)
            .reduce(root_group) do |parent_group, path_component|
                parent_group.groups.find { |group| group.display_name == path_component } ||
                    parent_group.new_group(path_component, path_component)
            end
    end
end

OpenBoringBarProjectGenerator.ensure! if $PROGRAM_NAME == __FILE__
