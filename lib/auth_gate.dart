import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'errores.dart';
import 'login_screen.dart';
import 'recordatorios.dart';
import 'rol_cache.dart';
import 'seleccion_creditos.dart';
import 'sensores_camara.dart';
import 'home_screen.dart';
import 'cliente_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // La sesión guardada se conoce al instante: no se muestra "cargando".
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnap) {
        final Widget pantalla;
        if (authSnap.data == null) {
          // Sin sesión: no deben quedar recordatorios de otro usuario en el celular.
          Recordatorios.cancelarTodo();
          SeleccionCreditos.instancia.olvidarUsuario();
          ModoPrivado.reiniciar();
          pantalla = const LoginScreen();
        } else {
          final uid = authSnap.data!.uid;
          pantalla = _RolGate(key: ValueKey(uid), uid: uid);
        }
        // Transición suave entre login, carga y la app.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: pantalla,
        );
      },
    );
  }
}

/// Lee `usuarios/{uid}` y decide la pantalla según el rol.
/// Si el perfil no se puede leer o no existe, NO se asume ningún rol:
/// se muestra un error con opción de reintentar o cerrar sesión.
class _RolGate extends StatefulWidget {
  final String uid;
  const _RolGate({super.key, required this.uid});

  @override
  State<_RolGate> createState() => _RolGateState();
}

class _RolGateState extends State<_RolGate> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _crearStream();
  }

  void _crearStream() {
    // includeMetadataChanges: también avisa cuando llega la respuesta del servidor
    // después de una lectura de la caché local.
    _stream = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.uid)
        .snapshots(includeMetadataChanges: true);
  }

  void _reintentar() => setState(_crearStream);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, docSnap) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _pantalla(docSnap),
      ),
    );
  }

  /// Pantalla de cada rol. Sin rastreo: el GPS solo se usa cuando el cliente lo necesita.
  Widget? _pantallaRol(String? rol) {
    if (rol == 'admin') return const HomeScreen();
    if (rol == 'cliente') return const ClienteShell();
    return null;
  }

  Widget _pantalla(AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> docSnap) {
    if (docSnap.hasError) {
      debugPrint('AuthGate: error leyendo el perfil ${widget.uid}: ${docSnap.error}');
      return _ErrorPerfil(
        titulo: 'No pudimos cargar tu perfil',
        texto: mensajeError(docSnap.error!),
        onReintentar: _reintentar,
      );
    }
    // Mientras llega el perfil, se usa el rol guardado en el celular (entrada instantánea).
    if (!docSnap.hasData) return _pantallaRol(RolCache.rolDe(widget.uid)) ?? const _Cargando();

    final snap = docSnap.data!;
    final datos = snap.data();
    if (datos == null) {
      // Un "no existe" leído de la caché del celular no es definitivo:
      // se espera la respuesta del servidor.
      if (snap.metadata.isFromCache) {
        return _pantallaRol(RolCache.rolDe(widget.uid)) ??
            const _Cargando(texto: 'Conectando con el servidor…');
      }
      // Justo después del registro el perfil tarda un instante en escribirse.
      final creado = FirebaseAuth.instance.currentUser?.metadata.creationTime;
      if (creado != null && DateTime.now().difference(creado).inSeconds < 30) {
        return const _Cargando();
      }
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      return _ErrorPerfil(
        titulo: 'Perfil incompleto',
        texto: 'La cuenta $email no tiene un perfil registrado '
            '(ID: ${widget.uid}). Contacta al administrador.',
        onReintentar: _reintentar,
      );
    }

    final rol = (datos['rol'] ?? '').toString();
    debugPrint('AuthGate -> uid: ${widget.uid} | rol: "$rol"');

    final pantalla = _pantallaRol(rol);
    if (pantalla != null) {
      RolCache.guardar(widget.uid, rol);
      return pantalla;
    }

    return _ErrorPerfil(
      titulo: 'Rol no válido',
      texto: 'Tu perfil tiene un rol no reconocido ("$rol"). Contacta al administrador.',
      onReintentar: _reintentar,
    );
  }
}

class _ErrorPerfil extends StatelessWidget {
  final String titulo;
  final String texto;
  final VoidCallback onReintentar;
  const _ErrorPerfil({required this.titulo, required this.texto, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.rojo.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_off_outlined, size: 52, color: AppColors.rojo),
              ),
              const SizedBox(height: 24),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onReintentar, child: const Text('Reintentar')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  final String? texto;
  const _Cargando({this.texto});

  @override
  Widget build(BuildContext context) {
    if (texto == null) {
      // Misma composición que el splash, para que no se note el cambio de pantalla.
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', width: 150, fit: BoxFit.contain),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(texto!, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              'Verifica tu conexión a internet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
