import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'errores.dart';
import 'formato.dart';
import 'mis_prestamos_screen.dart';
import 'navegacion_cliente.dart';
import 'soporte.dart';
import 'apis_peru.dart';
import 'cercanos_screen.dart';
import 'promociones.dart';
import 'score_screen.dart';
import 'sensores_camara.dart';
import 'ui_comun.dart';

/// Pantalla principal del cliente: préstamos activos con su próxima cuota,
/// solicitudes en revisión o, si no tiene nada, una invitación a simular.
class ClienteInicioScreen extends StatelessWidget {
  const ClienteInicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    final db = FirebaseFirestore.instance;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, perfilSnap) {
          final nombre = (perfilSnap.data?.data()?['nombre'] ?? '').toString().trim();
          final primerNombre = nombre.isEmpty ? '' : nombre.split(' ').first;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('prestamos').where('clienteId', isEqualTo: user.uid).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final activos = docs.where((d) => d.data()['estado'] == 'Activo').toList();
              final pendientes = docs.where((d) => d.data()['estado'] == 'Pendiente').toList();

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _encabezado(context, primerNombre),
                  const _PromosInicio(),
                  const _AccionesRapidas(),
                  const _PagarCerca(),
                  const TarjetaScore(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (snap.hasError)
                          mensajeVacio(Icons.error_outline_rounded, 'No se pudieron cargar tus préstamos',
                              mensajeError(snap.error!))
                        else if (!snap.hasData)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          for (final p in activos) ...[
                            _TarjetaPrestamoActivo(doc: p),
                            const SizedBox(height: 16),
                          ],
                          for (final p in pendientes) ...[
                            _tarjetaPendiente(context, p),
                            const SizedBox(height: 16),
                          ],
                          if (activos.isEmpty && pendientes.isEmpty) _sinPrestamos(context),
                        ],
                        const SizedBox(height: 8),
                        const BotonWhatsApp(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _encabezado(BuildContext context, String nombre) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.azul, AppColors.azulOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Image.asset('assets/logo.png', height: 30, fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          Text(
            nombre.isEmpty ? '¡Hola!' : '¡Hola, $nombre!',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Aquí ves el estado de tus préstamos.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPendiente(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final p = doc.data();
    final fecha = aFecha(p['fechaSolicitud']);
    return tarjetaBlanca(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: AppColors.ambar),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Solicitud en revisión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              chipEstado('Pendiente'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${fmtMoney(aNum(p['monto']))} a ${p['plazoMeses']} meses · cuota aprox. ${fmtMoney(aNum(p['cuotaMensual']))}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (fecha != null)
            Text('Enviada ${haceTiempo(fecha)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => cancelarSolicitud(context, doc.reference),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rojo,
                    side: const BorderSide(color: AppColors.rojo),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetallePrestamoCliente(prestamoId: doc.id)),
                  ),
                  child: const Text('Ver detalle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sinPrestamos(BuildContext context) {
    return tarjetaBlanca(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 56, color: AppColors.azul.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          const Text('No tienes préstamos activos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Simula cuánto pagarías y envía tu solicitud en minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => tabCliente.value = tabSimular,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Simular préstamo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Préstamo activo: saldo, progreso y próxima cuota con botón de pago.
class _TarjetaPrestamoActivo extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _TarjetaPrestamoActivo({required this.doc});

  @override
  Widget build(BuildContext context) {
    final p = doc.data();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: doc.reference.collection('cuotas').orderBy('numero').snapshots(),
      builder: (context, snap) {
        final cuotas = snap.data?.docs ?? [];
        final pagadas = cuotas.where((c) => c.data()['estado'] == 'Pagada').length;
        final enVerificacion = cuotas.where((c) => c.data()['estado'] == 'Por verificar').length;
        final idx = cuotas.indexWhere((c) => (c.data()['estado'] ?? 'Pendiente') == 'Pendiente');
        final proxima = idx >= 0 ? cuotas[idx] : null;
        final total = cuotas.isEmpty ? (p['plazoMeses'] as num?)?.toInt() ?? 0 : cuotas.length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: AppColors.azul.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Saldo pendiente', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        const Spacer(),
                        Text(
                          'Préstamo de ${fmtMoney(aNum(p['monto']))}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtMoney(aNum(p['saldoPendiente'])),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : pagadas / total,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: AppColors.verde,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$pagadas de $total cuotas pagadas',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (enVerificacion > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          enVerificacion == 1
                              ? '1 pago en verificación'
                              : '$enVerificacion pagos en verificación',
                          style: const TextStyle(color: AppColors.ambar, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              if (snap.connectionState == ConnectionState.waiting && cuotas.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else if (proxima != null)
                _proximaCuota(context, proxima)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    enVerificacion > 0
                        ? 'Estamos verificando tu último pago.'
                        : 'No tienes cuotas pendientes.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetallePrestamoCliente(prestamoId: doc.id)),
                  ),
                  child: const Text('Ver cronograma completo'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _proximaCuota(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> cuota) {
    final c = cuota.data();
    final vence = aFecha(c['fecha']) ?? DateTime.now();
    final hoy = DateTime.now();
    final dias = DateTime(vence.year, vence.month, vence.day).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final vencida = dias < 0;
    final textoDias = dias == 0
        ? 'Vence hoy'
        : vencida
            ? 'Vencida hace ${-dias} ${-dias == 1 ? 'día' : 'días'}'
            : 'Vence en $dias ${dias == 1 ? 'día' : 'días'}';
    final color = vencida ? AppColors.rojo : (dias <= 3 ? AppColors.ambar : AppColors.azul);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Próxima cuota (${c['numero']})', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtMoney(aNum(c['cuota'])), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(textoDias, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(fmtFecha(vence), style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
            ],
          ),
          if ((c['motivoRechazoPago'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tu último pago fue rechazado: ${c['motivoRechazoPago']}',
                style: const TextStyle(color: AppColors.rojo, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => mostrarPagar(context, cuota),
              style: vencida ? ElevatedButton.styleFrom(backgroundColor: AppColors.rojo) : null,
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Pagar ahora'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Promociones del cliente en la pantalla de inicio. Al tocarlas abre la tienda.
class _PromosInicio extends StatefulWidget {
  const _PromosInicio();

  @override
  State<_PromosInicio> createState() => _PromosInicioState();
}

class _PromosInicioState extends State<_PromosInicio> {
  late final Stream<List<Promocion>> _stream =
      promocionesDelCliente(FirebaseAuth.instance.currentUser?.uid ?? '').asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: CarruselPromociones(
        stream: _stream,
        onTap: () => tabCliente.value = tabCreditos,
      ),
    );
  }
}

/// Los dos botones de la rúbrica: CÁMARA (escanear DNI) y SENSOR (modo privado).
class _AccionesRapidas extends StatelessWidget {
  const _AccionesRapidas();

  Future<void> _escanearDni(BuildContext context) async {
    final dni = await leerDniConCamara(context);
    if (dni == null || !context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? dniCuenta;
    if (uid != null) {
      try {
        final d = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        dniCuenta = d.data()?['dni']?.toString();
      } catch (_) {}
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => _ResultadoDni(dni: dni, dniCuenta: dniCuenta),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _BotonGrande(
              icono: Icons.document_scanner_rounded,
              etiqueta: 'CÁMARA',
              titulo: 'Escanear DNI',
              color: AppColors.azul,
              onTap: () => _escanearDni(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: ModoPrivado.activo,
              builder: (context, activo, _) => _BotonGrande(
                icono: activo ? Icons.visibility_off_rounded : Icons.screen_rotation_alt_rounded,
                etiqueta: 'SENSOR',
                titulo: activo ? 'Modo privado ON' : 'Modo privado',
                color: activo ? AppColors.verde : AppColors.ambar,
                pie: activo
                    ? ValueListenableBuilder<double>(
                        valueListenable: ModoPrivado.lectura,
                        builder: (context, v, _) => Text(
                          '${v.toStringAsFixed(1)} m/s² · voltea o agita',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                      )
                    : null,
                onTap: () {
                  ModoPrivado.alternarSensor();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ModoPrivado.activo.value
                        ? 'Modo privado activo: pon el celular boca abajo o agítalo para ocultar tus montos.'
                        : 'Modo privado desactivado.'),
                  ));
                },
                onLongPress: ModoPrivado.alternarMontos,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String titulo;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? pie;
  const _BotonGrande({
    required this.icono,
    required this.etiqueta,
    required this.titulo,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icono, color: color, size: 26),
                  ),
                  const Spacer(),
                  Text(etiqueta,
                      style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
              const SizedBox(height: 10),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (pie != null) pie!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado de escanear el DNI: número leído, nombre en RENIEC y si coincide con la cuenta.
class _ResultadoDni extends StatelessWidget {
  final String dni;
  final String? dniCuenta;
  const _ResultadoDni({required this.dni, required this.dniCuenta});

  @override
  Widget build(BuildContext context) {
    final coincide = dniCuenta != null && dniCuenta == dni;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DNI escaneado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(dni, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 3)),
            const SizedBox(height: 10),
            FutureBuilder<PersonaDni>(
              future: ApisPeru.dni(dni),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Consultando RENIEC…'),
                  ]);
                }
                if (snap.hasError) {
                  return Text(snap.error.toString(), style: TextStyle(color: Colors.grey.shade700));
                }
                return Row(children: [
                  const Icon(Icons.person_rounded, color: AppColors.azul),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(snap.data!.nombreCompleto,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ]);
              },
            ),
            const SizedBox(height: 14),
            if (dniCuenta != null && dniCuenta!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (coincide ? AppColors.verde : AppColors.rojo).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(coincide ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                      color: coincide ? AppColors.verde : AppColors.rojo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      coincide
                          ? 'Identidad confirmada: es el DNI de tu cuenta.'
                          : 'Este DNI no coincide con el de tu cuenta ($dniCuenta).',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Acceso al mapa "Pagar cerca de ti" (geolocalización útil, sin rastreo).
class _PagarCerca extends StatelessWidget {
  const _PagarCerca();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.verde.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.near_me_rounded, color: AppColors.verde),
          ),
          title: const Text('Pagar cerca de ti', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Agencias, bancos, cajeros y agentes en el mapa', style: TextStyle(fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CercanosScreen())),
        ),
      ),
    );
  }
}
