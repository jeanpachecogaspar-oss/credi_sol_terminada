import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'apis_peru.dart';
import 'datos_personales.dart';
import 'sensores_camara.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _celularController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;
  bool _acepto = false;

  /// Persona encontrada en RENIEC (APIsPERU). Si es null y la consulta falló, se escribe el nombre a mano.
  PersonaDni? _persona;
  bool _consultandoDni = false;
  String? _errorDni;
  bool _nombreManual = false;

  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Consulta el DNI en RENIEC (APIsPERU) y completa el nombre automáticamente.
  Future<void> _consultarDni() async {
    final dni = _dniController.text.trim();
    final err = validarDni(dni);
    if (err != null) {
      setState(() => _errorDni = err);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _consultandoDni = true;
      _errorDni = null;
      _persona = null;
    });
    try {
      final p = await ApisPeru.dni(dni);
      if (!mounted) return;
      setState(() {
        _persona = p;
        _nombreManual = false;
        _nombreController.text = p.nombreCompleto;
      });
    } on ApisPeruError catch (e) {
      if (!mounted) return;
      // Si el servicio no está disponible, se permite escribir el nombre.
      setState(() {
        _errorDni = e.mensaje;
        _nombreManual = true;
      });
    } finally {
      if (mounted) setState(() => _consultandoDni = false);
    }
  }

  Future<void> _registrarUsuario() async {
    final nombre = _nombreController.text.trim();
    final dni = _dniController.text.trim();
    final celular = _celularController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (validarDni(dni) != null) {
      _mensaje('Ingresa tu DNI de 8 dígitos');
      return;
    }
    if (_persona == null && !_nombreManual) {
      _mensaje('Pulsa "Validar" para confirmar tu DNI');
      return;
    }
    final errNombre = validarNombre(nombre);
    if (errNombre != null) {
      _mensaje(errNombre);
      return;
    }
    final errCel = validarCelular(celular);
    if (errCel != null) {
      _mensaje(errCel);
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _mensaje('Completa tu correo y contraseña');
      return;
    }

    if (password.length < 6) {
      _mensaje('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (!_acepto) {
      _mensaje('Debes aceptar el tratamiento de tus datos para registrarte');
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Crear cuenta (sin GPS: la ubicación solo se pide cuando hace falta)
      final credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Datos del usuario. Todo el que se registra es cliente.
      await FirebaseFirestore.instance.collection('usuarios').doc(credencial.user!.uid).set({
        'nombre': nombre,
        'dni': dni,
        'celular': celular,
        'dniVerificado': _persona != null,
        'email': email,
        'rol': 'cliente',
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _mensaje('Cuenta creada correctamente');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _mensaje('Ya existe una cuenta con ese correo');
          break;
        case 'invalid-email':
          _mensaje('El correo no es válido');
          break;
        case 'weak-password':
          _mensaje('La contraseña es muy débil');
          break;
        case 'network-request-failed':
          _mensaje('Sin conexión a internet');
          break;
        default:
          _mensaje('Error al registrar: ${e.message}');
      }
    } catch (e) {
      _mensaje('Error inesperado: $e');
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
          Positioned(top: -60, right: -40, child: _circulo(170, azul.withValues(alpha: 0.15))),
          Positioned(top: 120, left: -60, child: _circulo(120, rojo.withValues(alpha: 0.1))),
          Positioned(bottom: -70, left: -30, child: _circulo(190, amarillo.withValues(alpha: 0.2))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    Image.asset('assets/logo.png', height: 80, fit: BoxFit.contain),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(28),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(color: azul.withValues(alpha: 0.1), blurRadius: 34, offset: const Offset(0, 14)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Crear cuenta',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Solo necesitas tu DNI: tu nombre se completa solo.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 24),
                          _bloqueDni(),
                          const SizedBox(height: 14),
                          _campo(
                            controller: _celularController,
                            label: 'Celular',
                            icono: Icons.phone_iphone_rounded,
                            teclado: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _campo(
                            controller: _emailController,
                            label: 'Correo electrónico',
                            icono: Icons.email_outlined,
                            teclado: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _campo(
                            controller: _passwordController,
                            label: 'Contraseña',
                            icono: Icons.lock_outline,
                            esPassword: true,
                          ),
                          const SizedBox(height: 14),
                          _consentimiento(),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _cargando ? null : _registrarUsuario,
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
                                          'Registrarme',
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
                        ],
                      ),
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

  Widget _bloqueDni() {
    final p = _persona;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _dniController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                onChanged: (v) {
                  if (_persona != null || _errorDni != null) {
                    setState(() {
                      _persona = null;
                      _errorDni = null;
                    });
                  }
                  if (v.trim().length == 8) _consultarDni();
                },
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'DNI',
                  errorText: _errorDni,
                  errorMaxLines: 3,
                  prefixIcon: const Icon(Icons.badge_outlined, color: azul, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Escanear DNI con la cámara',
                    icon: const Icon(Icons.document_scanner_rounded, color: azul),
                    onPressed: () async {
                      final dni = await leerDniConCamara(context);
                      if (dni == null || !mounted) return;
                      _dniController.text = dni;
                      _consultarDni();
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _consultandoDni ? null : _consultarDni,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _consultandoDni
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Validar'),
              ),
            ),
          ],
        ),
        if (p != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E9E6B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2E9E6B).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF2E9E6B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Validado con RENIEC', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_nombreManual) ...[
          const SizedBox(height: 14),
          _campo(
            controller: _nombreController,
            label: 'Nombres y apellidos',
            icono: Icons.person_outline,
            capitalizar: TextCapitalization.words,
          ),
        ],
      ],
    );
  }

  Widget _consentimiento() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _acepto = !_acepto),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acepto,
            activeColor: azul,
            onChanged: (v) => setState(() => _acepto = v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Acepto el tratamiento de mis datos (Ley 29733). CrediSol NO rastrea mi ubicación: '
                'solo la usa cuando yo lo pido (verificar mi recibo, ubicar mi negocio o buscar puntos de pago).',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.35),
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

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    TextInputType? teclado,
    TextCapitalization capitalizar = TextCapitalization.none,
    bool esPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      textCapitalization: capitalizar,
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