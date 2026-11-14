// Builds native/phoedox_sync (Rust, yrs) for the target platform; Dart finds
// it through the asset of lib/sync/native.dart. Needs rustup on the build
// machine (see README).
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await const RustBuilder(
      assetName: 'sync/native.dart',
      cratePath: 'native/phoedox_sync',
    ).run(input: input, output: output);
  });
}
