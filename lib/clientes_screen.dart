import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'datos_personales.dart';
import 'formato.dart';

const Color _azul = AppColors.azul;
const Color _rojo = AppColors.rojo;
const Color _verde = AppColors.verde;
const Color _ambar = AppColors.ambar;

DateTime? _aFecha(dynamic v) => v is Timestamp ? v.toDate() : null;
double _aNum(dynamic v) => (v as num?)?.toDouble() ?? 0;

String _hace(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}

String _fechaHora(DateTime d) =>
    '${fmtFecha(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Devuelve lat/lng/fecha si el usuario tiene ubicación guardada.
({double lat, double lng, double precision, DateTime fecha})? _ubicacion(Map<String, dynamic> data) {
  final u = data['ubicacion'];
  if (u is Map && u['lat'] is num && u['lng'] is num) {
    return (
      lat: _aNum(u['lat']),
      lng: _aNum(u['lng']),
      precision: _aNum(u['precision']),
      fecha: _aFecha(u['fecha']) ?? DateTime.now(),
    );
  }
  return null;
}

Color _colorEstado(String e) {
  switch (e) {
    case 'Activo':
      return _azul;
    case 'Pagado':
      return _verde;
    case 'Rechazado':
      return _rojo;
    default:
      return _ambar;
  }
}

// ======================= LISTA DE CLIENTES =======================

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _buscarCtrl = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('usuarios')
        .where('rol', isEqualTo: 'cliente')
        .snapshots();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  bool _coincide(Map<String, dynamic> d) {
    if (_filtro.isEmpty) return true;
    final texto = [d['nombre'], d['email'], d['dni'], d['celular']]
        .map((e) => (e ?? '').toString().toLowerCase())
        .join(' ');
    return texto.contains(_filtro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _buscarCtrl,
              onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo, DNI o celular',
                prefixIcon: const Icon(Icons.search_rounded, color: _azul),
                suffixIcon: _filtro.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _buscarCtrl.clear();
                          setState(() => _filtro = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No se pudieron cargar los clientes.\n${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final todos = snap.data!.docs.toList()
                  ..sort((a, b) => (a.data()['nombre'] ?? '')
                      .toString()
                      .toLowerCase()
                      .compareTo((b.data()['nombre'] ?? '').toString().toLowerCase()));
                final docs = todos.where((d) => _coincide(d.data())).toList();

                if (todos.isEmpty) {
                  return _mensajeVacio(Icons.people_outline_rounded, 'Aún no hay clientes registrados',
                      'Aparecerán aquí cuando se registren desde la app.');
                }
                if (docs.isEmpty) {
                  return _mensajeVacio(Icons.search_off_rounded, 'Sin resultados', 'No hay clientes que coincidan con tu búsqueda.');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        _filtro.isEmpty
                            ? '${todos.length} clientes registrados'
                            : '${docs.length} de ${todos.length} clientes',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      );
                    }
                    return _tarjeta(context, docs[i - 1]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeVacio(IconData icono, String titulo, String texto) {
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

  Widget _tarjeta(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final nombre = (d['nombre'] ?? 'Sin nombre').toString();
    final ubic = _ubicacion(d);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _DetalleCliente(uid: doc.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _azul.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _azul.withValues(alpha: 0.12),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: _azul, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text((d['email'] ?? '').toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        ubic != null ? Icons.location_on_rounded : Icons.location_off_rounded,
                        size: 15,
                        color: ubic != null ? _verde : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ubic != null ? 'Ubicación ${_hace(ubic.fecha)}' : 'Sin ubicación',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ubic != null ? _verde : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ======================= DETALLE DEL CLIENTE =======================

class _DetalleCliente extends StatelessWidget {
  final String uid;
  const _DetalleCliente({required this.uid});

  Future<void> _abrir(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _aviso(context);
    } catch (_) {
      if (context.mounted) _aviso(context);
    }
  }

  void _aviso(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del cliente')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data();
          if (d == null) return const Center(child: Text('Cliente no encontrado'));

          final nombre = (d['nombre'] ?? 'Sin nombre').toString();
          final ubic = _ubicacion(d);
          final registro = _aFecha(d['fechaRegistro']);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _azul.withValues(alpha: 0.12),
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: const TextStyle(color: _azul, fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text((d['email'] ?? '').toString(), style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _tarjeta(
                Column(
                  children: [
                    _fila('Correo', (d['email'] ?? '—').toString()),
                    _fila('Registrado', registro != null ? _fechaHora(registro) : '—'),
                    _fila('Acepta ubicación', d['aceptoUbicacion'] == true ? 'Sí' : 'No'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _tarjeta(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos personales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    perfilCompleto(d)
                        ? DatosPersonalesAdmin(uid: uid, d: d)
                        : Text(
                            'El cliente aún no completó sus datos personales. Se piden al enviar su primera solicitud.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _tarjeta(_ubicacionCard(context, ubic)),
              const SizedBox(height: 22),
              const Text('Préstamos del cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _prestamos(),
            ],
          );
        },
      ),
    );
  }

  Widget _ubicacionCard(BuildContext context, ({double lat, double lng, double precision, DateTime fecha})? u) {
    if (u == null) {
      return Row(
        children: [
          Icon(Icons.location_off_rounded, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          const Expanded(child: Text('Este cliente todavía no tiene una ubicación registrada.')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.location_on_rounded, color: _verde),
            SizedBox(width: 8),
            Text('Última ubicación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        _fila('Actualizada', '${_hace(u.fecha)} · ${_fechaHora(u.fecha)}'),
        _fila('Coordenadas', '${u.lat.toStringAsFixed(6)}, ${u.lng.toStringAsFixed(6)}'),
        if (u.precision > 0) _fila('Precisión', '± ${u.precision.toStringAsFixed(0)} m'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _abrir(context, 'https://www.google.com/maps/search/?api=1&query=${u.lat},${u.lng}'),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Ver en mapa'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _abrir(context, 'https://www.google.com/maps/dir/?api=1&destination=${u.lat},${u.lng}'),
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Cómo llegar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _prestamos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('prestamos').where('clienteId', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList()
          ..sort((a, b) => (_aFecha(b.data()['fechaSolicitud']) ?? DateTime.now())
              .compareTo(_aFecha(a.data()['fechaSolicitud']) ?? DateTime.now()));

        if (docs.isEmpty) {
          return Text('Este cliente aún no tiene préstamos.', style: TextStyle(color: Colors.grey.shade600));
        }

        return Column(
          children: docs.map((doc) {
            final p = doc.data();
            final estado = (p['estado'] ?? 'Pendiente').toString();
            final color = _colorEstado(estado);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmtMoney(_aNum(p['monto'])), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(
                          'Cuota ${fmtMoney(_aNum(p['cuotaMensual']))} · ${p['plazoMeses']} meses',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                    child: Text(estado, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _tarjeta(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _azul.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _fila(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }
}