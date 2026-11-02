import 'dart:convert';
import 'dart:io';

/// Consultas de DNI (RENIEC) y RUC (SUNAT) con APIsPERU: https://apisperu.com/servicios/dniruc
///
/// TOKEN: regístrate gratis en https://apisperu.com/admin/register (1 000 consultas al mes),
/// copia el token de tu panel y pégalo abajo.
class ApisPeru {
  static const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImplYW5wYWNoZWNvZ2FzcGFyQGdtYWlsLmNvbSIsImp0aSI6ImRiMDUwM2VkMDZjOGNmYzgifQ.I1vxHTtY6irhbyC7xulZjZprUzCPX1gSRUmhxOROYbc';

  static const String _host = 'dniruc.apisperu.com';

  static bool get configurado => token.isNotEmpty;

  static Future<Map<String, dynamic>> _consultar(String ruta) async {
    if (!configurado) {
      throw const ApisPeruError('Falta configurar el token de APIsPERU en lib/apis_peru.dart.');
    }
    final uri = Uri.https(_host, ruta, {'token': token});
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await cliente.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final cuerpo = await res.transform(utf8.decoder).join();
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const ApisPeruError('El token de APIsPERU no es válido o se agotaron las consultas del mes.');
      }
      if (res.statusCode != 200) {
        throw ApisPeruError('El servicio respondió ${res.statusCode}. Inténtalo más tarde.');
      }
      final datos = jsonDecode(cuerpo);
      if (datos is! Map<String, dynamic> || datos['success'] == false) {
        throw const ApisPeruError('No se encontró el documento.');
      }
      return datos;
    } on SocketException {
      throw const ApisPeruError('Sin conexión a internet.');
    } on HandshakeException {
      throw const ApisPeruError('No se pudo conectar de forma segura con APIsPERU.');
    } on FormatException {
      throw const ApisPeruError('Respuesta no válida del servicio.');
    } finally {
      cliente.close();
    }
  }

  /// Nombre completo de la persona con ese DNI.
  static Future<PersonaDni> dni(String dni) async {
    final d = await _consultar('/api/v1/dni/$dni');
    final nombres = (d['nombres'] ?? '').toString().trim();
    if (nombres.isEmpty) throw const ApisPeruError('No se encontró ese DNI en RENIEC.');
    return PersonaDni(
      dni: dni,
      nombres: nombres,
      apellidoPaterno: (d['apellidoPaterno'] ?? '').toString().trim(),
      apellidoMaterno: (d['apellidoMaterno'] ?? '').toString().trim(),
    );
  }

  /// Razón social y dirección fiscal del RUC.
  static Future<EmpresaRuc> ruc(String ruc) async {
    final d = await _consultar('/api/v1/ruc/$ruc');
    final razon = (d['razonSocial'] ?? '').toString().trim();
    if (razon.isEmpty) throw const ApisPeruError('No se encontró ese RUC en SUNAT.');
    return EmpresaRuc(
      ruc: ruc,
      razonSocial: razon,
      direccion: (d['direccion'] ?? '').toString().trim(),
      distrito: (d['distrito'] ?? '').toString().trim(),
      estado: (d['estado'] ?? '').toString().trim(),
      condicion: (d['condicion'] ?? '').toString().trim(),
    );
  }
}

class ApisPeruError implements Exception {
  final String mensaje;
  const ApisPeruError(this.mensaje);
  @override
  String toString() => mensaje;
}

class PersonaDni {
  final String dni;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  const PersonaDni({
    required this.dni,
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
  });

  /// "Juan Carlos Pérez López" (con mayúscula inicial en cada palabra).
  String get nombreCompleto => [nombres, apellidoPaterno, apellidoMaterno]
      .where((x) => x.isNotEmpty)
      .join(' ')
      .toLowerCase()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

class EmpresaRuc {
  final String ruc;
  final String razonSocial;
  final String direccion;
  final String distrito;
  final String estado;
  final String condicion;
  const EmpresaRuc({
    required this.ruc,
    required this.razonSocial,
    required this.direccion,
    required this.distrito,
    required this.estado,
    required this.condicion,
  });

  bool get activoHabido => estado.toUpperCase() == 'ACTIVO' && condicion.toUpperCase() == 'HABIDO';
}
