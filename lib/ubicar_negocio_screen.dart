import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'app_theme.dart';
import 'location_service.dart';
import 'mapas.dart';

/// Ubicación del negocio elegida por el cliente en el mapa.
class UbicacionNegocio {
  final LatLng punto;
  final String direccion;
  const UbicacionNegocio(this.punto, this.direccion);

  Map<String, dynamic> aMapa() => {'lat': punto.latitude, 'lng': punto.longitude, 'direccion': direccion};
}

/// "Ubica tu negocio": el cliente mueve el mapa hasta que el pin quede sobre su negocio.
/// El asesor usará este punto para la visita de evaluación. El GPS se usa una sola vez
/// para centrar el mapa; el cliente decide el punto final.
class UbicarNegocioScreen extends StatefulWidget {
  final UbicacionNegocio? inicial;
  const UbicarNegocioScreen({super.key, this.inicial});

  @override
  State<UbicarNegocioScreen> createState() => _UbicarNegocioScreenState();
}

class _UbicarNegocioScreenState extends State<UbicarNegocioScreen> {
  final MapController _mapa = MapController();
  late LatLng _centro = widget.inicial?.punto ?? centroPeru;
  String _direccion = '';
  bool _buscando = false;
  bool _moviendo = false;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _direccion = widget.inicial?.direccion ?? '';
    if (widget.inicial == null) _irAMiUbicacion();
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _irAMiUbicacion() async {
    try {
      if (await LocationService.solicitar() != EstadoUbicacion.ok) return;
      final p = await LocationService.posicionActual();
      if (!mounted) return;
      _centro = LatLng(p.latitude, p.longitude);
      _mapa.move(_centro, 17.5);
      _buscarDireccion();
    } catch (e) {
      debugPrint('Ubicar negocio: $e');
    }
  }

  /// Dirección aproximada del punto (geocodificador de Android, sin costo).
  Future<void> _buscarDireccion() async {
    final punto = _centro;
    setState(() => _buscando = true);
    try {
      final r = await Geocoding().placemarkFromCoordinates(punto.latitude, punto.longitude);
      if (!mounted || punto != _centro) return;
      if (r.isNotEmpty) {
        final p = r.first;
        final calle = [p.thoroughfare, p.subThoroughfare].where((x) => x != null && x.trim().isNotEmpty).join(' ');
        final texto = [
          calle.isNotEmpty ? calle : p.street,
          p.subLocality,
          p.locality,
        ].where((x) => x != null && x.trim().isNotEmpty).toSet().join(', ');
        setState(() => _direccion = texto);
      }
    } catch (e) {
      debugPrint('Geocodificación: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _alMover(MapCamera camara, bool porGesto) {
    _centro = camara.center;
    // Fuera del frame actual, por si el mapa avisa durante su propio dibujo.
    if (!_moviendo) {
      scheduleMicrotask(() {
        if (mounted) setState(() => _moviendo = true);
      });
    }
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _moviendo = false);
      _buscarDireccion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubica tu negocio')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _centro,
              initialZoom: widget.inicial == null ? 13 : 17.5,
              onPositionChanged: _alMover,
            ),
            children: capasBase(),
          ),
          // Pin fijo en el centro: se mueve el mapa, no el pin.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: AnimatedScale(
                  scale: _moviendo ? 1.15 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.location_on_rounded, size: 52, color: AppColors.rojo),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Mueve el mapa hasta que el pin quede sobre la puerta de tu negocio. '
                  'Tu asesor lo usará para visitarte.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 150,
            child: FloatingActionButton.small(
              heroTag: 'miUbicacionNegocio',
              onPressed: _irAMiUbicacion,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: AppColors.azul),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _buscando || _moviendo
                                  ? 'Buscando dirección…'
                                  : (_direccion.isEmpty ? 'Punto seleccionado' : _direccion),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _moviendo
                            ? null
                            : () => Navigator.pop(context, UbicacionNegocio(_centro, _direccion)),
                        child: const Text('Confirmar ubicación'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
