import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

Future<void> saveSecureValue(String key, String value) async {
  await secureStorage.write(key: key, value: value);
}

Future<String?> loadSecureValue(String key) async {
  return secureStorage.read(key: key);
}

Future<void> deleteSecureValue(String key) async {
  await secureStorage.delete(key: key);
}
