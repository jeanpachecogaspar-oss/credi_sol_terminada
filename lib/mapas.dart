import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapas DENTRO de la app con servicios gratuitos y sin clave de pago:
/// - OpenStreetMap: el mapa (teselas).
/// - Overpass API: bancos, cajeros y agentes reales cerca del cliente (datos de OpenStreetMap).
/// - OSRM: la ruta por calles entre dos puntos.
///
/// La ubicación del cliente se usa SOLO en el momento en que la necesita (no hay rastreo).

const LatLng centroPeru = LatLng(-12.0464, -77.0428); // Lima, si no hay GPS

/// Capa de mapa de OpenStreetMap + atribución (obligatoria por su licencia).
List<Widget> capasBase() => [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'pe.credisol.app',
        maxZoom: 19,
      ),
      const RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ];

/// Distancia en metros entre dos puntos.
double distanciaMetros(LatLng a, LatLng b) => Distance().as(LengthUnit.Meter, a, b);

String textoDistancia(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

Future<Map<String, dynamic>> _getJson(Uri uri, {String? cuerpoPost}) async {
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  cliente.userAgent = 'CrediSol/1.0 (pe.credisol.app)';
  try {
    final req = cuerpoPost == null ? await cliente.getUrl(uri) : await cliente.postUrl(uri);
    if (cuerpoPost != null) {
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      req.write('data=${Uri.encodeQueryComponent(cuerpoPost)}');
    }
    final res = await req.close().timeout(const Duration(seconds: 25));
    final texto = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    return jsonDecode(texto) as Map<String, dynamic>;
  } finally {
    cliente.close();
  }
}

// =================== Overpass: puntos de pago cercanos ===================

enum TipoPunto { banco, cajero, agente }

class PuntoPago {
  final String nombre;
  final TipoPunto tipo;
  final LatLng posicion;
  final String direccion;
  const PuntoPago(this.nombre, this.tipo, this.posicion, this.direccion);

  IconData get icono => switch (tipo) {
        TipoPunto.banco => Icons.account_balance_rounded,
        TipoPunto.cajero => Icons.local_atm_rounded,
        TipoPunto.agente => Icons.storefront_rounded,
      };

  Color get color => switch (tipo) {
        TipoPunto.banco => const Color(0xFF1565C0),
        TipoPunto.cajero => const Color(0xFF2E9E6B),
        TipoPunto.agente => const Color(0xFFB38600),
      };

  String get tipoTexto => switch (tipo) {
        TipoPunto.banco => 'Banco',
        TipoPunto.cajero => 'Cajero',
        TipoPunto.agente => 'Agente',
      };
}

/// Bancos, cajeros y agentes (BCP, Interbank, BBVA, Kasnet, etc.) en un radio de [radio] metros.
Future<List<PuntoPago>> puntosCercanos(LatLng p, {int radio = 1500}) async {
  final a = '(around:$radio,${p.latitude},${p.longitude})';
  final consulta = '[out:json][timeout:20];('
      'node["amenity"="bank"]$a;'
      'node["amenity"="atm"]$a;'
      'node["amenity"="payment_centre"]$a;'
      'node["shop"="money_transfer"]$a;'
      'node["payment:agent"]$a;'
      ');out body 80;';
  final datos = await _getJson(Uri.parse('https://overpass-api.de/api/interpreter'), cuerpoPost: consulta);
  final lista = <PuntoPago>[];
  for (final e in (datos['elements'] as List? ?? []).cast<Map<String, dynamic>>()) {
    final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final amenity = tags['amenity']?.toString();
    final tipo = amenity == 'bank'
        ? TipoPunto.banco
        : amenity == 'atm'
            ? TipoPunto.cajero
            : TipoPunto.agente;
    final nombre = (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? '').toString();
    final calle = [tags['addr:street'], tags['addr:housenumber']].whereType<String>().join(' ');
    lista.add(PuntoPago(
      nombre.isEmpty ? (tipo == TipoPunto.cajero ? 'Cajero automático' : tipo == TipoPunto.banco ? 'Banco' : 'Agente') : nombre,
      tipo,
      LatLng((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble()),
      calle,
    ));
  }
  lista.sort((x, y) => distanciaMetros(p, x.posicion).compareTo(distanciaMetros(p, y.posicion)));
  return lista;
}

// =================== OSRM: ruta por calles ===================

class Ruta {
  final List<LatLng> puntos;
  final double metros;
  final double segundos;
  const Ruta(this.puntos, this.metros, this.segundos);

  String get minutosCaminando => '${(metros / 80).ceil()} min a pie'; // ~4.8 km/h
}

/// Ruta entre [desde] y [hasta]. Devuelve null si el servicio no responde.
Future<Ruta?> rutaEntre(LatLng desde, LatLng hasta) async {
  try {
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${desde.longitude},${desde.latitude};${hasta.longitude},${hasta.latitude}'
        '?overview=full&geometries=geojson');
    final d = await _getJson(uri);
    final rutas = d['routes'] as List?;
    if (rutas == null || rutas.isEmpty) return null;
    final r = rutas.first as Map<String, dynamic>;
    final coords = ((r['geometry'] as Map)['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    return Ruta(coords, (r['distance'] as num).toDouble(), (r['duration'] as num).toDouble());
  } catch (e) {
    debugPrint('OSRM: $e');
    return null;
  }
}

/// Marcador circular con ícono.
Widget pinMapa(IconData icono, Color color, {double tam = 36, bool resaltado = false}) {
  return Container(
    width: tam,
    height: tam,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: resaltado ? 3.5 : 2.5),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Icon(icono, color: Colors.white, size: tam * 0.55),
  );
}

/// Punto azul "estás aquí".
Widget miUbicacion() => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 4)],
      ),
    );
