import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'avisos.dart';

/// Entrar con huella digital (o rostro / PIN del celular).
///
/// Funciona como en las apps de bancos: NO se guarda la contraseña. La sesión de
/// Firebase ya queda guardada en el celular; la huella es una cerradura encima de ella.
/// Se pide al abrir la app y al volver después de [Huella.tiempoFuera] en segundo plano.
/// Si la huella falla, el usuario puede usar el PIN del celular o su contraseña.
class Huella {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Tiempo en segundo plano tras el cual se vuelve a pedir la huella.
  static const Duration tiempoFuera = Duration(minutes: 2);

  /// true justo después de entrar con contraseña: en ese momento no se pide la huella.
  static bool recienAutenticado = false;

  static String _clave(String uid) => 'huella_$uid';
  static String _claveOfrecida(String uid) => 'huella_ofrecida_$uid';

  static Future<bool> activa(String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_clave(uid)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _guardar(String uid, bool valor) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_clave(uid), valor);
    await p.setBool(_claveOfrecida(uid), true);
  }

  /// ¿El celular tiene huella, rostro o al menos PIN/patrón configurado?
  static Future<bool> disponible() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Pide la huella. Devuelve null si se autenticó; si no, el motivo para mostrar.
  static Future<String?> autenticar(String motivo) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        // Permite usar el PIN o patrón del celular si la huella no funciona:
        // así nadie se queda fuera de su cuenta.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? null : 'No se pudo verificar tu identidad.';
    } on LocalAuthException catch (e) {
      debugPrint('Huella: ${e.code} ${e.description}');
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
          return 'Verificación cancelada.';
        case LocalAuthExceptionCode.temporaryLockout:
          return 'Demasiados intentos. Espera unos segundos o entra con tu contraseña.';
        case LocalAuthExceptionCode.biometricLockout:
          return 'Huella bloqueada por demasiados intentos. Entra con tu contraseña.';
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricHardware:
          return 'Tu celular ya no tiene huella ni PIN configurado. Entra con tu contraseña.';
        default:
          return 'No se pudo usar la huella. Entra con tu contraseña.';
      }
    } catch (e) {
      debugPrint('Huella: $e');
      return 'No se pudo usar la huella. Entra con tu contraseña.';
    }
  }

  /// Activa la huella solo si el usuario la confirma en ese momento.
  static Future<String?> activar(String uid) async {
    if (!await disponible()) return 'Tu celular no tiene huella ni bloqueo de pantalla configurado.';
    final error = await autenticar('Confirma tu huella para activar el ingreso con huella');
    if (error == null) await _guardar(uid, true);
    return error;
  }

  static Future<void> desactivar(String uid) => _guardar(uid, false);

  /// Después del primer ingreso con contraseña, ofrece activar la huella una sola vez.
  static Future<void> ofrecerSiCorresponde(BuildContext context, String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_claveOfrecida(uid)) ?? false) return;
      if (await activa(uid) || !await disponible()) return;
      await p.setBool(_claveOfrecida(uid), true);
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint_rounded, size: 44, color: AppColors.azul),
        title: const Text('¿Entrar con tu huella?'),
        content: const Text(
          'La próxima vez abre CrediSol con tu huella, sin escribir la contraseña. '
          'Puedes cambiarlo cuando quieras en Perfil.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Activar')),
        ],
      ),
    );
    if (si != true) return;
    final error = await activar(uid);
    messenger.mostrarAviso(SnackBar(content: Text(error ?? 'Listo: la próxima vez entrarás con tu huella')));
  }
}

/// Envuelve la app de un usuario con sesión y la bloquea con huella cuando corresponde.
/// El contenido sigue montado debajo (no se pierde lo que estaba haciendo ni se recargan
/// los datos), pero queda tapado por la pantalla de bloqueo.
class BloqueoHuella extends StatefulWidget {
  final String uid;
  final Widget child;
  const BloqueoHuella({super.key, required this.uid, required this.child});

  @override
  State<BloqueoHuella> createState() => _BloqueoHuellaState();
}

