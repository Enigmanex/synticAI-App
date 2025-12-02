import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static Future<void> saveUser(String uid, String email, bool admin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("uid", uid);
    await prefs.setString("email", email);
    await prefs.setBool("admin", admin);
  }

  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "uid": prefs.getString("uid"),
      "email": prefs.getString("email"),
      "admin": prefs.getBool("admin") ?? false,
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
