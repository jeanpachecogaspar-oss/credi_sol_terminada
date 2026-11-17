import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'app_theme.dart';
import 'ui_comun.dart';

/// Lecturas en vivo de los sensores del celular (sensors_plus):
/// acelerómetro, acelerómetro sin gravedad, giroscopio y magnetómetro.
/// Cada tarjeta muestra los ejes X, Y, Z y la magnitud. Si el celular no
/// tiene un sensor, se indica en su tarjeta.
class SensoresScreen extends StatefulWidget {
  const SensoresScreen({super.key});

  @override
  State<SensoresScreen> createState() => _SensoresScreenState();
}

class _Lectura {
  final double x, y, z;
  const _Lectura(this.x, this.y, this.z);
  double get magnitud => math.sqrt(x * x + y * y + z * z);
}

class _SensoresScreenState extends State<SensoresScreen> {
  final _subs = <StreamSubscription<dynamic>>[];
  _Lectura? _acel, _lineal, _giro, _magn;
  final _errores = <String, bool>{};

  @override
  void initState() {
    super.initState();
    const periodo = SensorInterval.uiInterval;
    _escuchar<AccelerometerEvent>('acel', accelerometerEventStream(samplingPeriod: periodo),
        (e) => _acel = _Lectura(e.x, e.y, e.z));
    _escuchar<UserAccelerometerEvent>('lineal', userAccelerometerEventStream(samplingPeriod: periodo),
        (e) => _lineal = _Lectura(e.x, e.y, e.z));
    _escuchar<GyroscopeEvent>('giro', gyroscopeEventStream(samplingPeriod: periodo),
        (e) => _giro = _Lectura(e.x, e.y, e.z));
    _escuchar<MagnetometerEvent>('magn', magnetometerEventStream(samplingPeriod: periodo),
        (e) => _magn = _Lectura(e.x, e.y, e.z));
  }

  void _escuchar<T>(String clave, Stream<T> stream, void Function(T) alLeer) {
    _subs.add(stream.listen(
      (e) {
        if (!mounted) return;
        setState(() => alLeer(e));
      },
      onError: (Object e) {
        debugPrint('Sensor $clave: $e');
        if (mounted) setState(() => _errores[clave] = true);
      },
      cancelOnError: true,
    ));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Inclinación del celular a partir de la gravedad (acelerómetro).
  String get _orientacion {
    final a = _acel;
    if (a == null) return '—';
    if (a.z < -7.5) return 'Boca abajo';
    if (a.z > 7.5) return 'Sobre la mesa, boca arriba';
    if (a.y.abs() > a.x.abs()) return a.y > 0 ? 'Vertical' : 'Vertical invertido';
    return a.x > 0 ? 'Horizontal (izquierda)' : 'Horizontal (derecha)';
  }

  /// Rumbo aproximado con el magnetómetro (válido con el celular plano).
  String get _brujula {
    final m = _magn;
    if (m == null) return '—';
    var grados = math.atan2(m.y, m.x) * 180 / math.pi;
    grados = (90 - grados) % 360;
    if (grados < 0) grados += 360;
    const puntos = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final p = puntos[((grados + 22.5) ~/ 45) % 8];
    return '${grados.toStringAsFixed(0)}° $p';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensores del celular')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Valores en tiempo real. Mueve, gira o inclina el celular para ver cómo cambian.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          tarjetaBlanca(
            child: Row(
              children: [
                Expanded(child: _resumen(Icons.screen_rotation_rounded, 'Posición', _orientacion)),
                Expanded(child: _resumen(Icons.explore_rounded, 'Brújula', _brujula)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _tarjeta('Acelerómetro', 'Incluye la gravedad', 'm/s²', Icons.speed_rounded, AppColors.azul, _acel,
              _errores['acel'] == true),
          _tarjeta('Aceleración lineal', 'Movimiento sin la gravedad', 'm/s²', Icons.open_with_rounded,
              AppColors.verde, _lineal, _errores['lineal'] == true),
          _tarjeta('Giroscopio', 'Velocidad de giro', 'rad/s', Icons.threesixty_rounded, const Color(0xFF7E57C2),
              _giro, _errores['giro'] == true),
          _tarjeta('Magnetómetro', 'Campo magnético', 'µT', Icons.explore_outlined, AppColors.ambar, _magn,
              _errores['magn'] == true),
          const SizedBox(height: 6),
          Text(
            'CrediSol usa el acelerómetro en el "Modo privado" (boca abajo o agitar oculta los montos) y '
            'en la inclinación 3D del inicio de sesión.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _resumen(IconData icono, String titulo, String valor) {
    return Column(
      children: [
        Icon(icono, color: AppColors.azul),
        const SizedBox(height: 4),
        Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(valor, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _tarjeta(String titulo, String sub, String unidad, IconData icono, Color color, _Lectura? l, bool error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: tarjetaBlanca(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                if (l != null)
                  Text('${l.magnitud.toStringAsFixed(2)} $unidad',
                      style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            if (error)
              Text('Este celular no tiene este sensor.', style: TextStyle(color: Colors.grey.shade600))
            else if (l == null)
              Text('Esperando lectura…', style: TextStyle(color: Colors.grey.shade600))
            else
              Row(
                children: [
                  _eje('X', l.x, color),
                  _eje('Y', l.y, color),
                  _eje('Z', l.z, color),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _eje(String eje, double v, Color color) {
    // Barra centrada: hacia la derecha si es positivo, a la izquierda si es negativo.
    final frac = (v.abs() / 20).clamp(0.0, 1.0);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(eje, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(v.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: v < 0 ? frac : 0,
                          child: Container(color: color),
                        ),
                      ),
                    ),
                    Container(width: 1, color: Colors.grey.shade400),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: v > 0 ? frac : 0,
                          child: Container(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
