import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'cronograma.dart';
import 'datos_personales.dart';
import 'errores.dart';
import 'formato.dart';
import 'mapa_visitas_screen.dart';
import 'ui_comun.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  static const List<(String, String)> _filtros = [
    ('Pendiente', 'Pendientes'),
    ('Activo', 'Aprobadas'),
    ('Pagado', 'Pagadas'),
    ('Rechazado', 'Rechazadas'),
    ('Cancelado', 'Canceladas'),
  ];

  String _estado = 'Pendiente';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _crearStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _crearStream() => FirebaseFirestore.instance
      .collection('prestamos')
      .where('estado', isEqualTo: _estado)
      .snapshots();

  void _cambiar(String estado) {
    setState(() {
      _estado = estado;
      _stream = _crearStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes'),
        actions: [
          IconButton(
            tooltip: 'Mapa de visitas',
            icon: const Icon(Icons.map_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaVisitasScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          filtroChips(opciones: _filtros, actual: _estado, onChanged: _cambiar),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return mensajeVacio(Icons.error_outline_rounded, 'No se pudieron cargar las solicitudes', '${snap.error}');
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs.toList()
                  ..sort((a, b) => (aFecha(b.data()['fechaSolicitud']) ?? DateTime.now())
                      .compareTo(aFecha(a.data()['fechaSolicitud']) ?? DateTime.now()));

                if (docs.isEmpty) {
                  return mensajeVacio(Icons.inbox_outlined, 'No hay solicitudes en este estado', 'Cuando haya, aparecerán aquí.');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _tarjeta(context, docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final p = doc.data();
    final nombre = (p['clienteNombre'] ?? 'Sin nombre').toString();
    final fecha = aFecha(p['fechaSolicitud']);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _DetalleSolicitud(prestamoId: doc.id)),
      ),
      child: tarjetaBlanca(
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.azul.withValues(alpha: 0.12),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtMoney(aNum(p['monto']))} · ${p['plazoMeses']} meses',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
                  ),
                  if (fecha != null)
                    Text(haceTiempo(fecha), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            chipEstado((p['estado'] ?? 'Pendiente').toString()),
          ],
        ),
      ),
    );
  }
}

// ======================= DETALLE DE LA SOLICITUD =======================

class _DetalleSolicitud extends StatelessWidget {
  final String prestamoId;
  const _DetalleSolicitud({required this.prestamoId});

  Future<void> _aprobar(BuildContext context, DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmar(
      context,
      'Aprobar préstamo',
      '¿Aprobar el préstamo de ${fmtMoney(aNum(p['monto']))} para ${p['clienteNombre'] ?? 'el cliente'}?',
      'Aprobar',
    );
    if (!ok) return;
    try {
      final db = FirebaseFirestore.instance;
      await db.runTransaction((tx) async {
        final actual = await tx.get(ref);
        final d = actual.data();
        if (d == null) throw StateError('La solicitud ya no existe.');
        if (d['estado'] != 'Pendiente') throw StateError('Esta solicitud ya fue atendida.');

        // El cronograma definitivo se calcula aquí, con fechas desde la aprobación,
        // a partir de las condiciones validadas por las reglas de Firestore.
        final monto = aNum(d['monto']);
        final hoy = DateTime.now();
        final inicio = DateTime(hoy.year, hoy.month, hoy.day);
        final cuotas = generarCronograma(
          monto: monto,
          tasa: aNum(d['tasa']),
          tasaAnual: d['tasaAnual'] == true,
          plazo: (d['plazoMeses'] as num).toInt(),
          fechaInicio: inicio,
        );
        final total = totalCuotas(cuotas);

        for (final c in cuotas) {
          tx.set(ref.collection('cuotas').doc(c.numero.toString().padLeft(3, '0')), {
            'numero': c.numero,
            'fecha': Timestamp.fromDate(c.fecha),
            'cuota': c.cuota,
            'interes': c.interes,
            'amortizacion': c.amortizacion,
            'saldo': c.saldo,
            'estado': 'Pendiente',
            // Copia para listar cobranzas sin leer cada préstamo.
            'prestamoId': ref.id,
            'clienteId': d['clienteId'],
            'clienteNombre': d['clienteNombre'] ?? '',
          });
        }
        tx.update(ref, {
          'estado': 'Activo',
          'fechaAprobacion': FieldValue.serverTimestamp(),
          'fechaDesembolso': Timestamp.fromDate(inicio),
          'aprobadoPor': FirebaseAuth.instance.currentUser?.uid,
          'cuotaMensual': cuotas.first.cuota,
          'totalAPagar': total,
          'totalIntereses': totalIntereses(cuotas),
          'saldoPendiente': total,
          'cuotasPagadas': 0,
          'tcea': double.parse(calcularTcea(monto, cuotas.map((c) => c.cuota).toList()).toStringAsFixed(2)),
        });
      });
      messenger.showSnackBar(const SnackBar(content: Text('Préstamo aprobado y cronograma generado')));
    } catch (e) {
      debugPrint('Error al aprobar: $e');
      messenger.showSnackBar(SnackBar(content: Text('No se pudo aprobar. ${mensajeError(e)}')));
    }
  }

