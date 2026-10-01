import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const AndroidOptions secureStorageAndroidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);

const IOSOptions secureStorageIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);

FlutterSecureStorage buildSecureStorage() {
  return const FlutterSecureStorage(
    aOptions: secureStorageAndroidOptions,
    iOptions: secureStorageIOSOptions,
  );
}
