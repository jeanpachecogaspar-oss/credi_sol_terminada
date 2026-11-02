import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'formato.dart';
import 'ui_comun.dart';

typedef _Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

class DashboardScreen extends StatefulWidget {
  /// Cambia de pestaña en el panel de administración (1 Clientes, 2 Solicitudes, 3 Cobranzas).
  final ValueChanged<int>? onIrA;
  const DashboardScreen({super.key, this.onIrA});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _prestamos;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _clientes;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _cuotasPendientes;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _porVerificar;

  @override
  void initState() {
    super.initState();
    _crearStreams();
  }

  void _crearStreams() {
    final db = FirebaseFirestore.instance;
    _prestamos = db.collection('prestamos').snapshots();
    _clientes = db.collection('usuarios').where('rol', isEqualTo: 'cliente').snapshots();
    // Cuotas sin pagar de todos los préstamos; las vencidas se filtran por fecha en la app.
    _cuotasPendientes = db.collectionGroup('cuotas').where('estado', isEqualTo: 'Pendiente').snapshots();
    _porVerificar = db.collectionGroup('cuotas').where('estado', isEqualTo: 'Por verificar').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _prestamos,
        builder: (context, sp) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _clientes,
          builder: (context, sc) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _cuotasPendientes,
            builder: (context, sq) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _porVerificar,
              builder: (context, sv) {
                final error = sp.error ?? sc.error ?? sq.error ?? sv.error;
                if (error != null) {
                  return errorConsulta(
                    context,
                    'No se pudieron cargar los datos',
                    error,
                    () => setState(_crearStreams),
                  );
                }
                if (!sp.hasData || !sc.hasData || !sq.hasData || !sv.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _contenido(sp.data!.docs, sc.data!.docs, sq.data!.docs, sv.data!.docs);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(_Docs prestamos, _Docs clientes, _Docs cuotasPendientes, _Docs porVerificar) {
    var pendientes = 0;
    var activos = 0;
    var pagados = 0;
    var capital = 0.0;
    var porCobrar = 0.0;
    final idsActivos = <String>{};
    final nombres = <String, String>{};

    for (final d in prestamos) {
      final p = d.data();
      final e = p['estado'];
      nombres[d.id] = (p['clienteNombre'] ?? 'Sin nombre').toString();
      if (e == 'Pendiente') pendientes++;
      if (e == 'Activo') {
        activos++;
        idsActivos.add(d.id);
        porCobrar += aNum(p['saldoPendiente']);
      }
      if (e == 'Pagado') pagados++;
      if (e == 'Activo' || e == 'Pagado') capital += aNum(p['monto']);
    }

    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final vencidas = cuotasPendientes.where((c) {
      final prestamoId = c.reference.parent.parent!.id;
      final fecha = aFecha(c.data()['fecha']);
      return idsActivos.contains(prestamoId) && fecha != null && fecha.isBefore(inicioHoy);
    }).toList()
      ..sort((a, b) => aFecha(a.data()['fecha'])!.compareTo(aFecha(b.data()['fecha'])!));
    final montoVencido = vencidas.fold(0.0, (s, c) => s + aNum(c.data()['cuota']));

    return RefreshIndicator(
      onRefresh: () async => setState(_crearStreams),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.azul, AppColors.azulOscuro]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _grande('Capital prestado', fmtMoney(capital))),
                    Expanded(child: _grande('Saldo por cobrar', fmtMoney(porCobrar))),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _pequeno('Préstamos activos', '$activos')),
                    Expanded(child: _pequeno('Préstamos pagados', '$pagados')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _tile('Clientes', '${clientes.length}', Icons.people_alt_rounded, AppColors.azul,
                  onTap: widget.onIrA == null ? null : () => widget.onIrA!(1)),
              _tile('Solicitudes pendientes', '$pendientes', Icons.inbox_rounded, AppColors.ambar,
                  onTap: widget.onIrA == null ? null : () => widget.onIrA!(2)),
              _tile('Pagos por verificar', '${porVerificar.length}', Icons.payments_rounded, AppColors.verde,
                  onTap: widget.onIrA == null ? null : () => widget.onIrA!(3)),
              _tile(
                'Cuotas vencidas',
                '${vencidas.length}',
                Icons.warning_amber_rounded,
                AppColors.rojo,
                subtitulo: vencidas.isEmpty ? null : fmtMoney(montoVencido),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _CuotasVencidasScreen(vencidas: vencidas, nombres: nombres)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _grande(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _pequeno(String titulo, String valor) {
    return Row(
      children: [
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Flexible(child: Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
      ],
    );
  }

  Widget _tile(String titulo, String valor, IconData icono, Color color, {String? subtitulo, VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: tarjetaBlanca(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, color: color, size: 20),
                ),
                const Spacer(),
                if (onTap != null) Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    if (subtitulo != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitulo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CuotasVencidasScreen extends StatelessWidget {
  final _Docs vencidas;
  final Map<String, String> nombres;
  const _CuotasVencidasScreen({required this.vencidas, required this.nombres});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text('Cuotas vencidas (${vencidas.length})')),
      body: vencidas.isEmpty
          ? mensajeVacio(Icons.check_circle_outline_rounded, 'No hay cuotas vencidas', 'Todos los clientes están al día.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: vencidas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final doc = vencidas[i];
                final c = doc.data();
                final fecha = aFecha(c['fecha'])!;
                final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(fecha).inDays;
                final prestamoId = doc.reference.parent.parent!.id;
                return tarjetaBlanca(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.rojo.withValues(alpha: 0.12),
                        child: Text('${c['numero']}', style: const TextStyle(color: AppColors.rojo, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (c['clienteNombre'] ?? nombres[prestamoId] ?? 'Sin nombre').toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Venció ${fmtFecha(fecha)} · hace $dias ${dias == 1 ? 'día' : 'días'}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(fmtMoney(aNum(c['cuota'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
