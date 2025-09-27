import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:native_toolchain_rs/src/exception.dart';

@internal
interface class ProcessRunner {
  const ProcessRunner(this.logger);
  final Logger? logger;

  Future<String> invoke(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      logger?.info(
        'Invoking "$executable $arguments" '
        '${workingDirectory != null ? 'in directory $workingDirectory ' : ''}'
        'with environment: ${environment ?? {}}',
      );
      final result = await Process.run(
        executable,
        arguments,
        environment: environment,
        workingDirectory: workingDirectory,
      );
      if (result.exitCode != 0) {
        throw RustProcessException(
          'Process finished with non-zero exit code: "$executable $arguments" '
          'with stdout: "${result.stdout}" and stderr: "${result.stderr}"',
        );
      }
      return result.stdout as String;
    } on ProcessException catch (exception, stackTrace) {
      logger?.severe(
        'Failed to invoke "$executable $arguments"',
        exception,
        stackTrace,
      );
      rethrow;
    }
  }
}

@internal
extension InvokeRustup on ProcessRunner {
  Future<String> invokeRustup(
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      return await invoke(
        'rustup',
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException catch (e) {
      throw RustProcessException(
        'Failed to invoke rustup; is it installed? '
        'For help installing rust, see https://rustup.rs',
        inner: e,
      );
    }
  }
}
