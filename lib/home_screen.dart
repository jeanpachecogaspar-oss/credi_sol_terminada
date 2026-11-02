import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'dashboard_screen.dart';
import 'clientes_screen.dart';
import 'solicitudes_screen.dart';
import 'cobranzas_screen.dart';
import 'admin_creditos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  void _irA(int i) => setState(() => _indice = i);

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      DashboardScreen(onIrA: _irA),
      const ClientesScreen(),
      const SolicitudesScreen(),
      const CobranzasScreen(),
      const AdminCreditosScreen(),
    ];
    return Scaffold(
      body: pantallas[_indice],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _irA,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.azul.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded, color: AppColors.azul),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded, color: AppColors.azul),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded, color: AppColors.azul),
            label: 'Solicitudes',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded, color: AppColors.azul),
            label: 'Cobranzas',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance_rounded, color: AppColors.azul),
            label: 'Créditos',
          ),
        ],
      ),
    );
  }
}