import 'dart:io';

import 'package:jnigen/jnigen.dart';

/// Generates JNI bindings for the Android native classes.
///
/// Run with:
///   cd example && flutter build apk --debug && cd .. && dart run tool/jnigen.dart
void main(List<String> args) {
  final packageRoot = Platform.script.resolve('../');
  generateJniBindings(
    Config(
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          path: packageRoot.resolve(
            'lib/src/platforms/android/bindings.g.dart',
          ),
          structure: OutputStructure.singleFile,
        ),
      ),
      sourcePath: [packageRoot.resolve('android/src/main/kotlin')],
      classPath: [
        packageRoot.resolve(
          'example/build/file_saver_ffi/tmp/kotlin-classes/debug',
        ),
        packageRoot.resolve(
          'example/build/file_saver_ffi/tmp/kotlin-classes/release',
        ),
      ],
      classes: [
        'com.vanvixi.file_saver_ffi.FileSaver',
        'com.vanvixi.file_saver_ffi.models.ProgressCallback',
      ],
    ),
  );
}
