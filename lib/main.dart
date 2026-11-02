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
  await Future.wait([Firebase.initializeApp(), RolCache.cargar()]);
  // Los recordatorios se preparan en segundo plano: no retrasan el arranque.
  Recordatorios.iniciar();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrediSol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}