
import 'package:shared_preferences/shared_preferences.dart';

class AuthStore {
  static const _kTokenKey = 'auth_token_v1';
  String? _token;
  String? get token => _token;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
  }

  Future<void> save(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  Future<void> clear() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }
}
