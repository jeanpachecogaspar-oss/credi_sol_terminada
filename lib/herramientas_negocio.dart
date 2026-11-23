import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'banca_comunal_screen.dart';
import 'cuotas_temporada_screen.dart';
import 'libreta_ventas_screen.dart';
import 'planificador_inversion_screen.dart';
import 'sensores_screen.dart';

/// Sección del Inicio con las 4 ideas disruptivas y el acceso a los sensores.
class HerramientasNegocio extends StatelessWidget {
  const HerramientasNegocio({super.key});

  @override
  Widget build(BuildContext context) {
    void ir(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Herramientas para tu negocio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _Herramienta(
                icono: Icons.shopping_basket_rounded,
                titulo: 'Planifica tu inversión',
                texto: 'Arrastra tu mercadería y mira si te conviene',
                color: AppColors.azul,
                onTap: () => ir(const PlanificadorInversionScreen()),
              ),
              _Herramienta(
                icono: Icons.bar_chart_rounded,
                titulo: 'Cuotas por temporada',
                texto: 'Paga más cuando vendes más',
                color: AppColors.verde,
                onTap: () => ir(const CuotasTemporadaScreen()),
              ),
              _Herramienta(
                icono: Icons.menu_book_rounded,
                titulo: 'Libreta de ventas',
                texto: 'Anota tus ventas y conoce cuánto pedir',
                color: const Color(0xFFEF6C00),
                onTap: () => ir(const LibretaVentasScreen()),
              ),
              _Herramienta(
                icono: Icons.diversity_3_rounded,
                titulo: 'Banca comunal',
                texto: 'Pide en grupo con tus socios',
                color: const Color(0xFF7E57C2),
                onTap: () => ir(const BancaComunalScreen()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Paleta.superficie,
            borderRadius: BorderRadius.circular(20),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.ambar.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sensors_rounded, color: AppColors.ambar),
              ),
              title: const Text('Sensores del celular', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Acelerómetro, giroscopio y magnetómetro en vivo', style: TextStyle(fontSize: 12.5)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => ir(const SensoresScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Herramienta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final Color color;
  final VoidCallback onTap;
  const _Herramienta({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paleta.superficie,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: color),
              ),
              const Spacer(),
              Text(titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Paleta.gris600, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}
