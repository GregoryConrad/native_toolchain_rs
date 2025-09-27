import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';
import 'package:native_toolchain_rs/src/build_environment.dart';
import 'package:native_toolchain_rs/src/config_mapping.dart';
import 'package:native_toolchain_rs/src/crate_info_validator.dart';
import 'package:native_toolchain_rs/src/crate_resolver.dart';
import 'package:native_toolchain_rs/src/process_runner.dart';
import 'package:path/path.dart' as path;

@internal
interface class RustBuildRunner {
  const RustBuildRunner({
    required this.config,
    required this.logger,
    required this.crateDirectoryResolver,
    required this.processRunner,
    required this.buildEnvironmentFactory,
    required this.crateInfoValidator,
  });

  final RustBuilder config;
  final Logger? logger;
  final CrateDirectoryResolver crateDirectoryResolver;
  final ProcessRunner processRunner;
  final BuildEnvironmentFactory buildEnvironmentFactory;
  final CrateInfoValidator crateInfoValidator;

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
    final codeConfig = input.config.code;
    final CodeConfig(:targetOS, :targetTriple, :linkMode) = codeConfig;
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
    final (
      :crateName,
      :toolchainChannel,
    ) = crateInfoValidator.fetchAndValidateCrateInfo(
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
        if (features.isNotEmpty) ...['--features', features.join(',')],
        ...extraCargoBuildArgs,
      ],
      environment: {
        ...buildEnvironmentFactory.createBuildEnvVars(codeConfig),
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
}
