import 'package:meta/meta.dart';
import 'package:native_toolchain_rs/src/exception.dart';
import 'package:native_toolchain_rs/src/toml_parsing.dart';

@internal
interface class CrateInfoValidator {
  const CrateInfoValidator({
    required this.toolchainTomlParser,
    required this.cargoManifestParser,
  });

  final ToolchainTomlParser toolchainTomlParser;
  final CargoManifestParser cargoManifestParser;

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

        if (toolchainIssues.isNotEmpty) {
          throw RustValidationException(toolchainIssues);
        }

        return channel;
      },
    ]);

    return (crateName: crateName, toolchainChannel: toolchainChannel);
  }
}
