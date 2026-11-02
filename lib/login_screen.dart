import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'registro_screen.dart';
import 'recuperar_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;

  /// Entrada: la tarjeta se despliega en 3D y la moneda-logo da dos vueltas.
  late final AnimationController _entrada;

  /// Bucle suave: la moneda flota y oscila y las monedas del fondo se mueven.
  late final AnimationController _flotar;
  late final Animation<double> _eslogan;

  /// Inclinación del celular (acelerómetro), suavizada. Solo redibuja las capas 3D,
  /// nunca el formulario.
  final ValueNotifier<Offset> _inclinacion = ValueNotifier(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sensor;

  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color dorado = Color(0xFFF2B705);

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _flotar = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _eslogan = CurvedAnimation(parent: _entrada, curve: const Interval(0.4, 0.9));
    try {
      _sensor = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        // x: izquierda/derecha, y: adelante/atrás (≈ 9.8 en vertical). Filtro paso bajo.
        final objetivo = Offset((e.x / 9.8).clamp(-1.0, 1.0), ((e.y - 6.5) / 9.8).clamp(-1.0, 1.0));
        final actual = _inclinacion.value;
        _inclinacion.value = actual + (objetivo - actual) * 0.15;
      }, onError: (Object _) {}, cancelOnError: true);
    } catch (_) {
      // Sin acelerómetro: la tarjeta queda fija.
    }
  }

  /// Si el usuario pidió "reducir animaciones" en el sistema, se muestra todo quieto.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _entrada.value = 1;
      _flotar.stop();
    }
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _entrada.dispose();
    _flotar.dispose();
    _inclinacion.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    // La contraseña no se recorta: un espacio puede ser parte de ella.
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _mensaje('Ingresa tu correo y contraseña');
      return;
    }

    setState(() => _cargando = true);

    try {
      // Al iniciar sesión, AuthGate detecta el cambio y abre la pantalla según el rol.
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _mensaje('No existe una cuenta con ese correo');
          break;
        case 'wrong-password':
          _mensaje('Contraseña incorrecta');
          break;
        case 'invalid-email':
          _mensaje('El correo no es válido');
          break;
        case 'invalid-credential':
          _mensaje('Correo o contraseña incorrectos');
          break;
        case 'network-request-failed':
          _mensaje('Sin conexión a internet');
          break;
        default:
          _mensaje('Error al iniciar sesión: ${e.message}');
      }
    } catch (e) {
      _mensaje('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: azulOscuro,
      body: Stack(
        children: [
          // Capa 1: fondo con degradado y monedas 3D en profundidad (parallax).
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_flotar, _inclinacion]),
                builder: (context, _) => CustomPaint(
                  painter: _FondoProfundidad(t: _flotar.value, inclinacion: _inclinacion.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    // Capa 2: moneda-logo 3D.
                    RepaintBoundary(child: _MonedaLogo(entrada: _entrada, flotar: _flotar, inclinacion: _inclinacion)),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _eslogan,
                      child: const Text(
                        'Impulsando a crecer tu negocio',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.3),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Capa 3: tarjeta del formulario en 3D (se despliega y se inclina con el celular).
                    AnimatedBuilder(
                      animation: Listenable.merge([_entrada, _inclinacion]),
                      child: _tarjeta(),
                      builder: (context, tarjeta) {
                        final t = Curves.easeOutBack.transform(
                          const Interval(0.25, 1).transform(_entrada.value),
                        );
                        final inc = _inclinacion.value;
                        final m = Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateX((1 - t) * 1.1 + inc.dy * 0.12)
                          ..rotateY(-inc.dx * 0.14);
                        return Opacity(
                          opacity: Curves.easeOut.transform(const Interval(0.25, 0.7).transform(_entrada.value)),
                          child: Transform(alignment: Alignment.center, transform: m, child: tarjeta),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta() {
    return Container(
      padding: const EdgeInsets.all(28),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 40, offset: const Offset(0, 24)),
          BoxShadow(color: dorado.withValues(alpha: 0.18), blurRadius: 2, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bienvenido',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          Text('Inicia sesión para continuar', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 26),
          _campoTexto(
            controller: _emailController,
            label: 'Correo electrónico',
            icono: Icons.email_outlined,
            teclado: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _campoTexto(
            controller: _passwordController,
            label: 'Contraseña',
            icono: Icons.lock_outline,
            esPassword: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cargando
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecuperarPasswordScreen(
                            emailInicial: _emailController.text.trim(),
                          ),
                        ),
                      );
                    },
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: azul, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _cargando ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [azul, azulOscuro]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _cargando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                        )
                      : const Text(
                          'Ingresar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _cargando
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegistroScreen()),
                      ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  children: const [
                    TextSpan(text: '¿No tienes cuenta? '),
                    TextSpan(
                      text: 'Regístrate',
                      style: TextStyle(color: azul, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    TextInputType? teclado,
    bool esPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      obscureText: esPassword ? _ocultarPassword : false,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icono, color: azul, size: 20),
        suffixIcon: esPassword
            ? IconButton(
                icon: Icon(
                  _ocultarPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
              )
            : null,
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: azul, width: 1.5),
        ),
      ),
    );
  }
}

/// Moneda 3D con el logo: entra girando dos vueltas sobre el eje Y y luego flota,
/// oscila y sigue la inclinación del celular. Tiene canto dorado para dar grosor.
class _MonedaLogo extends StatelessWidget {
  final AnimationController entrada;
  final AnimationController flotar;
  final ValueNotifier<Offset> inclinacion;
  const _MonedaLogo({required this.entrada, required this.flotar, required this.inclinacion});

  @override
  Widget build(BuildContext context) {
    const tam = 132.0;
    final cara = Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Colors.white, Color(0xFFEFF3F9)],
        ),
        border: Border.all(color: const Color(0xFFF2B705), width: 5),
      ),
      padding: const EdgeInsets.all(22),
      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([entrada, flotar, inclinacion]),
      builder: (context, _) {
        final e = Curves.easeOutCubic.transform(const Interval(0, 0.85).transform(entrada.value));
        final f = flotar.value * 2 * math.pi;
        final inc = inclinacion.value;
        final giro = (1 - e) * 4 * math.pi + math.sin(f) * 0.35 + inc.dx * 0.5;
        final y = math.sin(f * 2) * 6;
        final escala = 0.6 + 0.4 * e;
        // Grosor: capas desplazadas detrás de la cara (canto de la moneda).
        final canto = <Widget>[
          for (var i = 6; i > 0; i--)
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(giro)
                ..translateByDouble(0.0, 0.0, i * 1.6, 1.0),
              child: Container(
                width: tam,
                height: tam,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC99700)),
              ),
            ),
        ];
        return Transform.translate(
          offset: Offset(0, y),
          child: Transform.scale(
            scale: escala,
            child: SizedBox(
              width: tam + 20,
              height: tam + 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sombra en el "piso".
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: tam * (0.7 - y / 60),
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.black.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  ...canto,
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateX(-inc.dy * 0.3)
                      ..rotateY(giro),
                    child: cara,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fondo con degradado de marca y monedas en tres profundidades que se desplazan
/// distinto según la inclinación (efecto parallax 3D).
class _FondoProfundidad extends CustomPainter {
  final double t;
  final Offset inclinacion;
  _FondoProfundidad({required this.t, required this.inclinacion});

  static const _monedas = [
    // x, y (0..1), radio, profundidad (1 = cerca)
    (0.12, 0.10, 34.0, 0.9), (0.85, 0.16, 22.0, 0.5), (0.70, 0.42, 14.0, 0.3),
    (0.08, 0.55, 18.0, 0.4), (0.90, 0.70, 40.0, 1.0), (0.25, 0.86, 26.0, 0.7),
    (0.55, 0.06, 12.0, 0.25), (0.45, 0.95, 16.0, 0.35),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ).createShader(rect),
    );
    for (final (x, y, r, z) in _monedas) {
      final fase = t * 2 * math.pi + x * 10;
      final c = Offset(
        x * size.width - inclinacion.dx * 40 * z + math.sin(fase) * 6 * z,
        y * size.height + inclinacion.dy * 30 * z + math.cos(fase) * 8 * z,
      );
      final radio = r * (0.8 + 0.2 * math.cos(fase));
      // Canto (sombra desplazada) + cara con brillo: da sensación de volumen.
      canvas.drawCircle(c + Offset(0, 3 * z), radio, Paint()..color = const Color(0xFFB38600).withValues(alpha: 0.35 + 0.4 * z));
      canvas.drawCircle(
        c,
        radio,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [const Color(0xFFFFE082).withValues(alpha: 0.5 + 0.5 * z), const Color(0xFFF2B705).withValues(alpha: 0.35 + 0.5 * z)],
          ).createShader(Rect.fromCircle(center: c, radius: radio)),
      );
    }
  }

  @override
  bool shouldRepaint(_FondoProfundidad old) => old.t != t || old.inclinacion != inclinacion;
}
