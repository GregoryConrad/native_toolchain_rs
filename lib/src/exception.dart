import 'dart:io';

import 'package:meta/meta.dart';

// NOTE: the API for our exceptions is currently experimental
// ignore_for_file: public_member_api_docs

/// # WARNING
/// This is experimental!
/// It may change on any new release without notice!
/// Please file an issue with your use-case for it, if you do use it.
@experimental
sealed class RustBuildException implements Exception {}

/// # WARNING
/// This is experimental!
/// It may change on any new release without notice!
/// Please file an issue with your use-case for it, if you do use it.
@experimental
final class RustValidationException implements RustBuildException {
  @experimental
  const RustValidationException(this.validationErrors);
  final List<String> validationErrors;

  /// Calls all [functions] and throws an aggregate [RustValidationException]
  /// if any function in [functions] threw.
  /// Otherwise, returns the [functions]' results.
  static List<T> compose<T>(Iterable<T Function()> functions) {
    final response = <T>[];
    final validationErrors = <String>[];

    for (final function in functions) {
      try {
        response.add(function());
      } on RustValidationException catch (e) {
        validationErrors.addAll(e.validationErrors);
      }
    }

    if (validationErrors.isNotEmpty) {
      throw RustValidationException(validationErrors);
    }

    return response;
  }

  @override
  String toString() =>
      'RustValidationException(validationErrors: $validationErrors)';
}

/// # WARNING
/// This is experimental!
/// It may change on any new release without notice!
/// Please file an issue with your use-case for it, if you do use it.
@experimental
final class RustProcessException implements RustBuildException {
  @experimental
  const RustProcessException(this.message, {this.inner});
  final String message;
  final ProcessException? inner;

  @override
  String toString() =>
      'RustProcessException('
      'message: $message, '
      'innerProcessException: ${inner ?? 'none'}'
      ')';
}
