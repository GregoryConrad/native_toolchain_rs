import 'package:mocktail/mocktail.dart';
import 'package:native_toolchain_rs/src/crate_info_validator.dart';
import 'package:native_toolchain_rs/src/exception.dart';
import 'package:native_toolchain_rs/src/toml_parsing.dart';
import 'package:test/test.dart';

class MockCargoManifestParser extends Mock implements CargoManifestParser {}

class MockToolchainTomlParser extends Mock implements ToolchainTomlParser {}

void main() {
  group('CrateInfoValidator', () {
    late CrateInfoValidator validator;
    late MockToolchainTomlParser mockToolchainTomlParser;
    late MockCargoManifestParser mockCargoManifestParser;

    setUp(() {
      mockToolchainTomlParser = MockToolchainTomlParser();
      mockCargoManifestParser = MockCargoManifestParser();
      validator = CrateInfoValidator(
        toolchainTomlParser: mockToolchainTomlParser,
        cargoManifestParser: mockCargoManifestParser,
      );
    });

    test('fetchAndValidateCrateInfo returns correct info on success', () {
      when(() => mockCargoManifestParser.parseManifest(any())).thenReturn((
        crateName: 'my_crate',
        libCrateTypes: ['staticlib', 'cdylib'],
      ));
      when(() => mockToolchainTomlParser.parseToolchainToml(any())).thenReturn((
        channel: '1.90.0',
        targets: {'aarch64-linux-android'},
      ));

      final result = validator.fetchAndValidateCrateInfo(
        manifestPath: 'dummy_manifest_path',
        toolchainTomlPath: 'dummy_toolchain_path',
        targetTriple: 'aarch64-linux-android',
      );

      expect(result.crateName, 'my_crate');
      expect(result.toolchainChannel, '1.90.0');
    });

    test('fetchAndValidateCrateInfo throws exception on validation issues', () {
      when(() => mockCargoManifestParser.parseManifest(any())).thenReturn((
        crateName: 'my_crate',
        libCrateTypes: ['staticlib'],
      ));
      when(() => mockToolchainTomlParser.parseToolchainToml(any())).thenReturn((
        channel: 'stable',
        targets: {'x86_64-linux-gnu'},
      ));

      expect(
        () => validator.fetchAndValidateCrateInfo(
          manifestPath: 'dummy_manifest_path',
          toolchainTomlPath: 'dummy_toolchain_path',
          targetTriple: 'aarch64-linux-android',
        ),
        throwsA(
          isA<RustValidationException>().having(
            (e) => e.validationErrors,
            'validationErrors',
            containsAll([
              '''Cargo.toml must specify [staticlib, cdylib] under lib.crate-types''',
              '''Your current channel in rust-toolchain.toml is stable; this is dangerous and consequently is not allowed! Please specify an exact version to fix this issue.''',
              '''aarch64-linux-android is not one of the supported targets: {x86_64-linux-gnu}''',
            ]),
          ),
        ),
      );
    });
  });
}
