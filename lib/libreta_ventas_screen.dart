import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'formato.dart';
import 'ideas_calculos.dart';
import 'navegacion_cliente.dart';
import 'ui_comun.dart';

/// IDEA DISRUPTIVA 3: Libreta de ventas.
///
/// Muchos emprendedores no tienen boletas ni estados financieros para demostrar ingresos.
/// Con esta libreta anotan cada día cuánto vendieron y gastaron. La app calcula su ganancia
/// promedio, la cuota máxima que pueden pagar sin ahogarse (35 % de la ganancia) y el
/// MONTO DE PRÉSTAMO SUGERIDO. Se guarda en el celular (no gasta datos ni lecturas).
class LibretaVentasScreen extends StatefulWidget {
  const LibretaVentasScreen({super.key});

  @override
  State<LibretaVentasScreen> createState() => _LibretaVentasScreenState();
}

class _LibretaVentasScreenState extends State<LibretaVentasScreen> {
  List<RegistroVenta> _registros = [];
  bool _cargando = true;
  int _plazo = 12;

  String get _clave => 'libreta_ventas_${FirebaseAuth.instance.currentUser?.uid ?? 'anonimo'}';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_clave);
      if (texto != null) {
        final lista = (jsonDecode(texto) as List).cast<Map<String, dynamic>>();
        _registros = lista.map(RegistroVenta.desde).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
      }
    } catch (e) {
      debugPrint('Libreta: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(_registros.map((r) => r.aMapa()).toList()));
  }

  bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _anotar({RegistroVenta? existente}) async {
    final hoy = DateTime.now();
    var fecha = existente?.fecha ?? DateTime(hoy.year, hoy.month, hoy.day);
    final ventas = TextEditingController(text: existente == null ? '' : existente.ventas.toStringAsFixed(2));
    final gastos = TextEditingController(text: existente == null ? '' : existente.gastos.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    String? validar(String? v) {
      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
      if (n == null || n < 0) return 'Monto no válido';
      if (n > 100000) return 'Monto muy alto';
      return null;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existente == null ? 'Anotar el día' : 'Editar el día',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime(hoy.year - 1),
                      lastDate: hoy,
                    );
                    if (f != null) setLocal(() => fecha = f);
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(fmtFecha(fecha)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ventas,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Vendí hoy (S/)', prefixIcon: Icon(Icons.trending_up)),
                  validator: validar,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: gastos,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(
                      labelText: 'Gasté hoy (mercadería, pasajes, luz…) (S/)', prefixIcon: Icon(Icons.trending_down)),
                  validator: validar,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final v = double.parse(ventas.text.replaceAll(',', '.'));
    final g = double.parse(gastos.text.replaceAll(',', '.'));
    setState(() {
      _registros.removeWhere((r) => _mismoDia(r.fecha, fecha));
      if (existente != null) _registros.remove(existente);
      _registros.add(RegistroVenta(fecha, v, g));
      _registros.sort((a, b) => b.fecha.compareTo(a.fecha));
    });
    await _guardar();
  }

  Future<void> _borrar(RegistroVenta r) async {
    setState(() => _registros.remove(r));
    await _guardar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Se borró el ${fmtFecha(r.fecha)}'),
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () {
          setState(() {
            _registros.add(r);
            _registros.sort((a, b) => b.fecha.compareTo(a.fecha));
          });
          _guardar();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = analizarVentas(_registros, plazo: _plazo);
    final ultimos = _registros.take(14).toList().reversed.toList();
    final maxVenta = ultimos.fold(0.0, (m, r) => r.ventas > m ? r.ventas : m);

    return Scaffold(
      appBar: AppBar(title: const Text('Libreta de ventas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _anotar(),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Anotar el día'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                Text('Anota cada día lo que vendes y gastas. Con 7 días o más, CrediSol te dice cuánto '
                    'puedes pedir sin riesgo.', style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 14),
                tarjetaBlanca(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.insights_rounded, color: AppColors.azul),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text('Tu capacidad de pago', style: TextStyle(fontWeight: FontWeight.w700))),
                          chipEstado('${a.dias} días'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      filaDato('Venta promedio / día', fmtMoney(a.ventaPromedio)),
                      filaDato('Ganancia promedio / día', fmtMoney(a.gananciaPromedio)),
                      filaDato('Ganancia al mes ($diasLaborablesMes días)', fmtMoney(a.gananciaMensual)),
                      filaDato('Cuota máxima sana', fmtMoney(a.cuotaMaxima)),
                      const SizedBox(height: 4),
                      Text('Plazo: $_plazo meses', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Slider(
                        value: _plazo.toDouble(),
                        min: 3,
                        max: 24,
                        divisions: 21,
                        onChanged: (v) => setState(() => _plazo = v.round()),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (a.montoSugerido > 0 ? AppColors.verde : AppColors.ambar).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: a.dias < 7
                            ? Text('Anota ${7 - a.dias} día(s) más para calcular tu monto sugerido.',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ambar))
                            : a.montoSugerido > 0
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Puedes pedir hasta', style: TextStyle(fontSize: 13)),
                                      Text(fmtMoney(a.montoSugerido),
                                          style: const TextStyle(
                                              fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.verde)),
                                      Text('a $_plazo meses, con una cuota de hasta ${fmtMoney(a.cuotaMaxima)}',
                                          style: const TextStyle(fontSize: 12.5)),
                                    ],
                                  )
                                : const Text(
                                    'Con tus ganancias actuales aún no conviene endeudarte. Sigue anotando: '
                                    'cuando suban, aquí verás tu monto.',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ambar)),
                      ),
                      if (a.dias >= 7 && a.montoSugerido > 0) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            final messenger = ScaffoldMessenger.of(context);
                            Clipboard.setData(ClipboardData(text: a.montoSugerido.toStringAsFixed(0)));
                            tabCliente.value = tabSimular;
                            Navigator.popUntil(context, (route) => route.isFirst);
                            messenger.showSnackBar(SnackBar(
                                content: Text('Simula ${fmtMoney(a.montoSugerido)} a $_plazo meses (monto copiado).')));
                          },
                          icon: const Icon(Icons.calculate_rounded),
                          label: const Text('Simular este monto'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ultimos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  tarjetaBlanca(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Últimos días', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final r in ultimos)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          height: maxVenta == 0 ? 0 : 90 * r.ventas / maxVenta,
                                          decoration: BoxDecoration(
                                            color: r.ganancia >= 0 ? AppColors.azul : AppColors.rojo,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(child: Text('${r.fecha.day}', style: const TextStyle(fontSize: 10))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Altura = ventas. Rojo = ese día gastaste más de lo que vendiste.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                for (final r in _registros)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      onTap: () => _anotar(existente: r),
                      title: Text(fmtFecha(r.fecha), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Vendí ${fmtMoney(r.ventas)} · Gasté ${fmtMoney(r.gastos)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmtMoney(r.ganancia),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: r.ganancia >= 0 ? AppColors.verde : AppColors.rojo)),
                          IconButton(
                            onPressed: () => _borrar(r),
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Borrar',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
