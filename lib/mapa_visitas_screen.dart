import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'app_theme.dart';
import 'formato.dart';
import 'location_service.dart';
import 'mapas.dart';
import 'ui_comun.dart';

/// Mapa de visitas del asesor: los negocios de las solicitudes pendientes (para evaluar)
/// y de los préstamos activos (para cobranza), con la ubicación que DECLARÓ el cliente.
/// Ordena por cercanía al asesor y traza la ruta. No rastrea a nadie.
class MapaVisitasScreen extends StatefulWidget {
  const MapaVisitasScreen({super.key});

  @override
  State<MapaVisitasScreen> createState() => _MapaVisitasScreenState();
}

class _Visita {
  final String id;
  final String cliente;
  final String estado;
  final double monto;
  final String producto;
  final LatLng punto;
  final String direccion;
  const _Visita(this.id, this.cliente, this.estado, this.monto, this.producto, this.punto, this.direccion);

  Color get color => estado == 'Pendiente' ? AppColors.ambar : AppColors.azul;
}

class _MapaVisitasScreenState extends State<MapaVisitasScreen> {
  final MapController _mapa = MapController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = FirebaseFirestore.instance
      .collection('prestamos')
      .where('estado', whereIn: ['Pendiente', 'Activo'])
      .snapshots();
  LatLng? _yo;
  _Visita? _elegida;
  Ruta? _ruta;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _ubicarme();
  }

  Future<void> _ubicarme() async {
    try {
      if (await LocationService.solicitar() != EstadoUbicacion.ok) return;
      final p = await LocationService.posicionActual();
      if (mounted) setState(() => _yo = LatLng(p.latitude, p.longitude));
    } catch (e) {
      debugPrint('Mapa visitas: $e');
    }
  }

  Future<void> _elegir(_Visita v) async {
    setState(() {
      _elegida = v;
      _ruta = null;
    });
    _mapa.move(v.punto, 16);
    final yo = _yo;
    if (yo == null) return;
    final r = await rutaEntre(yo, v.punto);
    if (mounted && _elegida == v) setState(() => _ruta = r);
  }

  List<_Visita> _visitas(QuerySnapshot<Map<String, dynamic>> snap) {
    final lista = <_Visita>[];
    for (final d in snap.docs) {
      final x = d.data();
      final u = x['ubicacionNegocio'];
      if (u is! Map || u['lat'] is! num || u['lng'] is! num) continue;
      lista.add(_Visita(
        d.id,
        (x['clienteNombre'] ?? 'Cliente').toString(),
        (x['estado'] ?? '').toString(),
        aNum(x['monto']),
        (x['productoNombre'] ?? '').toString(),
        LatLng((u['lat'] as num).toDouble(), (u['lng'] as num).toDouble()),
        (u['direccion'] ?? '').toString(),
      ));
    }
    final yo = _yo;
    if (yo != null) {
      lista.sort((a, b) => distanciaMetros(yo, a.punto).compareTo(distanciaMetros(yo, b.punto)));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de visitas')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return errorConsulta(context, 'No se pudo cargar el mapa', snap.error!, () => setState(() {}));
          }
          final todas = snap.hasData ? _visitas(snap.data!) : <_Visita>[];
          final visitas = todas.where((v) => _filtro.isEmpty || v.estado == _filtro).toList();
          final yo = _yo;
          return Column(
            children: [
              Expanded(
                flex: 5,
                child: FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: visitas.isNotEmpty ? visitas.first.punto : (yo ?? centroPeru),
                    initialZoom: 12.5,
                  ),
                  children: [
                    ...capasBase(),
                    if (_ruta != null)
                      PolylineLayer(polylines: [Polyline(points: _ruta!.puntos, strokeWidth: 5, color: AppColors.azul)]),
                    MarkerLayer(markers: [
                      for (final v in visitas)
                        Marker(
                          point: v.punto,
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _elegir(v),
                            child: pinMapa(
                              v.estado == 'Pendiente' ? Icons.assignment_rounded : Icons.payments_rounded,
                              v.color,
                              resaltado: v == _elegida,
                            ),
                          ),
                        ),
                      if (yo != null) Marker(point: yo, width: 24, height: 24, child: miUbicacion()),
                    ]),
                  ],
                ),
              ),
              if (_elegida != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_elegida!.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              '${_elegida!.producto.isEmpty ? 'Préstamo' : _elegida!.producto} · ${fmtMoney(_elegida!.monto)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                            ),
                            if (_elegida!.direccion.isNotEmpty)
                              Text(_elegida!.direccion, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            if (_ruta != null)
                              Text('${textoDistancia(_ruta!.metros)} por calles · ${(_ruta!.segundos / 60).ceil()} min en auto',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      chipEstado(_elegida!.estado),
                    ],
                  ),
                ),
              filtroChips(
                opciones: [
                  ('', 'Todos (${todas.length})'),
                  ('Pendiente', 'Por evaluar'),
                  ('Activo', 'Cobranza'),
                ],
                actual: _filtro,
                onChanged: (v) => setState(() => _filtro = v),
              ),
              Expanded(
                flex: 4,
                child: !snap.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : visitas.isEmpty
                        ? mensajeVacio(Icons.map_outlined, 'Sin visitas',
                            'Aparecen aquí las solicitudes en las que el cliente marcó la ubicación de su negocio.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: visitas.length,
                            itemBuilder: (context, i) {
                              final v = visitas[i];
                              return ListTile(
                                onTap: () => _elegir(v),
                                selected: v == _elegida,
                                leading: CircleAvatar(
                                  backgroundColor: v.color,
                                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(v.cliente),
                                subtitle: Text(
                                  '${v.estado == 'Pendiente' ? 'Evaluar' : 'Cobranza'} · ${fmtMoney(v.monto)}',
                                ),
                                trailing: yo == null
                                    ? null
                                    : Text(textoDistancia(distanciaMetros(yo, v.punto)),
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
