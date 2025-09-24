import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_toolchain_rs/src/exception.dart';
import 'package:toml/toml.dart';

// NOTE: this is an internal implementation detail
// ignore_for_file: public_member_api_docs

final class TomlDocumentWrapperFactory {
  const TomlDocumentWrapperFactory(this.logger);
  final Logger? logger;

  TomlDocumentWrapper parseFile(String filePath) =>
      TomlDocumentWrapper(logger, filePath, TomlDocument.loadSync(filePath));
}

final class TomlDocumentWrapper {
  const TomlDocumentWrapper(this.logger, this.filePath, this.document);

  final Logger? logger;
  final String filePath;
  final TomlDocument document;

  T walk<T>(String path) {
    try {
      dynamic currNode = document.toMap();
      for (final field in path.split('.')) {
        // NOTE: we are traversing this manually, dynamic is a must
        // ignore: avoid_dynamic_calls
        currNode = currNode[field];
      }
      return currNode as T;
    } on Object catch (exception, stackTrace) {
      logger?.severe(
        'Failed to find $path in $filePath: $document',
        exception,
        stackTrace,
      );
      throw RustValidationException(['Could not find $path in $filePath']);
    }
  }
}

final class CargoManifestParser {
  const CargoManifestParser(this.logger, this.tomlDocumentFactory);
  final Logger? logger;
  final TomlDocumentWrapperFactory tomlDocumentFactory;

  ({String crateName, List<String> libCrateTypes}) parseManifest(
    String manifestPath,
  ) {
    logger?.info('Looking for Cargo.toml');
    if (!File(manifestPath).existsSync()) {
      throw RustValidationException(['$manifestPath not found']);
    }

    logger?.info('Parsing Cargo.toml');
    final TomlDocumentWrapper manifest;
    try {
      manifest = tomlDocumentFactory.parseFile(manifestPath);
    } on Object catch (exception, stackTrace) {
      logger?.severe('Failed to parse Cargo.toml', exception, stackTrace);
      throw RustValidationException(['Failed to parse Cargo.toml: $exception']);
    }

    final [
      String crateName,
      List<String> libCrateTypes,
    ] = RustValidationException.compose<dynamic>([
      () => manifest.walk<String>('package.name'),
      () => manifest.walk<List<dynamic>>('lib.crate-type').cast<String>(),
    ]);

    return (
      crateName: crateName,
      libCrateTypes: libCrateTypes,
    );
  }
}

final class ToolchainTomlParser {
  const ToolchainTomlParser(this.logger, this.tomlDocumentFactory);
  final Logger? logger;
  final TomlDocumentWrapperFactory tomlDocumentFactory;

  ({Set<String> targets, String channel}) parseToolchainToml(
    String toolchainTomlPath,
  ) {
    logger?.info('Looking for rust-toolchain.toml');
    if (!File(toolchainTomlPath).existsSync()) {
      throw RustValidationException(['$toolchainTomlPath not found']);
    }

    logger?.info('Parsing rust-toolchain.toml');
    final TomlDocumentWrapper toolchain;
    try {
      toolchain = tomlDocumentFactory.parseFile(toolchainTomlPath);
    } on Object catch (e, stackTrace) {
      logger?.severe('Failed to parse rust-toolchain.toml', e, stackTrace);
      throw RustValidationException([
        'Failed to parse rust-toolchain.toml: $e',
      ]);
    }

    final [
      String channel,
      Set<String> targets,
    ] = RustValidationException.compose<dynamic>([
      () => toolchain.walk<String>('toolchain.channel'),
      () => toolchain
          .walk<List<dynamic>>('toolchain.targets')
          .cast<String>()
          .toSet(),
    ]);

    return (
      channel: channel,
      targets: targets,
    );
  }
}