class _BloqueoHuellaState extends State<BloqueoHuella> with WidgetsBindingObserver {
  bool _bloqueado = false;
  bool _verificando = false;
  bool _ocultarEnRecientes = false;
  bool _activa = false;
  DateTime? _enSegundoPlanDesde;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final recien = Huella.recienAutenticado;
    Huella.recienAutenticado = false;
    Huella.activa(widget.uid).then((activa) {
      if (!mounted) return;
      _activa = activa;
      if (activa && !recien) {
        setState(() => _bloqueado = true);
        _desbloquear();
      } else if (recien) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Huella.ofrecerSiCorresponde(context, widget.uid);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El diálogo de huella también cambia el estado de la app: se ignora mientras se verifica.
    if (_verificando) return;
    Huella.activa(widget.uid).then((v) => _activa = v);
    if (state == AppLifecycleState.paused) {
      _enSegundoPlanDesde ??= DateTime.now();
    }
    // Tapa los montos en la vista de "apps recientes".
    if (_activa && mounted) {
      setState(() => _ocultarEnRecientes = state != AppLifecycleState.resumed);
    }
    if (state == AppLifecycleState.resumed) {
      final desde = _enSegundoPlanDesde;
      _enSegundoPlanDesde = null;
      if (_activa && desde != null && DateTime.now().difference(desde) >= Huella.tiempoFuera) {
        setState(() => _bloqueado = true);
        _desbloquear();
      }
    }
  }

  Future<void> _desbloquear() async {
    if (_verificando) return;
    setState(() {
      _verificando = true;
      _error = null;
    });
    final error = await Huella.autenticar('Usa tu huella para entrar a CrediSol');
    if (!mounted) return;
    setState(() {
      _verificando = false;
      _error = error;
      if (error == null) _bloqueado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bloqueada, la app no recibe toques ni lectores de pantalla.
        ExcludeSemantics(
          excluding: _bloqueado,
          child: AbsorbPointer(absorbing: _bloqueado, child: widget.child),
        ),
        if (_bloqueado)
          Positioned.fill(child: _PantallaBloqueo(verificando: _verificando, error: _error, onHuella: _desbloquear))
        else if (_ocultarEnRecientes)
          const Positioned.fill(child: _Cortina()),
      ],
    );
  }
}

class _PantallaBloqueo extends StatelessWidget {
  final bool verificando;
  final String? error;
  final VoidCallback onHuella;
  const _PantallaBloqueo({required this.verificando, required this.error, required this.onHuella});

  @override
  Widget build(BuildContext context) {
    final correo = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: Paleta.superficie,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _Logo(),
              const SizedBox(height: 28),
              const Text('Hola de nuevo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(correo, style: TextStyle(color: Paleta.gris600)),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Entrar con huella',
                child: InkResponse(
                  onTap: verificando ? null : onHuella,
                  radius: 56,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.azul.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: verificando
                        ? const Padding(padding: EdgeInsets.all(34), child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.fingerprint_rounded, size: 60, color: AppColors.azul),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                error ?? 'Toca para entrar con tu huella',
                textAlign: TextAlign.center,
                style: TextStyle(color: error == null ? Paleta.gris700 : AppColors.rojo, height: 1.35),
              ),
              const Spacer(flex: 2),
              TextButton(
                // Plan B: cierra la sesión y vuelve al login con contraseña.
                onPressed: verificando ? null : () => FirebaseAuth.instance.signOut(),
                child: const Text('Entrar con mi contraseña'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tapa la app en la vista de "apps recientes" para no mostrar montos.
class _Cortina extends StatelessWidget {
  const _Cortina();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Paleta.superficie,
      child: const Center(child: _Logo()),
    );
  }
}

/// Interruptor "Entrar con huella" para la pantalla de Perfil.
class InterruptorHuella extends StatefulWidget {
  const InterruptorHuella({super.key});

  @override
  State<InterruptorHuella> createState() => _InterruptorHuellaState();
}

class _InterruptorHuellaState extends State<InterruptorHuella> {
  bool? _activa;
  bool _disponible = false;
  bool _cambiando = false;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final activa = await Huella.activa(_uid);
    final disponible = await Huella.disponible();
    if (mounted) {
      setState(() {
        _activa = activa;
        _disponible = disponible;
      });
    }
  }

  Future<void> _cambiar(bool valor) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _cambiando = true);
    String? error;
    if (valor) {
      error = await Huella.activar(_uid);
    } else {
      await Huella.desactivar(_uid);
    }
    if (!mounted) return;
    setState(() => _cambiando = false);
    await _cargar();
    messenger.mostrarAviso(SnackBar(
      content: Text(error ?? (valor ? 'Ingreso con huella activado' : 'Ingreso con huella desactivado')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_activa == null) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.azul),
      title: const Text('Entrar con huella', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _disponible ? 'Abre la app con tu huella o el PIN del celular' : 'Configura una huella o PIN en tu celular',
        style: const TextStyle(fontSize: 12.5),
      ),
      value: _activa!,
      onChanged: !_disponible || _cambiando ? null : _cambiar,
    );
  }
}

/// Logo sobre su recuadro blanco: se ve bien en modo claro y oscuro.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Image.asset('assets/logo.png', width: 140, fit: BoxFit.contain),
    );
  }
}
