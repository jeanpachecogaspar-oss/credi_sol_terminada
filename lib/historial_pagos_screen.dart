import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'errores.dart';
import 'formato.dart';
import 'ui_comun.dart';

/// Historial de pagos del cliente: pagos confirmados, en verificación y rechazados,
/// agrupados por préstamo.
class HistorialPagosScreen extends StatelessWidget {
  const HistorialPagosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: uid == null
          ? const SizedBox()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('prestamos')
                  .where('clienteId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return mensajeVacio(Icons.error_outline_rounded, 'No se pudo cargar el historial', mensajeError(snap.error!));
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final prestamos = snap.data!.docs
                    .where((d) => d.data()['estado'] == 'Activo' || d.data()['estado'] == 'Pagado')
                    .toList()
                  ..sort((a, b) => (aFecha(b.data()['fechaAprobacion']) ?? DateTime(2000))
                      .compareTo(aFecha(a.data()['fechaAprobacion']) ?? DateTime(2000)));

                if (prestamos.isEmpty) {
                  return mensajeVacio(
                    Icons.receipt_long_outlined,
                    'Aún no tienes pagos',
                    'Cuando reportes el pago de una cuota, aparecerá aquí.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final p in prestamos) ...[
                      _HistorialPrestamo(doc: p),
                      const SizedBox(height: 18),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _Evento {
  final String estado;
  final DateTime? fecha;
  final int numero;
  final double monto;
  final String medio;
  final String operacion;
  final String? motivo;
  const _Evento(this.estado, this.fecha, this.numero, this.monto, this.medio, this.operacion, [this.motivo]);
}

class _HistorialPrestamo extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _HistorialPrestamo({required this.doc});

  List<_Evento> _eventos(List<QueryDocumentSnapshot<Map<String, dynamic>>> cuotas) {
    final eventos = <_Evento>[];
    for (final d in cuotas) {
      final c = d.data();
      final numero = (c['numero'] as num?)?.toInt() ?? 0;
      final monto = aNum(c['cuota']);
      final medio = (c['medioPago'] ?? '—').toString();
      final op = (c['numeroOperacion'] ?? '—').toString();

      for (final r in (c['historialRechazos'] as List?) ?? const []) {
        if (r is! Map) continue;
        eventos.add(_Evento(
          'Rechazado',
          aFecha(r['fecha']),
          numero,
          monto,
          (r['medioPago'] ?? '—').toString(),
          (r['numeroOperacion'] ?? '—').toString(),
          (r['motivo'] ?? '').toString(),
        ));
      }
      if (c['estado'] == 'Por verificar') {
        eventos.add(_Evento('Por verificar', aFecha(c['fechaPago']), numero, monto, medio, op));
      } else if (c['estado'] == 'Pagada') {
        eventos.add(_Evento('Pagada', aFecha(c['fechaConfirmacion']) ?? aFecha(c['fechaPago']), numero, monto, medio, op));
      }
    }
    eventos.sort((a, b) => (b.fecha ?? DateTime(2000)).compareTo(a.fecha ?? DateTime(2000)));
    return eventos;
  }

  @override
  Widget build(BuildContext context) {
    final p = doc.data();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Préstamo de ${fmtMoney(aNum(p['monto']))}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            chipEstado((p['estado'] ?? '').toString()),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: doc.reference.collection('cuotas').orderBy('numero').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final eventos = _eventos(snap.data!.docs);
            if (eventos.isEmpty) {
              return Text('Sin pagos reportados todavía.', style: TextStyle(color: Colors.grey.shade600));
            }
            return Column(
              children: [
                for (final e in eventos) ...[
                  _tarjeta(e),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tarjeta(_Evento e) {
    final etiqueta = switch (e.estado) {
      'Pagada' => 'Confirmado',
      'Por verificar' => 'En verificación',
      _ => 'Rechazado',
    };
    return tarjetaBlanca(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cuota ${e.numero} · ${fmtMoney(e.monto)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorEstado(e.estado).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  etiqueta,
                  style: TextStyle(color: colorEstado(e.estado), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${e.medio} · Op. ${e.operacion}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if (e.fecha != null)
            Text(fechaHora(e.fecha!), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          if (e.motivo != null && e.motivo!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Motivo: ${e.motivo}',
                style: const TextStyle(color: AppColors.rojo, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
