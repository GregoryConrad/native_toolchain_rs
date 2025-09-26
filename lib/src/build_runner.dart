import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';
import 'package:native_toolchain_rs/src/crate_resolver.dart';
import 'package:native_toolchain_rs/src/process_runner.dart';
import 'package:native_toolchain_rs/src/toml_parsing.dart';
import 'package:path/path.dart' as path;

// NOTE: this is an internal implementation detail
// ignore_for_file: public_member_api_docs

final class RustBuildRunner {
  const RustBuildRunner({
    required this.config,
    required this.logger,
    required this.crateDirectoryResolver,
    required this.tomlDocumentWrapperFactory,
    required this.toolchainTomlParser,
    required this.cargoManifestParser,
    required this.processRunner,
  });

  final RustBuilder config;
  final Logger? logger;
  final CrateDirectoryResolver crateDirectoryResolver;
  final TomlDocumentWrapperFactory tomlDocumentWrapperFactory;
  final ToolchainTomlParser toolchainTomlParser;
  final CargoManifestParser cargoManifestParser;
  final ProcessRunner processRunner;

  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
    required List<AssetRouting> assetRouting,
  }) async {
    logger?.info('Starting build of Rust native assets');
    logger?.config(input);
    logger?.config(Platform.environment);

    if (!input.config.buildCodeAssets) {
      logger?.info(
        'buildCodeAssets is false; '
        'skipping build of Rust native assets',
      );
      return;
    }

    logger?.info('Gathering all data required for the build');
    final CodeConfig(:targetOS, :targetTriple, :linkMode) = input.config.code;
    final RustBuilder(
      :assetName,
      :cratePath,
      :features,
      :enableDefaultFeatures,
      :extraCargoBuildArgs,
      :extraCargoEnvironmentVariables,
      buildMode: BuildMode(name: cargoBuildMode),
    ) = config;
    final crateDirectory = crateDirectoryResolver.resolveCrateDirectory(
      rootPath: path.fromUri(input.packageRoot),
      cratePathOptions: cratePath != null ? [cratePath] : ['rust', 'native'],
    );
    final outputDir = path.join(path.fromUri(input.outputDirectory), 'target');
    final manifestPath = path.join(crateDirectory.path, 'Cargo.toml');
    final (:crateName, :toolchainChannel) = fetchAndValidateCrateInfo(
      targetTriple: targetTriple,
      manifestPath: manifestPath,
      toolchainTomlPath: path.join(crateDirectory.path, 'rust-toolchain.toml'),
    );

    // NOTE: re-run build whenever anything in the Rust directory changes
    output.dependencies.add(crateDirectory.uri);

    logger?.info('Ensuring $toolchainChannel is installed');
    await ensureToolchainDownloaded(crateDirectory.path);

    logger?.info('Running cargo build');
    await processRunner.invokeRustup(
      [
        'run',
        toolchainChannel,
        'cargo',
        'build',
        '--$cargoBuildMode',
        '--manifest-path',
        manifestPath,
        '--package',
        crateName,
        '--target',
        targetTriple,
        '--target-dir',
        outputDir,
        if (!enableDefaultFeatures) '--no-default-features',
        if (features.isNotEmpty) ...[
          '--features',
          features.join(','),
        ],
        ...extraCargoBuildArgs,
      ],
      environment: {
        ...createBuildEnvVars(input.config.code),
        ...extraCargoEnvironmentVariables,
      },
    );

    for (final routing in assetRouting) {
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: assetName,
          linkMode: linkMode,
          file: path.toUri(
            path.join(
              outputDir,
              targetTriple,
              cargoBuildMode,
              targetOS.libraryFileName(crateName, linkMode),
            ),
          ),
        ),
        routing: routing,
      );
    }
  }

  Future<void> ensureToolchainDownloaded(String crateDirectory) async {
    // NOTE: invoking rustup automatically downloads the toolchain
    // in rust-toolchain.toml, if not already downloaded.
    logger?.config(
      await processRunner.invokeRustup([
        'show',
        'active-toolchain',
      ], workingDirectory: crateDirectory),
    );
  }

  ({String crateName, String toolchainChannel}) fetchAndValidateCrateInfo({
    required String manifestPath,
    required String toolchainTomlPath,
    required String targetTriple,
  }) {
    final [
      String crateName,
      String toolchainChannel,
    ] = RustValidationException.compose<dynamic>([
      () {
        final (:crateName, :libCrateTypes) = cargoManifestParser.parseManifest(
          manifestPath,
        );

        const requiredTypes = ['staticlib', 'cdylib'];
        if (!requiredTypes.every(libCrateTypes.contains)) {
          throw RustValidationException([
            'Cargo.toml must specify $requiredTypes under lib.crate-types',
          ]);
        }

        return crateName;
      },
      () {
        final (:channel, :targets) = toolchainTomlParser.parseToolchainToml(
          toolchainTomlPath,
        );

        final toolchainIssues = <String>[];

        const deniedChannels = {'stable', 'beta', 'nightly'};
        if (deniedChannels.contains(channel)) {
          toolchainIssues.add(
            'Your current channel in rust-toolchain.toml is $channel; '
            'this is dangerous and consequently is not allowed! '
            'Please specify an exact version to fix this issue.',
          );
        }

        if (!targets.contains(targetTriple)) {
          toolchainIssues.add(
            '$targetTriple is not one of the supported targets: $targets',
          );
        }

        return channel;
      },
    ]);

    return (crateName: crateName, toolchainChannel: toolchainChannel);
  }

  Map<String, String> createBuildEnvVars(CodeConfig codeConfig) {
    final CodeConfig(:targetOS, :targetTriple, :cCompiler) = codeConfig;
    final targetTripleEnvVar = targetTriple.replaceAll('-', '_');

    String getBinary(String binaryName) {
      if (cCompiler == null) {
        throw UnsupportedError(
          'CCompilerConfig was not provided but is required for $targetTriple',
        );
      }

      final binaryPath = path.join(
        path.dirname(path.fromUri(cCompiler.compiler)),
        OS.current.executableFileName(binaryName),
      );

      if (!File(binaryPath).existsSync()) {
        throw RustValidationException([
          'Binary $binaryPath not found; is your installed compiler too old?',
        ]);
      }

      return binaryPath;
    }

    return {
      // NOTE: XCode makes some injections into PATH that break host build
      // for crates with a build.rs
      // See also: https://github.com/irondash/native_toolchain_rust/issues/17
      if (Platform.isMacOS) ...{
        'PATH': Platform.environment['PATH']!
            .split(':')
            .where((e) => !e.contains('Contents/Developer/'))
            .join(':'),
      },

      // NOTE: we need to point to NDK >=27 vended LLVM for Android.
      // The `${targetTriple}35-clang`s were introduced in NDK 27,
      // so using these binaries:
      // 1. Ensures we are using a compatible NDK
      // 2. Also fixes build issues when just using the `clang`s directly
      if (targetOS == OS.android) ...{
        'AR_$targetTripleEnvVar': getBinary('llvm-ar'),
        'CC_$targetTripleEnvVar': getBinary('${targetTriple}35-clang'),
        'CXX_$targetTripleEnvVar': getBinary('${targetTriple}35-clang++'),
        'CARGO_TARGET_${targetTripleEnvVar.toUpperCase()}_LINKER': getBinary(
          '${targetTriple}35-clang',
        ),
      },
    };
  }
}

