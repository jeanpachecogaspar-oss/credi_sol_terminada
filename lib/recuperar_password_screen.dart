import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  final String? emailInicial;
  const RecuperarPasswordScreen({super.key, this.emailInicial});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  late final TextEditingController _emailController;
  bool _cargando = false;
  bool _enviado = false;

  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailInicial ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _enviarCorreo() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _mensaje('Ingresa tu correo electrónico');
      return;
    }

    setState(() => _cargando = true);

    try {
      // El correo de Firebase llega en español (la plantilla se edita en
      // Authentication > Plantillas; ver docs/recuperacion_contrasena.md).
      await FirebaseAuth.instance.setLanguageCode('es');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _enviado = true);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          _mensaje('El correo no es válido');
          break;
        case 'user-not-found':
          _mensaje('No existe una cuenta con ese correo');
          break;
        case 'too-many-requests':
          _mensaje('Demasiados intentos. Inténtalo más tarde');
          break;
        case 'network-request-failed':
          _mensaje('Sin conexión a internet');
          break;
        default:
          _mensaje('No se pudo enviar el correo (${e.code}). Inténtalo de nuevo.');
      }
    } catch (e) {
      debugPrint('Recuperar contraseña: $e');
      _mensaje('Ocurrió un error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE3F0FD), Colors.white],
              ),
            ),
          ),
          Positioned(top: -60, left: -40, child: _circulo(170, azul.withValues(alpha: 0.15))),
          Positioned(top: 90, right: -50, child: _circulo(120, rojo.withValues(alpha: 0.1))),
          Positioned(bottom: -70, right: -30, child: _circulo(190, amarillo.withValues(alpha: 0.2))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(color: azul.withValues(alpha: 0.1), blurRadius: 34, offset: const Offset(0, 14)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: _enviado ? _vistaEnviado() : _vistaFormulario(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circulo(double tamano, Color color) {
    return Container(width: tamano, height: tamano, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _vistaFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: azul.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock_reset_rounded, size: 32, color: azul),
        ),
        const SizedBox(height: 18),
        const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu correo y te enviaremos un enlace para crear una nueva contraseña.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined, color: azul, size: 20),
            labelText: 'Correo electrónico',
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
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _cargando ? null : _enviarCorreo,
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
                        'Enviar enlace',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vistaEnviado() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: azul.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, size: 40, color: azul),
        ),
        const SizedBox(height: 18),
        const Text(
          '¡Correo enviado!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 10),
        Text(
          'Si ${_emailController.text.trim()} tiene una cuenta, recibirás un enlace para restablecer tu contraseña. Revisa también la carpeta de spam.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: azul,
              side: const BorderSide(color: azul),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Volver al inicio de sesión', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}