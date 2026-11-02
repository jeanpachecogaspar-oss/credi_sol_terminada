import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetallePrestamoScreen extends StatefulWidget {
  final Map<String, dynamic> prestamo;

  const DetallePrestamoScreen({super.key, required this.prestamo});

  @override
  State<DetallePrestamoScreen> createState() => _DetallePrestamoScreenState();
}

class _DetallePrestamoScreenState extends State<DetallePrestamoScreen> {
  List<Map<String, dynamic>> pagos = [];
  bool cargando = true;

  static const Color colorPrincipal = Color(0xFF6C4EE3);
  static const Color colorAcento = Color(0xFF00C9A7);

  @override
  void initState() {
    super.initState();
    _obtenerPagos();
  }

  Future<void> _obtenerPagos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pagos')
          .where('prestamoId', isEqualTo: widget.prestamo['id'])
          .orderBy('fecha', descending: true)
          .get();

      setState(() {
        pagos = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al obtener historial de pagos: $e');
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prestamo = widget.prestamo;
    final monto = (prestamo['monto'] as num).toDouble();
    final totalAPagar = (prestamo['totalAPagar'] as num).toDouble();
    final saldo = (prestamo['saldoPendiente'] as num).toDouble();
    final progreso = totalAPagar > 0 ? (1 - (saldo / totalAPagar)).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(prestamo['clienteNombre']?.toString() ?? 'Préstamo'),
        backgroundColor: colorPrincipal,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [colorPrincipal, Color(0xFF9B7DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: colorPrincipal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo pendiente', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  'S/ ${saldo.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(colorAcento),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progreso * 100).toStringAsFixed(0)}% pagado de S/ ${totalAPagar.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _infoTarjeta(Icons.attach_money_rounded, 'Monto original', 'S/ ${monto.toStringAsFixed(2)}')),
              const SizedBox(width: 10),
              Expanded(child: _infoTarjeta(Icons.percent_rounded, 'Tasa', '${prestamo['tasa']}%')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoTarjeta(Icons.calendar_month_rounded, 'Plazo', '${prestamo['plazoMeses']} meses')),
              const SizedBox(width: 10),
              Expanded(child: _infoTarjeta(Icons.payments_rounded, 'Cuota', 'S/ ${(prestamo['cuotaMensual'] as num).toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Historial de pagos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (cargando)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (pagos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Este préstamo aún no tiene pagos registrados', style: TextStyle(color: Colors.grey))),
            )
          else
            ...pagos.map((pago) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1A00C9A7),
                      child: Icon(Icons.check_rounded, color: colorAcento),
                    ),
                    title: Text('S/ ${(pago['monto'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Pago registrado'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _infoTarjeta(IconData icono, String label, String valor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: colorPrincipal, size: 22),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}