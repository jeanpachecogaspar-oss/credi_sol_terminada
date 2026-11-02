import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'formato.dart';

// =================== CÁMARA: leer el DNI ===================

/// Toma una foto del DNI con la cámara y lee el número con Google ML Kit (OCR en el
/// celular, sin internet). Devuelve los 8 dígitos o null.
Future<String?> leerDniConCamara(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (foto == null) return null;
    final lector = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await lector.processImage(InputImage.fromFilePath(foto.path));
      final dni = extraerDni(r.text);
      if (dni == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('No se pudo leer el número. Enfoca el DNI completo, con buena luz y sin reflejos.'),
        ));
        return null;
      }
      HapticFeedback.mediumImpact();
      return dni;
    } finally {
      await lector.close();
    }
  } on PlatformException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.code == 'camera_access_denied'
          ? 'Permite el acceso a la cámara desde los ajustes del celular.'
          : 'No se pudo abrir la cámara.'),
    ));
    return null;
  }
}

/// Busca el número de DNI en el texto leído: primero el que sigue a "DNI",
/// luego la zona I<PER del reverso y, si no, el primer número de 8 dígitos.
String? extraerDni(String texto) {
  final t = texto.toUpperCase();
  final trasDni = RegExp(r'DNI\D{0,12}(\d{8})').firstMatch(t);
  if (trasDni != null) return trasDni.group(1);
  final mrz = RegExp(r'I<PER(\d{8})').firstMatch(t.replaceAll(' ', ''));
  if (mrz != null) return mrz.group(1);
  return RegExp(r'(?<!\d)(\d{8})(?!\d)').firstMatch(t)?.group(1);
}

// =================== SENSOR: modo privado ===================

/// "Modo privado": con el acelerómetro, al poner el celular BOCA ABAJO o al
/// AGITARLO, se ocultan los montos de la app (se ven como S/ ••••).
class ModoPrivado {
  ModoPrivado._();

  /// true: el sensor está escuchando.
  static final ValueNotifier<bool> activo = ValueNotifier(false);

  /// true: los montos están ocultos.
  static final ValueNotifier<bool> ocultos = ValueNotifier(false);

  /// Lectura en vivo del sensor (m/s²) para mostrar al usuario.
  static final ValueNotifier<double> lectura = ValueNotifier(0);

  static StreamSubscription<AccelerometerEvent>? _sub;
  static DateTime _ultimo = DateTime.fromMillisecondsSinceEpoch(0);

  static void alternarSensor() => activo.value ? detener() : iniciar();

  static void iniciar() {
    if (_sub != null) return;
    activo.value = true;
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        final fuerza = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        lectura.value = fuerza;
        final ahora = DateTime.now();
        if (ahora.difference(_ultimo) < const Duration(milliseconds: 1200)) return;
        if (e.z < -7.5 && !ocultos.value) {
          // Boca abajo: ocultar.
          _ultimo = ahora;
          _cambiar(true);
        } else if (fuerza > 24) {
          // Agitar: alternar.
          _ultimo = ahora;
          _cambiar(!ocultos.value);
        }
      },
      onError: (Object e) => debugPrint('Acelerómetro: $e'),
      cancelOnError: true,
    );
  }

  static void detener() {
    _sub?.cancel();
    _sub = null;
    activo.value = false;
  }

  static void _cambiar(bool ocultar) {
    HapticFeedback.heavyImpact();
    ocultos.value = ocultar;
    ocultarMontos = ocultar;
  }

  /// Mostrar u ocultar a mano (botón del ojo).
  static void alternarMontos() => _cambiar(!ocultos.value);

  /// Al cerrar sesión.
  static void reiniciar() {
    detener();
    ocultos.value = false;
    ocultarMontos = false;
  }
}
