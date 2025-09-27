import 'package:dart_only_example/dart_only_example.dart';
import 'package:test/test.dart';

void main() {
  test('rust_add correctly adds', () {
    expect(rust_add(1, 1), equals(2));
  });
}
