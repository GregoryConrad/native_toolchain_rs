import 'dart:io';

import 'package:native_toolchain_rs/src/exception.dart';
import 'package:path/path.dart' as path;

// NOTE: this is an internal implementation detail
// ignore_for_file: public_member_api_docs

final class CrateDirectoryResolver {
  const CrateDirectoryResolver();

  Directory resolveCrateDirectory({
    required String rootPath,
    required List<String> cratePathOptions,
  }) {
    final crateDirectory = cratePathOptions
        .map((option) => path.join(rootPath, option))
        .map(Directory.new)
        .where((dir) => dir.existsSync())
        .firstOrNull;
    if (crateDirectory == null) {
      throw RustValidationException([
        'No options for the crate path ($cratePathOptions) exist at $rootPath',
      ]);
    }
    return crateDirectory;
  }
}
