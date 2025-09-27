import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_toolchain_rs/src/exception.dart';
import 'package:native_toolchain_rs/src/process_runner.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessRunner', () {
    late ProcessRunner processRunner;
    late List<LogRecord> records;

    setUp(() {
      records = [];
      final logger = Logger.detached('test')..onRecord.listen(records.add);
      processRunner = ProcessRunner(logger);
    });

    test('invoke succeeds with exit code 0', () async {
      final result = await processRunner.invoke('echo', ['hello']);
      expect(result.trim(), equals('hello'));
      expect(records, hasLength(1));
      expect(records.single.message, contains('Invoking "echo [hello]'));
    });

    test('invoke throws RustProcessException on non-zero exit code', () {
      expect(
        () => processRunner.invoke('dart', ['run', 'non_existent_file.dart']),
        throwsA(isA<RustProcessException>()),
      );
    });

    test('invoke throws ProcessException on command not found', () {
      expect(
        () => processRunner.invoke('command_not_found', []),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
