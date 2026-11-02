import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre apps instaladas en el celular (Yape, bancos) mediante un canal nativo propio
/// (ver MainActivity.kt). Cada paquete debe estar en `<queries>` del AndroidManifest.
class AppsExternas {
  static const MethodChannel _canal = MethodChannel('credisol/apps');

  static const String yape = 'com.bcp.innovacxion.yapeapp';

  /// Apps de bancos que permiten pagar con Plin.
  static const Map<String, String> bancosPlin = {
    'BCP': 'com.bcp.bank.bcp',
    'Interbank': 'pe.com.interbank.mobilebanking',
    'BBVA': 'com.bbva.nxt_peru',
    'Scotiabank': 'pe.com.scotiabank.blpm.android.client',
  };

  static Future<bool> instalada(String paquete) async {
    try {
      return await _canal.invokeMethod<bool>('instalada', {'paquete': paquete}) ?? false;
    } catch (e) {
      debugPrint('AppsExternas.instalada: $e');
      return false;
    }
  }

  /// Abre la app. Devuelve false si no está instalada.
  static Future<bool> abrir(String paquete) async {
    try {
      return await _canal.invokeMethod<bool>('abrir', {'paquete': paquete}) ?? false;
    } catch (e) {
      debugPrint('AppsExternas.abrir: $e');
      return false;
    }
  }

  /// Solo si la app NO está instalada: su ficha en Play Store para instalarla.
  static Future<void> abrirEnPlayStore(String paquete) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('market://details?id=$paquete'), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$paquete'),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