  Future<void> _rechazar(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final motivo = await pedirMotivo(context, 'Rechazar solicitud');
    if (motivo == null) return;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final actual = await tx.get(ref);
        if (actual.data()?['estado'] != 'Pendiente') throw StateError('Esta solicitud ya fue atendida.');
        tx.update(ref, {
          'estado': 'Rechazado',
          'motivoRechazo': motivo,
          'fechaRechazo': FieldValue.serverTimestamp(),
          'rechazadoPor': FirebaseAuth.instance.currentUser?.uid,
        });
      });
      messenger.showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
    } catch (e) {
      debugPrint('Error al rechazar: $e');
      messenger.showSnackBar(SnackBar(content: Text('No se pudo rechazar. ${mensajeError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('prestamos').doc(prestamoId);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de préstamo')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return mensajeVacio(Icons.error_outline_rounded, 'No se pudo cargar', '${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final p = snap.data!.data();
          if (p == null) return mensajeVacio(Icons.search_off_rounded, 'Solicitud no encontrada', '');
          final estado = (p['estado'] ?? 'Pendiente').toString();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _resumen(p, estado),
                    if (estado == 'Rechazado' && (p['motivoRechazo'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      tarjetaBlanca(child: filaDato('Motivo del rechazo', p['motivoRechazo'].toString())),
                    ],
                    const SizedBox(height: 14),
                    _ClienteCard(uid: (p['clienteId'] ?? '').toString()),
                    const SizedBox(height: 14),
                    _Cronograma(ref: ref, prestamo: p),
                  ],
                ),
              ),
              if (estado == 'Pendiente')
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rechazar(context, ref),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.rojo,
                              side: const BorderSide(color: AppColors.rojo),
                            ),
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _aprobar(context, ref, p),
                            child: const Text('Aprobar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _resumen(Map<String, dynamic> p, String estado) {
    final fecha = aFecha(p['fechaSolicitud']);
    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Préstamo solicitado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              chipEstado(estado),
            ],
          ),
          const SizedBox(height: 8),
          filaDato('Monto', fmtMoney(aNum(p['monto'])), destacado: true),
          filaDato('Tasa', '${p['tasa']}% ${p['tasaAnual'] == true ? 'anual (TEA)' : 'mensual'}'),
          filaDato('Plazo', '${p['plazoMeses']} meses'),
          filaDato('Cuota mensual', fmtMoney(aNum(p['cuotaMensual']))),
          filaDato('Intereses', fmtMoney(aNum(p['totalIntereses']))),
          if (p['tcea'] is num) filaDato('TCEA', '${aNum(p['tcea']).toStringAsFixed(2)}%'),
          filaDato('Total a pagar', fmtMoney(aNum(p['totalAPagar'])), destacado: true),
          if ((p['destino'] ?? '').toString().isNotEmpty) filaDato('Destino', p['destino'].toString()),
          if (fecha != null) filaDato('Solicitado', fechaHora(fecha)),
          if (aFecha(p['fechaAprobacion']) != null) filaDato('Aprobado', fechaHora(aFecha(p['fechaAprobacion'])!)),
          if (aFecha(p['fechaRechazo']) != null) filaDato('Rechazado', fechaHora(aFecha(p['fechaRechazo'])!)),
          if (p['cuotasPagadas'] is num) filaDato('Cuotas pagadas', '${p['cuotasPagadas']} de ${p['plazoMeses']}'),
          if (estado == 'Activo') filaDato('Saldo pendiente', fmtMoney(aNum(p['saldoPendiente']))),
        ],
      ),
    );
  }
}

class _ClienteCard extends StatelessWidget {
  final String uid;
  const _ClienteCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return tarjetaBlanca(child: const Text('Esta solicitud no tiene un cliente asociado.'));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        if (d == null) {
          return tarjetaBlanca(child: const Text('No se encontró el perfil del cliente.'));
        }
        final u = d['ubicacion'];
        final tieneUbic = u is Map && u['lat'] is num && u['lng'] is num;
        final fechaUbic = tieneUbic ? aFecha(u['fecha']) : null;

        return tarjetaBlanca(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              filaDato('Nombre', (d['nombre'] ?? '—').toString()),
              filaDato('Correo', (d['email'] ?? '—').toString()),
              DatosPersonalesAdmin(uid: uid, d: d),
              const SizedBox(height: 6),
              filaDato(
                'Ubicación',
                tieneUbic ? 'Actualizada ${fechaUbic != null ? haceTiempo(fechaUbic) : ''}' : 'Sin ubicación registrada',
              ),
              if (tieneUbic) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => abrirUrl(
                      context,
                      'https://www.google.com/maps/search/?api=1&query=${(u['lat'] as num).toDouble()},${(u['lng'] as num).toDouble()}',
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Ver ubicación en el mapa'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Cronograma extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> prestamo;
  const _Cronograma({required this.ref, required this.prestamo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.collection('cuotas').orderBy('numero').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        // Las solicitudes pendientes aún no tienen cuotas: se muestra una proyección.
        final referencial = docs.isEmpty && prestamo['estado'] == 'Pendiente' && prestamo['plazoMeses'] is num;
        final filas = <(int, DateTime, double)>[
          if (referencial)
            for (final c in generarCronograma(
              monto: aNum(prestamo['monto']),
              tasa: aNum(prestamo['tasa']),
              tasaAnual: prestamo['tasaAnual'] == true,
              plazo: (prestamo['plazoMeses'] as num).toInt(),
              fechaInicio: DateTime.now(),
            ))
              (c.numero, c.fecha, c.cuota)
          else
            for (final d in docs)
              (
                (d.data()['numero'] as num?)?.toInt() ?? 0,
                aFecha(d.data()['fecha']) ?? DateTime.now(),
                aNum(d.data()['cuota']),
              ),
        ];
        return tarjetaBlanca(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                referencial ? 'Cronograma referencial (${filas.length} cuotas)' : 'Cronograma (${filas.length} cuotas)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: referencial ? const Text('Se genera al aprobar, con fechas desde ese día') : null,
              children: [
                for (final f in filas)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        SizedBox(width: 30, child: Text('${f.$1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text(fmtFecha(f.$2))),
                        Text(fmtMoney(f.$3), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}