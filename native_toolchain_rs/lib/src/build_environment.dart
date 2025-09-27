import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:meta/meta.dart';
import 'package:native_toolchain_rs/src/config_mapping.dart';
import 'package:native_toolchain_rs/src/exception.dart';
import 'package:path/path.dart' as path;

@internal
interface class BuildEnvironmentFactory {
  const BuildEnvironmentFactory();

  Map<String, String> createBuildEnvVars(CodeConfig codeConfig) {
    final CodeConfig(:targetOS, :cCompiler) = codeConfig;
    final targetTriple = codeConfig.targetTriple;
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
