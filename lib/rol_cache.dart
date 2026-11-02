import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda en el celular el rol del último usuario que inició sesión.
/// Así, al abrir la app, la pantalla correcta aparece al instante (sin esperar a
/// Firestore); el rol real se confirma con el servidor en segundo plano.
class RolCache {
  static SharedPreferences? _prefs;

  static Future<void> cargar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('RolCache: $e');
    }
  }

  static String? rolDe(String uid) => _prefs?.getString('rol_$uid');

  static void guardar(String uid, String rol) {
    if (rolDe(uid) == rol) return;
    _prefs?.setString('rol_$uid', rol);
  }
}
