import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'formato.dart';
import 'navegacion_cliente.dart';

/// Un factor que sube o baja el score, con su explicación.
class FactorScore {
  final String titulo;
  final String detalle;
  final int puntos;
  const FactorScore(this.titulo, this.detalle, this.puntos);
}

class ScoreCrediSol {
  final int puntaje; // 0..1000
  final List<FactorScore> factores;
  final double montoPreaprobado;
  const ScoreCrediSol(this.puntaje, this.factores, this.montoPreaprobado);

  String get nivel => puntaje >= 800
      ? 'Excelente'
      : puntaje >= 650
          ? 'Bueno'
          : puntaje >= 500
              ? 'Regular'
              : 'En construcción';

  Color get color => puntaje >= 800
      ? AppColors.verde
      : puntaje >= 650
          ? const Color(0xFF7CB342)
          : puntaje >= 500
              ? AppColors.ambar
              : AppColors.rojo;
}

/// Calcula el score con el historial real del cliente en Firestore:
/// puntualidad de pagos, cuotas vencidas, préstamos pagados, ingreso, carga de deuda,
/// antigüedad y verificación de identidad y domicilio (recibo vs GPS).
ScoreCrediSol calcularScore({
  required double ingreso,
  required int mesesAntiguedad,
  required bool dniVerificado,
  required String? estadoDomicilio, // 'verificado' | 'revisar' | null
  required int cuotasPuntuales,
  required int cuotasTarde,
  required int cuotasVencidas,
  required int prestamosPagados,
  required double cuotaMensualActiva,
}) {
  final f = <FactorScore>[];
  final pagadas = cuotasPuntuales + cuotasTarde;
  if (pagadas > 0) {
    final ratio = cuotasPuntuales / pagadas;
    f.add(FactorScore('Puntualidad', '$cuotasPuntuales de $pagadas cuotas pagadas a tiempo', (ratio * 250).round()));
  } else {
    f.add(const FactorScore('Puntualidad', 'Aún no tienes cuotas pagadas', 0));
  }
  if (cuotasTarde > 0) {
    f.add(FactorScore('Pagos con atraso', '$cuotasTarde cuotas pagadas después del vencimiento', -math.min(cuotasTarde * 30, 150)));
  }
  if (cuotasVencidas > 0) {
    f.add(FactorScore('Cuotas vencidas', '$cuotasVencidas cuotas pendientes ya vencieron', -math.min(cuotasVencidas * 70, 250)));
  }
  if (prestamosPagados > 0) {
    f.add(FactorScore('Préstamos pagados', '$prestamosPagados préstamos completados', math.min(prestamosPagados * 50, 150)));
  }
  if (ingreso > 0) {
    f.add(FactorScore('Ingreso declarado', fmtMoney(ingreso), math.min((ingreso / 2000 * 50).round(), 100)));
    final carga = cuotaMensualActiva / ingreso;
    if (cuotaMensualActiva > 0) {
      f.add(FactorScore(
        'Carga de deuda',
        'Tus cuotas son el ${(carga * 100).round()} % de tu ingreso',
        carga > 0.4 ? -100 : (carga > 0.25 ? -30 : 20),
      ));
    }
  }
  f.add(FactorScore('Antigüedad', '$mesesAntiguedad meses con CrediSol', math.min(mesesAntiguedad * 5, 60)));
  if (dniVerificado) f.add(const FactorScore('DNI validado con RENIEC', 'Tu identidad fue confirmada', 30));
  if (estadoDomicilio == 'verificado') {
    f.add(const FactorScore('Domicilio verificado', 'Tu recibo coincide con tu GPS', 60));
  } else if (estadoDomicilio == 'revisar') {
    f.add(const FactorScore('Domicilio por revisar', 'Tu recibo y tu GPS no coinciden del todo', 15));
  }
  final puntaje = (500 + f.fold<int>(0, (s, x) => s + x.puntos)).clamp(0, 1000);
  // Preaprobado: crece con el score y con el ingreso, dentro de los límites del préstamo.
  double pre = 0;
  if (puntaje >= 450 && cuotasVencidas == 0) {
    final base = ingreso > 0 ? ingreso * 4 * (puntaje - 400) / 600 : ConfigPrestamos.montoMinimo * 2;
    pre = ((base / 100).floor() * 100).toDouble().clamp(ConfigPrestamos.montoMinimo, ConfigPrestamos.montoMaximo).toDouble();
  }
  return ScoreCrediSol(puntaje, f, pre);
}

