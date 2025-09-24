<p align="center">
<a href="https://github.com/GregoryConrad/native_toolchain_rs/actions"><img src="https://github.com/GregoryConrad/native_toolchain_rs/actions/workflows/build.yml/badge.svg" alt="Build Status"></a>
<a href="https://github.com/GregoryConrad/native_toolchain_rs"><img src="https://img.shields.io/github/stars/GregoryConrad/native_toolchain_rs.svg?style=flat&logo=github&colorB=deeppink&label=stars" alt="Github Stars"></a>
<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="MIT License"></a>
</p>

# native_toolchain_rs
Rust support for Dart's Native Assets.

---

## Why native_toolchain_rs?
1. It's opinionated.
   That might sound bad, but it's opinionated in the way that _keeps you from shooting yourself in the foot_.
2. Does more with less.
   The API is incredibly easy to use: the only thing you _need_ to provide is `assetName`,
   and the rest is auto-magically figured out.
   (But you can still tweak the functionality as much as you need to!)


## Getting Started
1. Install [rustup](https://rustup.rs), for Rust, on your development computer
   (if you are a library author, consumers of your package will have to do the same)
2. Run `flutter pub add native_toolchain_rs` for Flutter or `dart pub add native_toolchain_rs` for Dart-only
3. (Until [Native Assets](https://github.com/dart-lang/sdk/issues/50565) is fully released) Switch to Flutter's beta channel: `flutter channel beta`
4. See [Code Setup](#code-setup)


## Code Setup
`native_toolchain_rs` will look (by default) for `native/` or `rust/` (customizable)
in your Dart package's root.
Create a `Cargo.toml` and `rust-toolchain.toml` in your chosen Rust sources directory;
keep reading for what these two files must contain
(but don't worry if you forget, you'll get a helpful error message).

### Quick n' dirty ("it just works") setup
```dart
// hook/build.dart:
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await RustBuilder(
      assetName: 'src/my_ffi_bindings.g.dart',
    ).run(input: input, output: output);
  });
}
```

### Recommended setup (so you get logs)
```dart
// hook/build.dart:
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';

void main(List<String> args) async {
  Logger.root.level = Level.CONFIG; // or whatever level you prefer

  await build(args, (input, output) async {
    final logger = Logger('my_package_build')..onRecord.listen(print);

    await RustBuilder(
      assetName: 'src/my_ffi_bindings.g.dart',
      // ...maybe enable some Cargo features or something in here too
    ).run(
      input: input,
      output: output,
      logger: logger,
    );
  });
}
```

### `Cargo.toml`
Keep at least the following in your `Cargo.toml`.
```toml
[package]
name = "my-crate-name" # name it whatever you want, doesn't matter

[lib]
crate-type = ["staticlib", "cdylib"] # THESE ARE IMPORTANT!
```

### `rust-toolchain.toml`
Keep at least the following in your `rust-toolchain.toml`.
```toml
[toolchain]
channel = "1.90.0" # or newer, but *do not* use stable, beta, or nightly alone (without a version number)!

# The targets you want to support; these are the default:
targets = [
  # Android
  "armv7-linux-androideabi",
  "aarch64-linux-android",
  "x86_64-linux-android",

  # iOS (device + simulator)
  "aarch64-apple-ios",
  "aarch64-apple-ios-sim",
  "x86_64-apple-ios",

  # Windows
  "aarch64-pc-windows-msvc",
  "x86_64-pc-windows-msvc",

  # Linux
  "aarch64-unknown-linux-gnu",
  "x86_64-unknown-linux-gnu",

  # macOS
  "aarch64-apple-darwin",
  "x86_64-apple-darwin",
]
```
