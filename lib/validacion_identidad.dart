import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Validación automática de las fotos de identidad, hecha EN EL CELULAR con
/// Google ML Kit (sin internet ni costo) y el geocodificador de Android:
///
/// - Selfie: debe haber exactamente un rostro, de frente y con los ojos abiertos.
/// - DNI (frente): debe leerse el número de DNI que escribió el cliente y verse un rostro.
/// - DNI (reverso): debe leerse la zona de lectura mecánica (I<PER…) o el número de DNI.
/// - Recibo de luz o agua: debe ser un recibo de una empresa de servicios y su dirección
///   se compara con la que escribió el cliente y con su ubicación GPS.
///
/// Es un filtro para rechazar fotos que no corresponden (una pared, otra persona,
/// un documento ajeno). La decisión final sigue siendo del administrador.
class ResultadoValidacion {
  /// true: la foto se acepta. false: se pide tomarla de nuevo.
  final bool aceptada;

  /// 'verificado' (todo coincide), 'revisar' (se acepta pero el admin debe mirar) o 'rechazado'.
  final String estado;

  /// Explicación para el cliente y el administrador.
  final String mensaje;

  /// Detalle que se guarda con la foto (lo ve el administrador).
  final Map<String, dynamic> datos;

  const ResultadoValidacion(this.aceptada, this.estado, this.mensaje, [this.datos = const {}]);

  const ResultadoValidacion.rechazo(String mensaje, [Map<String, dynamic> datos = const {}])
      : this(false, 'rechazado', mensaje, datos);

  Map<String, dynamic> aMapa() => {'estado': estado, 'mensaje': mensaje, ...datos};
}

class ValidadorIdentidad {
  // ---------------- Utilidades de texto ----------------

  static const Map<String, String> _tildes = {
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
  };

