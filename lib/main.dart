import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_theme.dart';
import 'recordatorios.dart';
import 'auth_gate.dart';
import 'rol_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase y el rol guardado se cargan en paralelo mientras se ve el splash nativo.
  await Future.wait([Firebase.initializeApp(), RolCache.cargar(), ControlTema.cargar()]);
  // Los recordatorios se preparan en segundo plano: no retrasan el arranque.
  Recordatorios.iniciar();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Paleta.oscuro = ControlTema.esOscuro(ControlTema.modo.value);
    ControlTema.modo.addListener(_actualizar);
  }

  @override
  void dispose() {
    ControlTema.modo.removeListener(_actualizar);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // El usuario cambió el modo del celular (aplica si eligió "Según el celular").
  @override
  void didChangePlatformBrightness() => _actualizar();

  void _actualizar() {
    final oscuro = ControlTema.esOscuro(ControlTema.modo.value);
    final cambio = oscuro != Paleta.oscuro;
    Paleta.oscuro = oscuro;
    setState(() {});
    if (cambio) WidgetsBinding.instance.addPostFrameCallback((_) => ControlTema.redibujarTodo());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrediSol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: ControlTema.modo.value,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}
