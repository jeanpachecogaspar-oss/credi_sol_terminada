import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'datos_personales.dart';
import 'errores.dart';
import 'formato.dart';
import 'historial_pagos_screen.dart';
import 'soporte.dart';
import 'ui_comun.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return mensajeVacio(Icons.error_outline_rounded, 'No se pudo cargar tu perfil', mensajeError(snap.error!));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() ?? {};
          final nombre = (d['nombre'] ?? '').toString();
          final nac = aFecha(d['fechaNacimiento']);
          String t(String c) => (d[c] ?? '').toString().isEmpty ? '—' : d[c].toString();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.azul.withValues(alpha: 0.12),
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre.isEmpty ? 'Sin nombre' : nombre,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        Text(user.email ?? '', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              tarjetaBlanca(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Datos personales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditarPerfilScreen(datos: d)),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Editar'),
                        ),
                      ],
                    ),
                    filaDato('DNI', t('dni')),
                    filaDato('Nacimiento', nac == null ? '—' : fmtFecha(nac)),
                    filaDato('Celular', t('celular')),
                    filaDato('Dirección', t('direccion')),
                    filaDato('Distrito', t('distrito')),
                    filaDato('Ocupación', t('ocupacion')),
                    filaDato('Ingreso mensual', d['ingresoMensual'] is num ? fmtMoney(aNum(d['ingresoMensual'])) : '—'),
                    if (!perfilCompleto(d))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tus datos se completan al enviar tu primera solicitud.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              tarjetaBlanca(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _opcion(
                      Icons.receipt_long_rounded,
                      'Historial de pagos',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialPagosScreen())),
                    ),
                    _opcion(Icons.lock_reset_rounded, 'Cambiar contraseña', () => _cambiarContrasena(context)),
                    _opcion(Icons.privacy_tip_outlined, 'Privacidad y mis datos', () => _privacidad(context, d)),
                    _opcion(Icons.chat_rounded, 'Soporte por WhatsApp', () => abrirWhatsApp(context)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await confirmar(context, 'Cerrar sesión', '¿Quieres cerrar tu sesión?', 'Cerrar sesión');
                  if (ok) await FirebaseAuth.instance.signOut();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rojo,
                  side: const BorderSide(color: AppColors.rojo),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _opcion(IconData icono, String texto, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icono, color: AppColors.azul),
      title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _cambiarContrasena(BuildContext context) {
    showDialog(context: context, builder: (_) => const _CambiarContrasenaDialog());
  }

  void _privacidad(BuildContext context, Map<String, dynamic> d) {
    final fecha = aFecha(d['fechaConsentimiento']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Privacidad y mis datos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                d['consentimientoDatos'] == true && fecha != null
                    ? 'Autorizaste el tratamiento de tus datos el ${fechaHora(fecha)}.'
                    : 'Aún no has autorizado el tratamiento de tus datos. Se solicita al enviar una solicitud.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(textoConsentimiento(), style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
              const SizedBox(height: 10),
              Text(
                'Ubicación: solo se usa mientras la app está abierta. Nunca accedemos a tus contactos, mensajes ni galería.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= EDITAR PERFIL =======================

class EditarPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> datos;
  const EditarPerfilScreen({super.key, required this.datos});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _celular;
  late final TextEditingController _direccion;
  late final TextEditingController _distrito;
  late final TextEditingController _ocupacion;
  late final TextEditingController _ingreso;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    String v(String c) => (widget.datos[c] ?? '').toString();
    _nombre = TextEditingController(text: v('nombre'));
    _celular = TextEditingController(text: v('celular'));
    _direccion = TextEditingController(text: v('direccion'));
    _distrito = TextEditingController(text: v('distrito'));
    _ocupacion = TextEditingController(text: v('ocupacion'));
    _ingreso = TextEditingController(
      text: widget.datos['ingresoMensual'] is num ? (widget.datos['ingresoMensual'] as num).toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    for (final c in [_nombre, _celular, _direccion, _distrito, _ocupacion, _ingreso]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'nombre': _nombre.text.trim(),
        'celular': _celular.text.trim(),
        'direccion': _direccion.text.trim(),
        'distrito': _distrito.text.trim(),
        'ocupacion': _ocupacion.text.trim(),
        'ingresoMensual': double.parse(_ingreso.text.trim().replaceAll(',', '.')),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Datos actualizados')));
    } catch (e) {
      debugPrint('Error al guardar perfil: $e');
      messenger.showSnackBar(SnackBar(content: Text('No se pudieron guardar. ${mensajeError(e)}')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dni = (widget.datos['dni'] ?? '').toString();
    final nac = aFecha(widget.datos['fechaNacimiento']);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar datos')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (dni.isNotEmpty || nac != null) ...[
              tarjetaBlanca(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dni.isNotEmpty) filaDato('DNI', dni),
                    if (nac != null) filaDato('Nacimiento', fmtFecha(nac)),
                    const SizedBox(height: 4),
                    Text(
                      'Por seguridad, el DNI y la fecha de nacimiento no se pueden cambiar desde la app. '
                      'Si hay un error, escríbenos por WhatsApp.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _campo(_nombre, 'Nombres y apellidos', Icons.person_outline_rounded, validarNombre,
                capitalizacion: TextCapitalization.words),
            _campo(_celular, 'Celular', Icons.phone_android_rounded, validarCelular,
                teclado: TextInputType.number, soloDigitos: true, maxLength: 9),
            _campo(_direccion, 'Dirección', Icons.home_outlined, (v) => validarTexto(v, 'dirección', max: 200)),
            _campo(_distrito, 'Distrito', Icons.location_city_rounded, (v) => validarTexto(v, 'distrito')),
            _campo(_ocupacion, 'Ocupación', Icons.work_outline_rounded, (v) => validarTexto(v, 'ocupación')),
            _campo(_ingreso, 'Ingreso mensual aproximado', Icons.payments_outlined, validarIngreso,
                teclado: const TextInputType.numberWithOptions(decimal: true), prefijo: 'S/ '),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController c,
    String label,
    IconData icono,
    String? Function(String?) validator, {
    TextInputType teclado = TextInputType.text,
    TextCapitalization capitalizacion = TextCapitalization.sentences,
    bool soloDigitos = false,
    int? maxLength,
    String? prefijo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        validator: validator,
        keyboardType: teclado,
        textCapitalization: capitalizacion,
        maxLength: maxLength,
        inputFormatters: soloDigitos ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefijo,
          counterText: '',
          prefixIcon: Icon(icono, color: AppColors.azul, size: 20),
        ),
      ),
    );
  }
}

// ======================= CAMBIAR CONTRASEÑA =======================

class _CambiarContrasenaDialog extends StatefulWidget {
  const _CambiarContrasenaDialog();

  @override
  State<_CambiarContrasenaDialog> createState() => _CambiarContrasenaDialogState();
}

class _CambiarContrasenaDialogState extends State<_CambiarContrasenaDialog> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    final actual = _actual.text;
    final nueva = _nueva.text;
    if (actual.isEmpty) return setState(() => _error = 'Ingresa tu contraseña actual');
    if (nueva.length < 6) return setState(() => _error = 'La nueva contraseña debe tener al menos 6 caracteres');
    if (nueva != _confirmar.text) return setState(() => _error = 'Las contraseñas nuevas no coinciden');
    if (nueva == actual) return setState(() => _error = 'La nueva contraseña debe ser distinta a la actual');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    setState(() {
      _cargando = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // Firebase exige volver a autenticarse antes de cambiar la contraseña.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: actual),
      );
      await user.updatePassword(nueva);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'wrong-password' || 'invalid-credential' => 'La contraseña actual no es correcta',
            'weak-password' => 'La nueva contraseña es muy débil',
            'too-many-requests' => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
            'network-request-failed' => 'Sin conexión a internet',
            _ => 'No se pudo cambiar la contraseña (${e.code})',
          });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: Icon(_ocultar ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _ocultar = !_ocultar),
          ),
        );

    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _actual, obscureText: _ocultar, decoration: deco('Contraseña actual')),
            const SizedBox(height: 12),
            TextField(controller: _nueva, obscureText: _ocultar, decoration: deco('Nueva contraseña')),
            const SizedBox(height: 12),
            TextField(controller: _confirmar, obscureText: _ocultar, decoration: deco('Repite la nueva contraseña')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.rojo, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cargando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _cargando ? null : _cambiar,
          child: _cargando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Cambiar'),
        ),
      ],
    );
  }
}
