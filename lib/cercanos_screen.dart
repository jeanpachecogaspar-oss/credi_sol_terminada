import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'app_theme.dart';
import 'config_pagos.dart';
import 'location_service.dart';
import 'mapas.dart';

/// "Pagar cerca de ti": agencias CrediSol y bancos, cajeros y agentes reales cercanos
/// (OpenStreetMap + Overpass), con la ruta por calles (OSRM). Todo dentro de la app.
/// La ubicación se pide UNA vez al abrir la pantalla; no se guarda ni se rastrea.
class CercanosScreen extends StatefulWidget {
  const CercanosScreen({super.key});

  @override
  State<CercanosScreen> createState() => _CercanosScreenState();
}

class _CercanosScreenState extends State<CercanosScreen> {
  final MapController _mapa = MapController();
  LatLng? _yo;
  List<PuntoPago> _puntos = [];
  bool _cargando = true;
  String? _error;
  PuntoPago? _elegido;
  Ruta? _ruta;
  bool _calculandoRuta = false;
  TipoPunto? _filtro;

  static final List<PuntoPago> _agencias = [
    for (final a in ConfigAgencias.agencias)
      PuntoPago(a.nombre, TipoPunto.agente, LatLng(a.lat, a.lng), a.direccion),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final estado = await LocationService.solicitar();
      if (estado != EstadoUbicacion.ok) {
        throw StateError('Activa el GPS y da permiso de ubicación para ver los puntos cercanos.');
      }
      final pos = await LocationService.posicionActual();
      final yo = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _yo = yo);
      _mapa.move(yo, 15.5);
      final puntos = await puntosCercanos(yo);
      if (!mounted) return;
      setState(() => _puntos = puntos);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Cercanos: $e');
      if (mounted) setState(() => _error = 'No se pudieron cargar los puntos cercanos. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegir(PuntoPago p) async {
    setState(() {
      _elegido = p;
      _ruta = null;
      _calculandoRuta = true;
    });
    _mapa.move(p.posicion, 16);
    final yo = _yo;
    if (yo == null) return;
    final r = await rutaEntre(yo, p.posicion);
    if (!mounted || _elegido != p) return;
    setState(() {
      _ruta = r;
      _calculandoRuta = false;
    });
  }

  List<PuntoPago> get _visibles => [
        ..._agencias,
        ..._puntos.where((p) => _filtro == null || p.tipo == _filtro),
      ];

  @override
  Widget build(BuildContext context) {
    final yo = _yo;
    final visibles = _visibles;
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar cerca de ti')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(initialCenter: yo ?? centroPeru, initialZoom: yo == null ? 12 : 15.5),
                  children: [
                    ...capasBase(),
                    if (_ruta != null)
                      PolylineLayer(polylines: [
                        Polyline(points: _ruta!.puntos, strokeWidth: 5, color: AppColors.azul),
                      ]),
                    MarkerLayer(markers: [
                      for (final p in visibles)
                        Marker(
                          point: p.posicion,
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _elegir(p),
                            child: pinMapa(
                              _agencias.contains(p) ? Icons.star_rounded : p.icono,
                              _agencias.contains(p) ? AppColors.rojo : p.color,
                              resaltado: p == _elegido,
                            ),
                          ),
                        ),
                      if (yo != null) Marker(point: yo, width: 24, height: 24, child: miUbicacion()),
                    ]),
                  ],
                ),
                if (_cargando)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Chip(
                        avatar: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        label: Text('Buscando puntos cercanos…'),
                      ),
                    ),
                  ),
                if (yo != null)
                  Positioned(
                    right: 12,
                    bottom: 34,
                    child: FloatingActionButton.small(
                      heroTag: 'centrarMapa',
                      onPressed: () => _mapa.move(yo, 15.5),
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
              ],
            ),
          ),
          if (_elegido != null) _detalle(_elegido!),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                for (final (t, txt) in [
                  (null, 'Todos'),
                  (TipoPunto.banco, 'Bancos'),
                  (TipoPunto.cajero, 'Cajeros'),
                  (TipoPunto.agente, 'Agentes'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(txt), selected: _filtro == t, onSelected: (_) => setState(() => _filtro = t)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: visibles.length,
                    itemBuilder: (context, i) {
                      final p = visibles[i];
                      final esAgencia = _agencias.contains(p);
                      return ListTile(
                        onTap: () => _elegir(p),
                        selected: p == _elegido,
                        leading: pinMapa(esAgencia ? Icons.star_rounded : p.icono, esAgencia ? AppColors.rojo : p.color, tam: 34),
                        title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [esAgencia ? 'Agencia CrediSol' : p.tipoTexto, if (p.direccion.isNotEmpty) p.direccion].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: yo == null
                            ? null
                            : Text(textoDistancia(distanciaMetros(yo, p.posicion)),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detalle(PuntoPago p) {
    final yo = _yo;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Row(
        children: [
          pinMapa(p.icono, p.color, tam: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _calculandoRuta
                      ? 'Calculando ruta…'
                      : _ruta != null
                          ? '${textoDistancia(_ruta!.metros)} por calles · ${_ruta!.minutosCaminando}'
                          : yo != null
                              ? 'A ${textoDistancia(distanciaMetros(yo, p.posicion))} en línea recta'
                              : '',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => setState(() {
              _elegido = null;
              _ruta = null;
            }),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
