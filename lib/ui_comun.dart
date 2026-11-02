import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'errores.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'formato.dart';

DateTime? aFecha(dynamic v) => v is Timestamp ? v.toDate() : null;
double aNum(dynamic v) => (v as num?)?.toDouble() ?? 0;

String haceTiempo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}

String fechaHora(DateTime d) =>
    '${fmtFecha(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Color colorEstado(String e) {
  switch (e) {
    case 'Activo':
      return AppColors.azul;
    case 'Pagado':
    case 'Pagada':
    case 'Confirmado':
    case 'Entregado':
      return AppColors.verde;
    case 'Rechazado':
    case 'Rechazada':
    case 'Vencida':
      return AppColors.rojo;
    case 'Pendiente':
    case 'Por verificar':
      return AppColors.ambar;
    default:
      return AppColors.gris;
  }
}

Widget chipEstado(String texto) {
  final color = colorEstado(texto);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

Widget tarjetaBlanca({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: AppColors.azul.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
      ],
    ),
    child: child,
  );
}

Widget filaDato(String titulo, String valor, {bool destacado = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5))),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: destacado ? 16 : 14,
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              color: destacado ? AppColors.azul : null,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget mensajeVacio(IconData icono, String titulo, String texto) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    ),
  );
}

/// Pantalla de error de una consulta, con reintento y, si falta un índice,
/// botones para crearlo o copiar el enlace.
Widget errorConsulta(BuildContext context, String titulo, Object error, VoidCallback onReintentar) {
  debugPrint('$titulo: $error');
  final enlace = enlaceIndice(error);
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(mensajeError(error), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          if (enlace != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => abrirUrl(context, enlace),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Crear índice'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: enlace));
                  messenger.showSnackBar(const SnackBar(content: Text('Enlace copiado')));
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar enlace'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

Widget filtroChips({
  required List<(String, String)> opciones,
  required String actual,
  required ValueChanged<String> onChanged,
}) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Row(
      children: [
        for (final o in opciones)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.$2),
              selected: actual == o.$1,
              onSelected: (_) => onChanged(o.$1),
            ),
          ),
      ],
    ),
  );
}

Future<void> abrirUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

/// Pide un texto obligatorio (por ejemplo, el motivo de un rechazo). Devuelve null si cancela.
Future<String?> pedirMotivo(BuildContext context, String titulo) {
  final ctrl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 300,
          onChanged: (_) {
            if (error != null) setDialog(() => error = null);
          },
          decoration: InputDecoration(hintText: 'Escribe el motivo', errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.length < 3) {
                setDialog(() => error = 'El motivo debe tener al menos 3 caracteres');
                return;
              }
              Navigator.pop(ctx, t);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, String boton) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(boton)),
      ],
    ),
  );
  return r == true;
}