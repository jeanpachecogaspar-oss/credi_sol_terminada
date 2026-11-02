import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final TextEditingController _montoController = TextEditingController();

  List<Map<String, dynamic>> prestamosActivos = [];
  List<Map<String, dynamic>> pagos = [];
  bool cargando = true;
  bool _guardando = false;
  String? _prestamoSeleccionadoId;

  static const Color colorPrincipal = Color(0xFF6C4EE3);
  static const Color colorAcento = Color(0xFF00C9A7);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([obtenerPrestamosActivos(), obtenerPagos()]);
  }

  Future<void> obtenerPrestamosActivos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('prestamos')
          .where('estado', isEqualTo: 'Activo')
          .get();

      setState(() {
        prestamosActivos = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      debugPrint('Error al obtener préstamos activos: $e');
    }
  }

  Future<void> obtenerPagos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pagos')
          .orderBy('fecha', descending: true)
          .get();

      setState(() {
        pagos = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al obtener pagos: $e');
      setState(() => cargando = false);
    }
  }

  Future<void> _registrarPago() async {
    final montoTexto = _montoController.text.trim();

    if (_prestamoSeleccionadoId == null || montoTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un préstamo e ingresa el monto')),
      );
      return;
    }

    final montoPago = double.tryParse(montoTexto);
    if (montoPago == null || montoPago <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final prestamoRef = FirebaseFirestore.instance.collection('prestamos').doc(_prestamoSeleccionadoId);
      final prestamoDoc = await prestamoRef.get();
      final datosPrestamo = prestamoDoc.data();

      if (datosPrestamo == null) throw Exception('El préstamo ya no existe');

      final saldoActual = (datosPrestamo['saldoPendiente'] as num).toDouble();
      final nuevoSaldo = (saldoActual - montoPago).clamp(0, double.infinity);
      final nuevoEstado = nuevoSaldo <= 0 ? 'Pagado' : 'Activo';

      // Registrar el pago
      await FirebaseFirestore.instance.collection('pagos').add({
        'prestamoId': _prestamoSeleccionadoId,
        'clienteNombre': datosPrestamo['clienteNombre'],
        'monto': montoPago,
        'fecha': FieldValue.serverTimestamp(),
      });

      // Actualizar el saldo del préstamo
      await prestamoRef.update({
        'saldoPendiente': nuevoSaldo,
        'estado': nuevoEstado,
      });

      _montoController.clear();
      setState(() => _prestamoSeleccionadoId = null);
      await _cargarDatos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado == 'Pagado' ? '¡Préstamo pagado por completo! 🎉' : 'Pago registrado'),
          backgroundColor: colorAcento,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar pago: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Pagos y Cuotas'),
        backgroundColor: colorPrincipal,
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargarDatos, tooltip: 'Actualizar'),
        ],
      ),
      body: Column(
        children: [
          _buildFormulario(),
          const Divider(height: 1),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : pagos.isEmpty
                    ? _buildVacio()
                    : _buildListaPagos(),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aún no hay pagos registrados', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _prestamoSeleccionadoId,
            decoration: const InputDecoration(
              icon: Icon(Icons.account_balance_wallet_rounded, color: colorPrincipal),
              labelText: 'Préstamo activo',
              border: UnderlineInputBorder(),
            ),
            items: prestamosActivos
                .map((p) => DropdownMenuItem<String>(
                      value: p['id'] as String,
                      child: Text(
                        '${p['clienteNombre']} · Saldo S/ ${(p['saldoPendiente'] as num).toStringAsFixed(2)}',
                      ),
                    ))
                .toList(),
            onChanged: (valor) => setState(() => _prestamoSeleccionadoId = valor),
            hint: const Text('Selecciona un préstamo'),
          ),
          TextField(
            controller: _montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              icon: Icon(Icons.payments_rounded, color: colorAcento),
              labelText: 'Monto del pago (S/)',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _registrarPago,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(_guardando ? 'Registrando...' : 'Registrar pago'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorAcento,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildListaPagos() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: pagos.length,
      itemBuilder: (context, index) {
        final pago = pagos[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A00C9A7),
              child: Icon(Icons.attach_money_rounded, color: colorAcento),
            ),
            title: Text(
              pago['clienteNombre']?.toString() ?? 'Cliente',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Pago registrado'),
            trailing: Text(
              'S/ ${(pago['monto'] as num).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: colorPrincipal),
            ),
          ),
        );
      },
    );
  }
}