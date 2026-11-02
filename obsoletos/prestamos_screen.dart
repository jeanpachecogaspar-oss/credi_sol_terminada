import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_prestamo_screen.dart';

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _tasaController = TextEditingController();
  final TextEditingController _plazoController = TextEditingController();

  List<Map<String, dynamic>> prestamos = [];
  List<Map<String, dynamic>> clientes = [];
  bool cargando = true;
  bool _guardando = false;
  String? _clienteSeleccionadoId;
  String? _idEditando;
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  static const Color colorPrincipal = Color(0xFF6C4EE3); // morado vibrante
  static const Color colorAcento = Color(0xFF00C9A7); // verde-turquesa

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _tasaController.dispose();
    _plazoController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _prestamosFiltrados {
    if (_textoBusqueda.trim().isEmpty) return prestamos;
    final texto = _textoBusqueda.toLowerCase();
    return prestamos.where((p) {
      final nombre = (p['clienteNombre'] ?? '').toString().toLowerCase();
      final estado = (p['estado'] ?? '').toString().toLowerCase();
      return nombre.contains(texto) || estado.contains(texto);
    }).toList();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([obtenerPrestamos(), obtenerClientes()]);
  }

  Future<void> obtenerClientes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clientes').get();
      setState(() {
        clientes = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      debugPrint('Error al obtener clientes: $e');
    }
  }

  Future<void> obtenerPrestamos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('prestamos')
          .orderBy('fechaRegistro', descending: true)
          .get();

      setState(() {
        prestamos = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al obtener préstamos: $e');
      setState(() => cargando = false);
    }
  }

  double _calcularTotalAPagar(double monto, double tasa, int plazo) {
    // Interés simple sobre el total del plazo (ajusta la fórmula a como te lo pida tu profesor)
    final interes = monto * (tasa / 100);
    return monto + interes;
  }

  void _limpiarFormulario() {
    _montoController.clear();
    _tasaController.clear();
    _plazoController.clear();
    setState(() {
      _clienteSeleccionadoId = null;
      _idEditando = null;
    });
  }

  Future<void> _guardarPrestamo() async {
    final montoTexto = _montoController.text.trim();
    final tasaTexto = _tasaController.text.trim();
    final plazoTexto = _plazoController.text.trim();

    if (_clienteSeleccionadoId == null || montoTexto.isEmpty || tasaTexto.isEmpty || plazoTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa cliente, monto, tasa y plazo')),
      );
      return;
    }

    final monto = double.tryParse(montoTexto);
    final tasa = double.tryParse(tasaTexto);
    final plazo = int.tryParse(plazoTexto);

    if (monto == null || tasa == null || plazo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto, tasa y plazo deben ser números válidos')),
      );
      return;
    }

    setState(() => _guardando = true);

    final cliente = clientes.firstWhere((c) => c['id'] == _clienteSeleccionadoId);
    final totalAPagar = _calcularTotalAPagar(monto, tasa, plazo);
    final cuotaMensual = totalAPagar / plazo;

    final datosPrestamo = <String, dynamic>{
      'clienteId': _clienteSeleccionadoId,
      'clienteNombre': cliente['nombre'],
      'monto': monto,
      'tasa': tasa,
      'plazoMeses': plazo,
      'totalAPagar': totalAPagar,
      'cuotaMensual': cuotaMensual,
      'saldoPendiente': totalAPagar,
      'estado': 'Activo',
    };

    try {
      if (_idEditando != null) {
        await FirebaseFirestore.instance.collection('prestamos').doc(_idEditando).update(datosPrestamo);
      } else {
        datosPrestamo['fechaRegistro'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('prestamos').add(datosPrestamo);
      }

      _limpiarFormulario();
      await obtenerPrestamos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _editarPrestamo(Map<String, dynamic> prestamo) {
    _montoController.text = prestamo['monto'].toString();
    _tasaController.text = prestamo['tasa'].toString();
    _plazoController.text = prestamo['plazoMeses'].toString();
    setState(() {
      _clienteSeleccionadoId = prestamo['clienteId'];
      _idEditando = prestamo['id'];
    });
  }

  Future<void> _eliminarPrestamo(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar préstamo'),
        content: const Text('¿Seguro que quieres eliminar este préstamo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('prestamos').doc(id).delete();
      await obtenerPrestamos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Color _colorPorEstado(String estado) {
    switch (estado) {
      case 'Pagado':
        return colorAcento;
      case 'Moroso':
        return Colors.redAccent;
      default:
        return colorPrincipal;
    }
  }

  IconData _iconoPorEstado(String estado) {
    switch (estado) {
      case 'Pagado':
        return Icons.check_circle_rounded;
      case 'Moroso':
        return Icons.warning_rounded;
      default:
        return Icons.hourglass_bottom_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Préstamos'),
        backgroundColor: colorPrincipal,
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFormulario(),
          _buildBarraBusqueda(),
          const Divider(height: 1),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : _prestamosFiltrados.isEmpty
                    ? _buildVacio()
                    : _buildListaPrestamos(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraBusqueda() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _busquedaController,
        onChanged: (valor) => setState(() => _textoBusqueda = valor),
        decoration: InputDecoration(
          hintText: 'Buscar por cliente o estado...',
          prefixIcon: const Icon(Icons.search_rounded, color: colorPrincipal),
          suffixIcon: _textoBusqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _busquedaController.clear();
                    setState(() => _textoBusqueda = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No hay préstamos registrados', style: TextStyle(color: Colors.grey)),
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
            value: _clienteSeleccionadoId,
            decoration: const InputDecoration(
              icon: Icon(Icons.person_search_rounded, color: colorPrincipal),
              labelText: 'Cliente',
              border: UnderlineInputBorder(),
            ),
            items: clientes
                .map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(c['nombre']?.toString() ?? 'Sin nombre'),
                    ))
                .toList(),
            onChanged: (valor) => setState(() => _clienteSeleccionadoId = valor),
            hint: const Text('Selecciona un cliente'),
          ),
          TextField(
            controller: _montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              icon: Icon(Icons.attach_money_rounded, color: colorAcento),
              labelText: 'Monto del préstamo (S/)',
              border: UnderlineInputBorder(),
            ),
          ),
          TextField(
            controller: _tasaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              icon: Icon(Icons.percent_rounded, color: Colors.orangeAccent),
              labelText: 'Tasa de interés (%)',
              border: UnderlineInputBorder(),
            ),
          ),
          TextField(
            controller: _plazoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              icon: Icon(Icons.calendar_month_rounded, color: Colors.blueAccent),
              labelText: 'Plazo (meses)',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarPrestamo,
                  icon: Icon(_idEditando != null ? Icons.save_rounded : Icons.add_card_rounded),
                  label: Text(_guardando
                      ? 'Guardando...'
                      : (_idEditando != null ? 'Guardar cambios' : 'Registrar préstamo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_idEditando != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _limpiarFormulario,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancelar edición',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildListaPrestamos() {
    final lista = _prestamosFiltrados;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final prestamo = lista[index];
        final estado = prestamo['estado']?.toString() ?? 'Activo';
        final color = _colorPorEstado(estado);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetallePrestamoScreen(prestamo: prestamo)),
            ),
            child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(_iconoPorEstado(estado), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prestamo['clienteNombre']?.toString() ?? 'Sin cliente',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              estado,
                              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.blueGrey),
                          onPressed: () => _editarPrestamo(prestamo),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                          onPressed: () => _eliminarPrestamo(prestamo['id']),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoChip(Icons.attach_money_rounded, 'Monto', 'S/ ${prestamo['monto']}'),
                    _infoChip(Icons.percent_rounded, 'Tasa', '${prestamo['tasa']}%'),
                    _infoChip(Icons.calendar_month_rounded, 'Plazo', '${prestamo['plazoMeses']} m'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoChip(Icons.payments_rounded, 'Cuota', 'S/ ${(prestamo['cuotaMensual'] as num).toStringAsFixed(2)}'),
                    _infoChip(Icons.account_balance_wallet_rounded, 'Saldo', 'S/ ${(prestamo['saldoPendiente'] as num).toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icono, String label, String valor) {
    return Column(
      children: [
        Icon(icono, size: 18, color: colorPrincipal),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}