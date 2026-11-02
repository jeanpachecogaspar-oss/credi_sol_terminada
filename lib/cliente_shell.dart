import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'recordatorios.dart';
import 'cliente_home_screen.dart';
import 'cliente_inicio_screen.dart';
import 'mis_prestamos_screen.dart';
import 'navegacion_cliente.dart';
import 'perfil_screen.dart';
import 'sensores_camara.dart';
import 'creditos_screen.dart';

class ClienteShell extends StatefulWidget {
  const ClienteShell({super.key});

  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> with WidgetsBindingObserver {
  static const Color azul = AppColors.azul;

  @override
  void initState() {
    super.initState();
    tabCliente.value = tabInicio;
    tabCliente.addListener(_cambio);
    ModoPrivado.ocultos.addListener(_cambio);
    WidgetsBinding.instance.addObserver(this);
    _sincronizarRecordatorios();
  }

  void _cambio() {
    if (mounted) setState(() {});
  }

  void _sincronizarRecordatorios() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) Recordatorios.sincronizar(uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sincronizarRecordatorios();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabCliente.removeListener(_cambio);
    ModoPrivado.ocultos.removeListener(_cambio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Al ocultar/mostrar montos (modo privado) se redibujan todas las pestañas.
      body: KeyedSubtree(
        key: ValueKey(ModoPrivado.ocultos.value),
        child: IndexedStack(
        index: tabCliente.value,
        children: const [
          ClienteInicioScreen(),
          CreditosScreen(),
          ClienteHomeScreen(),
          MisPrestamosScreen(),
          PerfilScreen(),
        ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabCliente.value,
        onDestinationSelected: (i) => tabCliente.value = i,
        backgroundColor: Colors.white,
        indicatorColor: azul.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: azul),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance_rounded, color: azul),
            label: 'Créditos',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded, color: azul),
            label: 'Simular',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: azul),
            label: 'Préstamos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: azul),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
