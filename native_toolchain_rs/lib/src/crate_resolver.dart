import 'dart:io';

import 'package:meta/meta.dart';
import 'package:native_toolchain_rs/src/exception.dart';
import 'package:path/path.dart' as path;

@internal
interface class CrateDirectoryResolver {
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
        '''
Could not find the crate directory.
The following paths were checked: $cratePathOptions at $rootPath.
Please make sure that the crate is in one of these locations, or explicitly specify the `cratePath` in your `RustBuilder`.
For more information, see https://github.com/GregoryConrad/native_toolchain_rs?tab=readme-ov-file#code-setup''',
      ]);
    }
    return crateDirectory;
  }
}
