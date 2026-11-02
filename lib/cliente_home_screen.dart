import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'cronograma.dart';
import 'formato.dart';
import 'solicitud_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  static const Color azul = AppColors.azul;
  static const Color azulOscuro = AppColors.azulOscuro;
  static const Color dorado = AppColors.dorado;

  // La tasa la define el negocio (config_prestamos.dart); el cliente no la elige.
  static const double _tasaSim = ConfigPrestamos.tasa;
  static const bool _tasaAnualSim = ConfigPrestamos.tasaAnual;

  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _plazoCtrl = TextEditingController();

  double _montoSolicitado = 0;
  int _plazoSolicitado = 0;
  List<CuotaCalc> _cronograma = [];

  @override
  void dispose() {
    _montoCtrl.dispose();
    _plazoCtrl.dispose();
    super.dispose();
  }

  // ---------- Cálculo ----------

  void _calcular() {
    FocusScope.of(context).unfocus();

    final monto = double.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
    final plazo = int.tryParse(_plazoCtrl.text.trim());

    if (monto == null || monto < ConfigPrestamos.montoMinimo || monto > ConfigPrestamos.montoMaximo) {
      _msg('El monto debe estar entre ${fmtMoney(ConfigPrestamos.montoMinimo)} y ${fmtMoney(ConfigPrestamos.montoMaximo)}');
      return;
    }
    if (plazo == null || plazo < ConfigPrestamos.plazoMinimo || plazo > ConfigPrestamos.plazoMaximo) {
      _msg('El plazo debe estar entre ${ConfigPrestamos.plazoMinimo} y ${ConfigPrestamos.plazoMaximo} meses');
      return;
    }

    setState(() {
      _montoSolicitado = monto;
      _plazoSolicitado = plazo;
      _cronograma = generarCronograma(
        monto: monto,
        tasa: _tasaSim,
        tasaAnual: _tasaAnualSim,
        plazo: plazo,
        fechaInicio: DateTime.now(),
      );
    });
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  void _solicitar() {
    if (_cronograma.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolicitudScreen(
          monto: _montoSolicitado,
          tasa: _tasaSim,
          tasaAnual: _tasaAnualSim,
          plazo: _plazoSolicitado,
          fechaInicio: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  double get _totalInteres => totalIntereses(_cronograma);
  double get _totalPagar => totalCuotas(_cronograma);
  double get _tcea => calcularTcea(_montoSolicitado, _cronograma.map((c) => c.cuota).toList());

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _encabezado(email),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  _tarjetaFormulario(),
                  if (_cronograma.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _tarjetaResumen(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _solicitar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.verde,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Solicitar este préstamo', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _tarjetaCronograma(),
                    const SizedBox(height: 12),
                    Text(
                      'Cálculo referencial con cuotas fijas (sistema francés). Sin comisiones ni seguros. '
                      'Las fechas definitivas se fijan cuando se aprueba el préstamo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(String email) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [azul, azulOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/logo.png', height: 30, fit: BoxFit.contain),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Simula tu préstamo',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: azul.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _campo(TextEditingController c, String label, IconData icono, {String? prefijo, String? ayuda, bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
      decoration: InputDecoration(
        prefixIcon: Icon(icono, color: azul, size: 20),
        prefixText: prefijo,
        labelText: label,
        helperText: ayuda,
      ),
    );
  }

  Widget _tarjetaFormulario() {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos del préstamo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _campo(
            _montoCtrl,
            'Monto del préstamo',
            Icons.payments_outlined,
            prefijo: 'S/ ',
            decimal: true,
            ayuda: 'Entre ${fmtMoney(ConfigPrestamos.montoMinimo)} y ${fmtMoney(ConfigPrestamos.montoMaximo)}',
          ),
          const SizedBox(height: 16),
          _campo(
            _plazoCtrl,
            'Plazo (meses)',
            Icons.calendar_month_outlined,
            ayuda: 'De ${ConfigPrestamos.plazoMinimo} a ${ConfigPrestamos.plazoMaximo} meses',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: azul.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.percent_rounded, color: azul, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tasa: ${ConfigPrestamos.descripcionTasa}. Sin comisiones ni cargos ocultos.',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _calcular,
              child: const Text('Calcular cronograma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [azul, azulOscuro]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cuota mensual', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                fmtMoney(_cronograma.first.cuota),
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_cronograma.length} cuotas · ${ConfigPrestamos.descripcionTasa} · TCEA ${_tcea.toStringAsFixed(2)}%',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _mini('Monto', fmtMoney(_montoSolicitado), azul)),
            const SizedBox(width: 10),
            Expanded(child: _mini('Intereses', fmtMoney(_totalInteres), AppColors.rojo)),
            const SizedBox(width: 10),
            Expanded(child: _mini('Total a pagar', fmtMoney(_totalPagar), dorado)),
          ],
        ),
      ],
    );
  }

  Widget _mini(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCronograma() {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cronograma referencial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 22,
              headingRowHeight: 44,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF2FD)),
              columns: const [
                DataColumn(label: Text('N°', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Cuota', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Interés', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Amortiz.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: [
                ..._cronograma.map(
                  (c) => DataRow(cells: [
                    DataCell(Text('${c.numero}')),
                    DataCell(Text(fmtFecha(c.fecha))),
                    DataCell(Text(fmtNum(c.cuota))),
                    DataCell(Text(fmtNum(c.interes))),
                    DataCell(Text(fmtNum(c.amortizacion))),
                    DataCell(Text(fmtNum(c.saldo))),
                  ]),
                ),
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xFFFFF8E1)),
                  cells: [
                    const DataCell(Text('')),
                    const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(fmtNum(_totalPagar), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(fmtNum(_totalInteres), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(fmtNum(_montoSolicitado), style: const TextStyle(fontWeight: FontWeight.bold))),
                    const DataCell(Text('')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
