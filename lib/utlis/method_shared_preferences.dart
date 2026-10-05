import 'package:shared_preferences/shared_preferences.dart';

// 存
Future<void> saveValue(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

// 读
Future<String?> loadValue(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}
