import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'errores.dart';
import 'formato.dart';
import 'ui_comun.dart';

/// Pagos reportados por los clientes. La fuente de verdad son las cuotas
/// (`prestamos/{id}/cuotas/{id}`), consultadas con collectionGroup.
class CobranzasScreen extends StatefulWidget {
  const CobranzasScreen({super.key});

  @override
  State<CobranzasScreen> createState() => _CobranzasScreenState();
}

class _CobranzasScreenState extends State<CobranzasScreen> {
  static const List<(String, String)> _filtros = [
    ('Por verificar', 'Por verificar'),
    ('Pagada', 'Confirmadas'),
  ];

  String _estado = 'Por verificar';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _crearStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _crearStream() {
    final q = FirebaseFirestore.instance.collectionGroup('cuotas').where('estado', isEqualTo: _estado);
    // Confirmadas: solo las 50 más recientes (requiere índice compuesto, ver firestore.indexes.json).
    return _estado == 'Pagada'
        ? q.orderBy('fechaConfirmacion', descending: true).limit(50).snapshots()
        : q.snapshots();
  }

  void _cambiar(String estado) {
    setState(() {
      _estado = estado;
      _stream = _crearStream();
    });
  }

  Future<void> _confirmar(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = doc.data();

    final ok = await confirmar(
      context,
      'Confirmar pago',
      'Verifica en tu Yape o banco que llegó ${fmtMoney(aNum(c['cuota']))} '
          'con la operación ${c['numeroOperacion'] ?? '—'} (${c['medioPago'] ?? '—'}).',
      'Confirmar',
    );
    if (!ok) return;

    try {
      final completo = await confirmarPagoCuota(doc.reference);
      messenger.showSnackBar(SnackBar(
        content: Text(completo ? 'Pago confirmado. ¡Préstamo pagado por completo!' : 'Pago confirmado'),
      ));
    } catch (e) {
      debugPrint('Error al confirmar pago: $e');
      messenger.showSnackBar(SnackBar(content: Text('No se pudo confirmar. ${mensajeError(e)}')));
    }
  }

  Future<void> _rechazar(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final motivo = await pedirMotivo(context, 'Rechazar pago');
    if (motivo == null) return;

    try {
      await rechazarPagoCuota(doc.reference, motivo);
      messenger.showSnackBar(const SnackBar(content: Text('Pago rechazado. La cuota volvió a pendiente.')));
    } catch (e) {
      debugPrint('Error al rechazar pago: $e');
      messenger.showSnackBar(SnackBar(content: Text('No se pudo rechazar. ${mensajeError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobranzas')),
      body: Column(
        children: [
          filtroChips(opciones: _filtros, actual: _estado, onChanged: _cambiar),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return errorConsulta(
                    context,
                    'No se pudieron cargar los pagos',
                    snap.error!,
                    () => setState(() => _stream = _crearStream()),
                  );
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs.toList();
                if (_estado == 'Por verificar') {
                  // Los más antiguos primero: se atienden en orden de llegada.
                  docs.sort((a, b) => (aFecha(a.data()['fechaPago']) ?? DateTime.now())
                      .compareTo(aFecha(b.data()['fechaPago']) ?? DateTime.now()));
                }

                if (docs.isEmpty) {
                  return mensajeVacio(
                    Icons.payments_outlined,
                    _estado == 'Por verificar' ? 'No hay pagos por verificar' : 'Aún no hay pagos confirmados',
                    'Cuando un cliente reporte un pago, aparecerá aquí.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _tarjeta(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final c = doc.data();
    final estado = (c['estado'] ?? '').toString();
    final reportado = aFecha(c['fechaPago']);
    final confirmado = aFecha(c['fechaConfirmacion']);
    final vence = aFecha(c['fecha']);
    final operacion = (c['numeroOperacion'] ?? '').toString();
    final rechazosPrevios = (c['historialRechazos'] as List?)?.length ?? 0;

    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: NombreClienteCuota(cuota: doc)),
              chipEstado(estado),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cuota ${c['numero']} · ${fmtMoney(aNum(c['cuota']))}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azul),
          ),
          const SizedBox(height: 8),
          if (vence != null) filaDato('Vence', fmtFecha(vence)),
          filaDato('Medio', (c['medioPago'] ?? '—').toString()),
          Row(
            children: [
              Expanded(child: filaDato('N° operación', operacion.isEmpty ? '—' : operacion)),
              if (operacion.isNotEmpty)
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.azul),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: operacion));
                    messenger.showSnackBar(const SnackBar(content: Text('Operación copiada')));
                  },
                ),
            ],
          ),
          if (reportado != null) filaDato('Reportado', fechaHora(reportado)),
          if (confirmado != null) filaDato('Confirmado', fechaHora(confirmado)),
          if (rechazosPrevios > 0)
            filaDato('Rechazos previos', '$rechazosPrevios (último: ${c['motivoRechazoPago'] ?? '—'})'),
          if (estado == 'Por verificar') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rechazar(doc),
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
                    onPressed: () => _confirmar(doc),
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Muestra el nombre del cliente de una cuota. Las cuotas nuevas lo traen
/// copiado; las antiguas se resuelven leyendo el préstamo (con caché).
class NombreClienteCuota extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> cuota;
  const NombreClienteCuota({super.key, required this.cuota});

  static final Map<String, Future<String>> _cache = {};

  static const TextStyle _estilo = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    final directo = (cuota.data()?['clienteNombre'] ?? '').toString();
    if (directo.isNotEmpty) return Text(directo, style: _estilo);

    final prestamoRef = cuota.reference.parent.parent!;
    final futuro = _cache.putIfAbsent(
      prestamoRef.id,
      () => prestamoRef.get().then((s) => (s.data()?['clienteNombre'] ?? 'Sin nombre').toString()),
    );
    return FutureBuilder<String>(
      future: futuro,
      builder: (context, snap) => Text(snap.data ?? '…', style: _estilo),
    );
  }
}

