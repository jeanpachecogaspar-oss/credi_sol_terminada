import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'formato.dart';

/// Recordatorios locales de cuotas (sin servidor ni costo).
///
/// Se programan en el propio celular a partir de las cuotas 'Pendiente' de los
/// préstamos activos del cliente: 3 días antes y el día del vencimiento, a las 9:00
/// (hora de Lima). Se recalculan al abrir la app, al volver a ella y después de
/// reportar un pago. Limitación: si el cliente no abre la app después de que se
/// aprueba su préstamo, ese préstamo no tendrá recordatorios.
class Recordatorios {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static DateTime? _ultimaSync;

  static const int _maxCuotas = 12; // 24 avisos como máximo; Android limita las alarmas por app.
  static const int _horaAviso = 9;

  static const AndroidNotificationDetails _canal = AndroidNotificationDetails(
    'recordatorios_cuotas',
    'Recordatorios de cuotas',
    channelDescription: 'Avisos antes del vencimiento de tus cuotas',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF1E88E5),
  );

  static Future<void>? _iniciando;

  /// Se llama en main() sin esperar. Nunca lanza errores: si falla, la app sigue sin recordatorios.
  /// Llamarla varias veces devuelve la misma tarea.
  static Future<void> iniciar() => _iniciando ??= _iniciar();

  static Future<void> _iniciar() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Lima'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Silueta blanca de los 3 círculos (res/drawable-*/ic_notificacion.png).
          android: AndroidInitializationSettings('ic_notificacion'),
        ),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Recordatorios: no se pudieron iniciar: $e');
    }
  }

  /// Vuelve a programar los recordatorios del cliente. Con [forzar] = false
  /// se ejecuta como máximo una vez cada 30 minutos para ahorrar lecturas.
  static Future<void> sincronizar(String uid, {bool forzar = false}) async {
    await iniciar();
    if (!_listo) return;
    final ahora = DateTime.now();
    if (!forzar && _ultimaSync != null && ahora.difference(_ultimaSync!) < const Duration(minutes: 30)) return;
    _ultimaSync = ahora;

    try {
      final db = FirebaseFirestore.instance;
      final prestamos = await db
          .collection('prestamos')
          .where('clienteId', isEqualTo: uid)
          .where('estado', isEqualTo: 'Activo')
          .get();

      final pendientes = <({DateTime fecha, int numero, double monto})>[];
      for (final p in prestamos.docs) {
        final cuotas = await p.reference.collection('cuotas').where('estado', isEqualTo: 'Pendiente').get();
        for (final c in cuotas.docs) {
          final d = c.data();
          final f = d['fecha'];
          if (f is! Timestamp) continue;
          pendientes.add((
            fecha: f.toDate(),
            numero: (d['numero'] as num?)?.toInt() ?? 0,
            monto: (d['cuota'] as num?)?.toDouble() ?? 0,
          ));
        }
      }

      await _plugin.cancelAll();
      if (pendientes.isEmpty) return;

      // El permiso se pide solo cuando hay algo que recordar (Android 13+).
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      pendientes.sort((a, b) => a.fecha.compareTo(b.fecha));
      final ahoraLima = tz.TZDateTime.now(tz.local);
      var id = 0;
      for (final c in pendientes.take(_maxCuotas)) {
        final vence = tz.TZDateTime(tz.local, c.fecha.year, c.fecha.month, c.fecha.day, _horaAviso);
        final avisos = [
          (vence.subtract(const Duration(days: 3)), 'Tu cuota vence en 3 días'),
          (vence, 'Tu cuota vence hoy'),
        ];
        for (final (cuando, titulo) in avisos) {
          id++;
          if (!cuando.isAfter(ahoraLima)) continue;
          await _plugin.zonedSchedule(
            id: id,
            scheduledDate: cuando,
            notificationDetails: const NotificationDetails(android: _canal),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: titulo,
            body: 'Cuota ${c.numero} por ${fmtMoney(c.monto)} · vence el ${fmtFecha(c.fecha)}. '
                'Paga con Yape, Plin o transferencia desde la app.',
          );
        }
      }
    } catch (e) {
      debugPrint('Recordatorios: no se pudieron programar: $e');
    }
  }

  /// Al cerrar sesión: que el siguiente usuario del celular no reciba avisos ajenos.
  static Future<void> cancelarTodo() async {
    _ultimaSync = null;
    await iniciar();
    if (!_listo) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Recordatorios: $e');
    }
  }
}