/// Lee los datos del cliente y calcula su score.
Future<ScoreCrediSol> scoreDelCliente(String uid) async {
  final db = FirebaseFirestore.instance;
  final perfil = (await db.collection('usuarios').doc(uid).get()).data() ?? {};
  String? domicilio;
  try {
    final recibo = await db.collection('usuarios').doc(uid).collection('documentos').doc('recibo_servicio').get();
    final v = recibo.data()?['validacion'];
    if (v is Map) domicilio = v['estado']?.toString();
  } catch (_) {}

  final prestamos = await db.collection('prestamos').where('clienteId', isEqualTo: uid).get();
  var puntuales = 0, tarde = 0, vencidas = 0, pagados = 0;
  var cuotaActiva = 0.0;
  final hoy = DateTime.now();
  for (final p in prestamos.docs) {
    final estado = p.data()['estado'];
    if (estado == 'Pagado') pagados++;
    if (estado != 'Activo' && estado != 'Pagado') continue;
    if (estado == 'Activo') cuotaActiva += (p.data()['cuotaMensual'] as num?)?.toDouble() ?? 0;
    final cuotas = await p.reference.collection('cuotas').get();
    for (final c in cuotas.docs) {
      final d = c.data();
      final vence = d['fecha'] is Timestamp ? (d['fecha'] as Timestamp).toDate() : null;
      if (vence == null) continue;
      final limite = DateTime(vence.year, vence.month, vence.day, 23, 59);
      if (d['estado'] == 'Pagada' || d['estado'] == 'Por verificar') {
        final pago = d['fechaPago'] is Timestamp ? (d['fechaPago'] as Timestamp).toDate() : null;
        if (pago != null && pago.isAfter(limite)) {
          tarde++;
        } else {
          puntuales++;
        }
      } else if (limite.isBefore(hoy)) {
        vencidas++;
      }
    }
  }
  final registro = perfil['fechaRegistro'] is Timestamp ? (perfil['fechaRegistro'] as Timestamp).toDate() : hoy;
  return calcularScore(
    ingreso: (perfil['ingresoMensual'] as num?)?.toDouble() ?? 0,
    mesesAntiguedad: (hoy.difference(registro).inDays / 30).floor(),
    dniVerificado: perfil['dniVerificado'] == true,
    estadoDomicilio: domicilio,
    cuotasPuntuales: puntuales,
    cuotasTarde: tarde,
    cuotasVencidas: vencidas,
    prestamosPagados: pagados,
    cuotaMensualActiva: cuotaActiva,
  );
}

// =================== Velocímetro ===================

/// Velocímetro animado de 0 a 1000 con aguja.
class Velocimetro extends StatelessWidget {
  final int puntaje;
  final double tamano;
  const Velocimetro({super.key, required this.puntaje, this.tamano = 240});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: puntaje.toDouble()),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: tamano,
        height: tamano * 0.8,
        child: CustomPaint(
          painter: _PintorVelocimetro(v / 1000),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              v.round().toString(),
              style: TextStyle(fontSize: tamano * 0.16, fontWeight: FontWeight.w800, color: AppColors.texto),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorVelocimetro extends CustomPainter {
  final double valor; // 0..1
  _PintorVelocimetro(this.valor);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height * 0.68);
    final radio = size.width * 0.44;
    final grosor = size.width * 0.075;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    // Fondo del arco
    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE8ECF3));
    // Arco de color (rojo → ámbar → verde)
    canvas.drawArc(rect, math.pi, math.pi * valor, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: math.pi,
            endAngle: 2 * math.pi,
            colors: [AppColors.rojo, AppColors.dorado, Color(0xFF7CB342), AppColors.verde],
          ).createShader(rect));
    // Marcas
    final marca = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;
    for (var i = 0; i <= 10; i++) {
      final a = math.pi + math.pi * i / 10;
      final p1 = centro + Offset(math.cos(a), math.sin(a)) * (radio - grosor * 0.9);
      final p2 = centro + Offset(math.cos(a), math.sin(a)) * (radio - grosor * (i % 5 == 0 ? 1.6 : 1.25));
      canvas.drawLine(p1, p2, marca);
    }
    // Aguja
    final a = math.pi + math.pi * valor;
    final punta = centro + Offset(math.cos(a), math.sin(a)) * (radio - grosor * 1.4);
    canvas.drawLine(
        centro,
        punta,
        Paint()
          ..color = AppColors.texto
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(centro, grosor * 0.45, Paint()..color = AppColors.texto);
  }

  @override
  bool shouldRepaint(_PintorVelocimetro old) => old.valor != valor;
}