/// Confirma el pago de una cuota 'Por verificar' y recalcula el préstamo.
/// Todo ocurre en una transacción: si otro administrador confirma a la vez,
/// Firestore reintenta y el saldo nunca queda inconsistente.
/// Devuelve true si con este pago el préstamo quedó cancelado.
Future<bool> confirmarPagoCuota(DocumentReference<Map<String, dynamic>> cuotaRef) {
  final db = FirebaseFirestore.instance;
  final prestamoRef = cuotaRef.parent.parent!;

  return db.runTransaction<bool>((tx) async {
    final pSnap = await tx.get(prestamoRef);
    final p = pSnap.data();
    if (p == null) throw StateError('El préstamo ya no existe.');
    if (p['estado'] != 'Activo') throw StateError('El préstamo no está activo.');

    // Se leen todas las cuotas por su ID (001, 002, ...). Las consultas no
    // están permitidas dentro de una transacción.
    final plazo = (p['plazoMeses'] as num?)?.toInt() ?? 0;
    final refs = <DocumentReference<Map<String, dynamic>>>[
      for (var n = 1; n <= plazo; n++) prestamoRef.collection('cuotas').doc(n.toString().padLeft(3, '0')),
    ];
    if (!refs.any((r) => r.id == cuotaRef.id)) refs.add(cuotaRef);

    final cuotas = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final r in refs) {
      cuotas.add(await tx.get(r));
    }

    final actual = cuotas.firstWhere((s) => s.id == cuotaRef.id);
    if (actual.data()?['estado'] != 'Por verificar') {
      throw StateError('Este pago ya fue atendido.');
    }

    var pagadas = 0;
    var total = 0;
    var saldo = 0.0;
    for (final s in cuotas) {
      final d = s.data();
      if (d == null) continue;
      total++;
      if (s.id == cuotaRef.id || d['estado'] == 'Pagada') {
        pagadas++;
      } else {
        saldo += aNum(d['cuota']);
      }
    }
    final completo = total > 0 && pagadas == total;

    tx.update(cuotaRef, {
      'estado': 'Pagada',
      'fechaConfirmacion': FieldValue.serverTimestamp(),
      'confirmadoPor': FirebaseAuth.instance.currentUser?.uid,
    });
    tx.update(prestamoRef, {
      'saldoPendiente': completo ? 0 : (saldo * 100).roundToDouble() / 100,
      'cuotasPagadas': pagadas,
      if (completo) 'estado': 'Pagado',
      if (completo) 'fechaPagado': FieldValue.serverTimestamp(),
    });
    return completo;
  });
}

/// Rechaza un pago reportado: la cuota vuelve a 'Pendiente' para que el
/// cliente pague de nuevo, y se guarda el intento en `historialRechazos`.
Future<void> rechazarPagoCuota(DocumentReference<Map<String, dynamic>> cuotaRef, String motivo) {
  return FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(cuotaRef);
    final c = snap.data();
    if (c == null || c['estado'] != 'Por verificar') {
      throw StateError('Este pago ya fue atendido.');
    }
    tx.update(cuotaRef, {
      'estado': 'Pendiente',
      'motivoRechazoPago': motivo,
      'fechaRechazoPago': FieldValue.serverTimestamp(),
      'rechazadoPor': FirebaseAuth.instance.currentUser?.uid,
      'historialRechazos': FieldValue.arrayUnion([
        {
          'motivo': motivo,
          'medioPago': c['medioPago'],
          'numeroOperacion': c['numeroOperacion'],
          'fecha': Timestamp.now(),
        }
      ]),
    });
  });
}
