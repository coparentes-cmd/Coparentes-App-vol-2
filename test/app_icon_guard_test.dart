import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Known Flutter template AppIcon / launcher hashes — must never ship.
const _flutterDefaultIconMd5 = <String>{
  // feature/f3-work before Coparentes icons were restored.
  'c785f8932297af4acd5f5ccb7630f01c',
  // flutter/examples template.
  'a2579d3f6463cb0fee4a900f1ecf8e8f',
};

String _md5File(File file) => md5.convert(file.readAsBytesSync()).toString();

void _assertNotFlutterDefault(File file, {required int minBytes}) {
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  expect(
    file.lengthSync(),
    greaterThan(minBytes),
    reason: '${file.path} looks like a tiny Flutter placeholder',
  );
  final digest = _md5File(file);
  expect(
    _flutterDefaultIconMd5.contains(digest),
    isFalse,
    reason:
        '${file.path} is a Flutter default icon — run ./tool/ensure_app_icons.sh',
  );
}

void main() {
  test('branding 1024 is Coparentes source art', () {
    _assertNotFlutterDefault(
      File('assets/branding/coparentes-app-icon-1024.png'),
      minBytes: 40000,
    );
  });

  test('iOS AppIcon 1024 is not Flutter default', () {
    _assertNotFlutterDefault(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ),
      minBytes: 40000,
    );
  });

  test('Android xxxhdpi launcher is not Flutter default', () {
    _assertNotFlutterDefault(
      File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'),
      minBytes: 4000,
    );
  });
}
