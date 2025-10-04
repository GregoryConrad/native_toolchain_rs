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

      if (codeConfig.targetOS == OS.android)
        ...const AndroidBuildEnvironmentFactory().createBuildEnvVars(
          codeConfig: codeConfig,
        ),
    };
  }
}

@internal
interface class AndroidBuildEnvironmentFactory {
  const AndroidBuildEnvironmentFactory();

  Map<String, String> createBuildEnvVars({
    required CodeConfig codeConfig,
  }) {
    final CodeConfig(:targetTriple, :cCompiler) = codeConfig;
    if (cCompiler == null) {
      throw UnsupportedError(
        'CCompilerConfig was not provided but is required for $targetTriple',
      );
    }

    String getCompilerPath(String binaryName) {
      final compilerBinariesDir = path.dirname(
        path.fromUri(cCompiler.compiler),
      );
      final binaryPath = path.join(compilerBinariesDir, binaryName);

      if (!File(binaryPath).existsSync()) {
        throw RustValidationException([
          'Binary $binaryPath not found; is your installed NDK too old?',
        ]);
      }

      return binaryPath;
    }

    final targetTripleEnvVar = targetTriple.replaceAll('-', '_');
    final ndkTargetTriple = switch (targetTriple) {
      // NOTE: sometimes the Rust and NDK target triples do not match.
      // See: https://github.com/GregoryConrad/native_toolchain_rs/issues/21#issuecomment-3368307228
      'armv7-linux-androideabi' => 'armv7a-linux-androideabi',
      _ => targetTriple,
    };

    // NOTE: we need to point to NDK >=27 vended LLVM for Android.
    // The `${ndkTargetTriple}35-clang`s were introduced in NDK 27,
    // so using these binaries:
    // 1. Ensures we are using a compatible NDK
    // 2. Also fixes build issues when just using the `clang`s directly
    const apiTarget = '35';
    final clangPath = getCompilerPath('$ndkTargetTriple$apiTarget-clang');
    final clangPpPath = getCompilerPath('$ndkTargetTriple$apiTarget-clang++');

    return {
      'AR_$targetTripleEnvVar': path.fromUri(cCompiler.archiver),
      'CC_$targetTripleEnvVar': clangPath,
      'CXX_$targetTripleEnvVar': clangPpPath,
      'CARGO_TARGET_${targetTripleEnvVar.toUpperCase()}_LINKER': clangPath,
    };
  }
}