extension on CodeConfig {
  String get targetTriple {
    return switch ((targetOS, targetArchitecture)) {
      // Android
      (OS.android, Architecture.arm64) => 'aarch64-linux-android',
      (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
      (OS.android, Architecture.x64) => 'x86_64-linux-android',

      // iOS
      (OS.iOS, Architecture.arm64)
          when iOS.targetSdk == IOSSdk.iPhoneSimulator =>
        'aarch64-apple-ios-sim',
      (OS.iOS, Architecture.arm64) when iOS.targetSdk == IOSSdk.iPhoneOS =>
        'aarch64-apple-ios',
      (OS.iOS, Architecture.arm64) => throw UnsupportedError(
        'Unknown IOSSdk: ${iOS.targetSdk}',
      ),
      (OS.iOS, Architecture.x64) => 'x86_64-apple-ios',

      // Windows
      (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
      (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',

      // Linux
      (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
      (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',

      // macOS
      (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
      (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',

      (_, _) => throw UnsupportedError(
        'Unsupported target: $targetOS on $targetArchitecture',
      ),
    };
  }

  LinkMode get linkMode {
    return switch (linkModePreference) {
      LinkModePreference.dynamic ||
      LinkModePreference.preferDynamic => DynamicLoadingBundled(),
      LinkModePreference.static ||
      LinkModePreference.preferStatic => StaticLinking(),
      _ => throw UnsupportedError(
        'Unsupported LinkModePreference: $linkModePreference',
      ),
    };
  }
}