  /// Mayúsculas, sin tildes y con espacios simples.
  static String normalizar(String t) {
    var r = t.toUpperCase();
    _tildes.forEach((k, v) => r = r.replaceAll(k, v));
    return r.replaceAll(RegExp(r'[^A-Z0-9<\n ]'), ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  /// Corrige confusiones típicas del OCR en zonas numéricas (O→0, I→1, S→5, B→8).
  static String _soloDigitos(String t) => t
      .toUpperCase()
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8')
      .replaceAll(RegExp(r'[^0-9]'), '');

  static Future<String> _leerTexto(String ruta) async {
    final reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await reconocedor.processImage(InputImage.fromFilePath(ruta));
      return r.text;
    } finally {
      await reconocedor.close();
    }
  }

  static Future<List<Face>> _rostros(String ruta, {bool clasificar = false}) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: clasificar,
        minFaceSize: 0.08,
      ),
    );
    try {
      return await detector.processImage(InputImage.fromFilePath(ruta));
    } finally {
      await detector.close();
    }
  }

  // ---------------- Selfie ----------------

  static Future<ResultadoValidacion> selfie(String ruta) async {
    try {
      final rostros = await _rostros(ruta, clasificar: true);
      if (rostros.isEmpty) {
        return const ResultadoValidacion.rechazo(
            'No detectamos un rostro. Toma la selfie de frente, con buena luz y sin cubrirte la cara.');
      }
      if (rostros.length > 1) {
        return const ResultadoValidacion.rechazo('Aparece más de una persona. En la selfie debes salir solo tú.');
      }
      final r = rostros.first;
      final giro = (r.headEulerAngleY ?? 0).abs();
      if (giro > 30) {
        return const ResultadoValidacion.rechazo('Mira de frente a la cámara.');
      }
      final ojoI = r.leftEyeOpenProbability;
      final ojoD = r.rightEyeOpenProbability;
      if (ojoI != null && ojoD != null && ojoI < 0.25 && ojoD < 0.25) {
        return const ResultadoValidacion.rechazo('Tus ojos parecen cerrados. Toma la selfie de nuevo con los ojos abiertos.');
      }
      return const ResultadoValidacion(true, 'verificado', 'Rostro detectado correctamente.', {'rostros': 1});
    } catch (e) {
      debugPrint('Validación selfie: $e');
      return const ResultadoValidacion(true, 'revisar', 'No se pudo analizar la foto en este celular.');
    }
  }

  // ---------------- DNI ----------------

  static Future<ResultadoValidacion> dniFrente(String ruta, String dni) async {
    try {
      final texto = normalizar(await _leerTexto(ruta));
      final rostros = await _rostros(ruta);
      final esDni = ['PERU', 'IDENTIDAD', 'DOCUMENTO NACIONAL', 'RENIEC', 'DNI', 'REPUBLICA']
          .where(texto.contains)
          .length;
      final tieneNumero = _soloDigitos(texto).contains(dni);

      if (texto.length < 15 || esDni == 0) {
        return const ResultadoValidacion.rechazo(
            'No parece la cara frontal de un DNI peruano. Enfoca todo el documento, sin reflejos.');
      }
      if (!tieneNumero) {
        return ResultadoValidacion.rechazo(
          'No pudimos leer el número $dni en el documento. Verifica que sea TU DNI y que se vea nítido.',
          {'dniLeido': false},
        );
      }
      if (rostros.isEmpty) {
        return const ResultadoValidacion(true, 'revisar',
            'Se leyó tu número de DNI, pero no se distingue la foto del documento.', {'dniLeido': true});
      }
      return const ResultadoValidacion(true, 'verificado', 'El número de DNI coincide con el ingresado.',
          {'dniLeido': true});
    } catch (e) {
      debugPrint('Validación DNI frente: $e');
      return const ResultadoValidacion(true, 'revisar', 'No se pudo analizar la foto en este celular.');
    }
  }

  static Future<ResultadoValidacion> dniReverso(String ruta, String dni) async {
    try {
      final crudo = (await _leerTexto(ruta)).toUpperCase().replaceAll(' ', '');
      final mrz = crudo.contains('<<') && (crudo.contains('PER') || crudo.contains('I<'));
      final tieneNumero = _soloDigitos(crudo).contains(dni);
      if (!mrz && !tieneNumero) {
        return const ResultadoValidacion.rechazo(
            'No parece el reverso de un DNI. Fotografía la parte de atrás completa, incluidas las líneas con "<<<".');
      }
      if (mrz && !tieneNumero) {
        return const ResultadoValidacion(true, 'revisar',
            'Es el reverso de un DNI, pero no se pudo leer tu número.', {'dniLeido': false});
      }
      return const ResultadoValidacion(true, 'verificado', 'Reverso del DNI válido.', {'dniLeido': true});
    } catch (e) {
      debugPrint('Validación DNI reverso: $e');
      return const ResultadoValidacion(true, 'revisar', 'No se pudo analizar la foto en este celular.');
    }
  }

  // ---------------- Recibo de luz o agua ----------------

  static const List<String> _empresas = [
    'LUZ DEL SUR', 'ENEL', 'SEDAPAL', 'HIDRANDINA', 'ELECTROCENTRO', 'ELECTRONOROESTE', 'ELECTRONORTE',
    'ELECTROSUR', 'ELECTRO ORIENTE', 'ELECTRO SUR ESTE', 'ELECTRO PUNO', 'ELECTRO UCAYALI', 'ELECTRO DUNAS',
    'COELVISAC', 'SEAL', 'SEDALIB', 'SEDAPAR', 'SEDACUSCO', 'EPS GRAU', 'SEDACHIMBOTE', 'EMAPA', 'SEDAM', 'EPS',
  ];
  static const List<String> _palabrasRecibo = [
    'SUMINISTRO', 'RECIBO', 'CONSUMO', 'KWH', 'M3', 'TARIFA', 'VENCIMIENTO', 'IMPORTE', 'ENERGIA', 'AGUA',
    'MEDIDOR', 'LECTURA', 'TOTAL A PAGAR',
  ];
  static const Set<String> _vacias = {
    'AV', 'AVENIDA', 'JR', 'JIRON', 'CALLE', 'CAL', 'PSJE', 'PASAJE', 'MZ', 'MZA', 'LT', 'LOTE', 'NRO', 'NO',
    'NUM', 'DPTO', 'INT', 'URB', 'AAHH', 'ASOC', 'SECTOR', 'ETAPA', 'DEL', 'LAS', 'LOS', 'LA', 'EL', 'DE', 'Y',
    'PERU', 'LIMA',
  };

  static List<String> _claves(String direccion) => normalizar(direccion)
      .split(RegExp(r'\s+'))
      .where((p) => p.length >= 2 && !_vacias.contains(p))
      .toSet()
      .toList();

  /// Línea de dirección del recibo: la que sigue a "DIRECCION" / "DOMICILIO" / "SUMINISTRO".
  static String? _direccionDelRecibo(String textoOriginal) {
    final lineas = textoOriginal.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (var i = 0; i < lineas.length; i++) {
      final n = normalizar(lineas[i]);
      if (n.contains('DIRECCION') || n.contains('DOMICILIO')) {
        final resto = lineas[i].split(RegExp(r'[:：]')).skip(1).join(' ').trim();
        if (resto.length >= 6) return resto;
        if (i + 1 < lineas.length) return lineas[i + 1];
      }
    }
    // Sin rótulo: la primera línea que empieza como una dirección.
    final re = RegExp(r'^(AV|AV\.|JR|JR\.|CALLE|CAL|PSJE|MZ|URB|PJ|CA)\b');
    for (final l in lineas) {
      if (re.hasMatch(normalizar(l))) return l;
    }
    return null;
  }

  static Future<double?> _distanciaAGps(String direccion, String distrito, Position gps) async {
    try {
      final geo = Geocoding();
      final r = await geo
          .locationFromAddress('$direccion, $distrito, Perú')
          .timeout(const Duration(seconds: 12));
      if (r.isEmpty) return null;
      return Geolocator.distanceBetween(gps.latitude, gps.longitude, r.first.latitude, r.first.longitude);
    } catch (e) {
      debugPrint('Geocodificación: $e');
      return null;
    }
  }

  static Future<String?> _distritoDeGps(Position gps) async {
    try {
      final r = await Geocoding()
          .placemarkFromCoordinates(gps.latitude, gps.longitude)
          .timeout(const Duration(seconds: 12));
      if (r.isEmpty) return null;
      final p = r.first;
      return [p.locality, p.subLocality, p.subAdministrativeArea]
          .firstWhere((x) => x != null && x.trim().isNotEmpty, orElse: () => null);
    } catch (e) {
      debugPrint('Geocodificación inversa: $e');
      return null;
    }
  }

  /// [direccion] y [distrito]: lo que escribió el cliente. [gps]: su ubicación actual.
  static Future<ResultadoValidacion> recibo(
    String ruta, {
    required String direccion,
    required String distrito,
    Position? gps,
  }) async {
    final String original;
    try {
      original = await _leerTexto(ruta);
    } catch (e) {
      debugPrint('Validación recibo: $e');
      return const ResultadoValidacion(true, 'revisar', 'No se pudo analizar la foto en este celular.');
    }
    final texto = normalizar(original);

    // 1. ¿Es un recibo de servicios?
    final empresa = _empresas.firstWhere((e) => RegExp('\\b$e\\b').hasMatch(texto), orElse: () => '');
    final palabras = _palabrasRecibo.where(texto.contains).length;
    if (empresa.isEmpty && palabras < 3) {
      return const ResultadoValidacion.rechazo(
          'No parece un recibo de luz o agua. Fotografía el recibo completo, sobre una mesa y con buena luz.');
    }

    // 2. ¿La dirección del recibo es la que escribió el cliente?
    final claves = _claves(direccion);
    final encontradas = claves.where((c) => RegExp('\\b$c\\b').hasMatch(texto)).length;
    final coincidencia = claves.isEmpty ? 0.0 : encontradas / claves.length;
    final distritoNorm = normalizar(distrito);
    final distritoEnRecibo = distritoNorm.isNotEmpty && texto.contains(distritoNorm);
    final direccionRecibo = _direccionDelRecibo(original);

    if (coincidencia < 0.4 && !distritoEnRecibo) {
      return ResultadoValidacion.rechazo(
        'El recibo no corresponde a la dirección que escribiste ($direccion, $distrito). '
        'Usa un recibo de tu domicilio o corrige tu dirección en el paso 1.',
        {'empresa': empresa, 'coincidenciaDireccion': coincidencia, if (direccionRecibo != null) 'direccionRecibo': direccionRecibo},
      );
    }

    // 3. ¿La ubicación GPS está cerca de esa dirección?
    double? distancia;
    String? distritoGps;
    if (gps != null) {
      final buscar = direccionRecibo ?? direccion;
      distancia = await _distanciaAGps(buscar, distrito, gps);
      distritoGps = await _distritoDeGps(gps);
    }
    final gpsMismoDistrito = distritoGps != null &&
        (normalizar(distritoGps).contains(distritoNorm) || distritoNorm.contains(normalizar(distritoGps)));
    final gpsCerca = distancia != null && distancia <= 1500;

    final datos = <String, dynamic>{
      'empresa': empresa,
      'coincidenciaDireccion': double.parse(coincidencia.toStringAsFixed(2)),
      'distritoEnRecibo': distritoEnRecibo,
      if (direccionRecibo != null) 'direccionRecibo': direccionRecibo,
      if (distritoGps != null) 'distritoGps': distritoGps,
      if (distancia != null) 'distanciaGpsMetros': distancia.round(),
      if (gps != null) 'gps': {'lat': gps.latitude, 'lng': gps.longitude},
    };

    if (gps == null) {
      return ResultadoValidacion(true, 'revisar', 'Recibo válido. No se pudo obtener tu ubicación GPS para compararla.', datos);
    }
    if (gpsCerca || (distancia == null && gpsMismoDistrito)) {
      final dist = distancia == null ? 'en el mismo distrito' : 'a ${_metros(distancia)}';
      return ResultadoValidacion(true, 'verificado', 'La dirección del recibo coincide con tu ubicación GPS ($dist).', datos);
    }
    final donde = distancia != null ? 'a ${_metros(distancia)} de la dirección del recibo' : 'en otro distrito (${distritoGps ?? '—'})';
    return ResultadoValidacion(
      true,
      'revisar',
      'Tu ubicación GPS está $donde. Se enviará así y el asesor lo verificará.',
      datos,
    );
  }

  static String _metros(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
}