// =================== Tarjeta en Inicio y pantalla de detalle ===================

/// Tarjeta del score en la pantalla de Inicio del cliente.
class TarjetaScore extends StatefulWidget {
  const TarjetaScore({super.key});

  @override
  State<TarjetaScore> createState() => _TarjetaScoreState();
}

class _TarjetaScoreState extends State<TarjetaScore> {
  late final Future<ScoreCrediSol> _futuro =
      scoreDelCliente(FirebaseAuth.instance.currentUser?.uid ?? '');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: FutureBuilder<ScoreCrediSol>(
        future: _futuro,
        builder: (context, snap) {
          final s = snap.data;
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: s == null
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreScreen(score: s))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (s == null)
                      SizedBox(
                        width: 120,
                        height: 96,
                        child: Center(
                          child: snap.hasError
                              ? const Icon(Icons.speed_rounded, color: AppColors.gris, size: 40)
                              : const CircularProgressIndicator(),
                        ),
                      )
                    else
                      Velocimetro(puntaje: s.puntaje, tamano: 120),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tu Score CrediSol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          if (s != null) ...[
                            Text(s.nivel, style: TextStyle(color: s.color, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              s.montoPreaprobado > 0
                                  ? 'Preaprobado hasta ${fmtMoney(s.montoPreaprobado)}'
                                  : 'Toca para ver cómo mejorarlo',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                            ),
                          ] else
                            Text(snap.hasError ? 'No disponible ahora' : 'Calculando…',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.gris),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ScoreScreen extends StatelessWidget {
  final ScoreCrediSol score;
  const ScoreScreen({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score;
    final factores = [...s.factores]..sort((a, b) => b.puntos.compareTo(a.puntos));
    return Scaffold(
      appBar: AppBar(title: const Text('Score CrediSol')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Velocimetro(puntaje: s.puntaje, tamano: 280)),
          const SizedBox(height: 6),
          Center(
            child: Text(s.nivel, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: s.color)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Puntaje de 0 a 1000 calculado con tu historial en CrediSol',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.azul, AppColors.azulOscuro]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFE082), size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monto preaprobado', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                      Text(
                        s.montoPreaprobado > 0 ? fmtMoney(s.montoPreaprobado) : 'Aún no disponible',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s.montoPreaprobado > 0) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                tabCliente.value = tabCreditos;
              },
              icon: const Icon(Icons.account_balance_rounded),
              label: const Text('Ver créditos para mí'),
            ),
          ],
          const SizedBox(height: 20),
          const Text('¿Qué influye en tu score?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final f in factores)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(
                      f.puntos > 0
                          ? Icons.trending_up_rounded
                          : f.puntos < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded,
                      color: f.puntos > 0 ? AppColors.verde : (f.puntos < 0 ? AppColors.rojo : AppColors.gris),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(f.detalle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(
                      f.puntos > 0 ? '+${f.puntos}' : '${f.puntos}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: f.puntos > 0 ? AppColors.verde : (f.puntos < 0 ? AppColors.rojo : AppColors.gris),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Consejo: paga tus cuotas antes del vencimiento y mantén tus cuotas por debajo del 40 % de tu ingreso.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
