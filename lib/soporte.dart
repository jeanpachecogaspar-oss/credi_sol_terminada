import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config_prestamos.dart';

/// Abre una conversación de WhatsApp con soporte, con un mensaje inicial.
Future<void> abrirWhatsApp(BuildContext context, {String mensaje = 'Hola, necesito ayuda con mi préstamo.'}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.parse(
    'https://wa.me/${ConfigEmpresa.whatsappSoporte}?text=${Uri.encodeComponent(mensaje)}',
  );
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('no abrió');
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp. Verifica que esté instalado.')),
    );
  }
}

/// Botón reutilizable de soporte.
class BotonWhatsApp extends StatelessWidget {
  final String? mensaje;
  const BotonWhatsApp({super.key, this.mensaje});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => mensaje == null ? abrirWhatsApp(context) : abrirWhatsApp(context, mensaje: mensaje!),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E9E52),
        side: const BorderSide(color: Color(0xFF1E9E52)),
      ),
      icon: const Icon(Icons.chat_rounded, size: 18),
      label: const Text('Escríbenos por WhatsApp'),
    );
  }
}
