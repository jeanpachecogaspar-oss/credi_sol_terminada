import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'cronograma.dart';
import 'drive_imagen.dart';

double _num(dynamic v, double porDefecto) => (v as num?)?.toDouble() ?? porDefecto;

/// Producto financiero de CrediSol: `productosFinancieros/{id}`.
///
/// Todos usan la tasa del negocio (ConfigPrestamos.tasa, validada en firestore.rules).
/// Cada producto define para qué es, su imagen y sus límites de monto y plazo.
class ProductoFinanciero {
  final String id;
  final String nombre;
  final String categoria;
  final String descripcion;
  final String imagen; // 'assets/creditos/x.png' (incluida en la app) o enlace de Google Drive
  final double montoMin;
  final double montoMax;
  final int plazoMin;
  final int plazoMax;
  final String publico;
  final List<String> requisitos;
  final bool activo;

  const ProductoFinanciero({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.imagen,
    required this.montoMin,
    required this.montoMax,
    required this.plazoMin,
    required this.plazoMax,
    this.publico = '',
    this.requisitos = const [],
    this.activo = true,
  });

  factory ProductoFinanciero.desde(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    double limitar(double v) => v.clamp(ConfigPrestamos.montoMinimo, ConfigPrestamos.montoMaximo).toDouble();
    int limitarPlazo(int v) => v.clamp(ConfigPrestamos.plazoMinimo, ConfigPrestamos.plazoMaximo);
    final mn = limitar(_num(d['montoMin'], ConfigPrestamos.montoMinimo));
    final mx = limitar(_num(d['montoMax'], ConfigPrestamos.montoMaximo));
    final pmn = limitarPlazo((d['plazoMin'] as num?)?.toInt() ?? ConfigPrestamos.plazoMinimo);
    final pmx = limitarPlazo((d['plazoMax'] as num?)?.toInt() ?? ConfigPrestamos.plazoMaximo);
    return ProductoFinanciero(
      id: doc.id,
      nombre: (d['nombre'] ?? '').toString(),
      categoria: (d['categoria'] ?? 'Personal').toString(),
      descripcion: (d['descripcion'] ?? '').toString(),
      imagen: (d['imagen'] ?? '').toString(),
      montoMin: mn,
      montoMax: mx < mn ? mn : mx,
      plazoMin: pmn,
      plazoMax: pmx < pmn ? pmn : pmx,
      publico: (d['publico'] ?? '').toString(),
      requisitos: (d['requisitos'] as List? ?? []).map((e) => e.toString()).toList(),
      activo: d['activo'] != false,
    );
  }

  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'categoria': categoria,
        'descripcion': descripcion,
        'imagen': imagen,
        'montoMin': montoMin,
        'montoMax': montoMax,
        'plazoMin': plazoMin,
        'plazoMax': plazoMax,
        'publico': publico,
        'requisitos': requisitos.isEmpty ? requisitosPorCategoria(categoria) : requisitos,
        'activo': activo,
      };

  List<String> get requisitosVisibles => requisitos.isEmpty ? requisitosPorCategoria(categoria) : requisitos;

  /// Cuota "desde": el monto mínimo al plazo más largo.
  double get cuotaDesde => cuotaMensual(montoMin, plazoMax);
}

/// Cuota mensual con la tasa de CrediSol (sistema francés, igual que el simulador).
double cuotaMensual(double monto, int plazo) {
  if (monto <= 0 || plazo <= 0) return 0;
  final c = generarCronograma(
    monto: monto,
    tasa: ConfigPrestamos.tasa,
    tasaAnual: ConfigPrestamos.tasaAnual,
    plazo: plazo,
    fechaInicio: DateTime.now(),
  );
  return c.isEmpty ? 0 : c.first.cuota;
}

const List<String> categoriasCredito = ['Capital de trabajo', 'Activo fijo', 'Agropecuario', 'Personal', 'Especiales'];

Color colorCategoria(String c) {
  switch (c) {
    case 'Capital de trabajo':
      return AppColors.azul;
    case 'Activo fijo':
      return const Color(0xFF7E57C2);
    case 'Agropecuario':
      return AppColors.verde;
    case 'Personal':
      return const Color(0xFFEF6C00);
    default:
      return AppColors.dorado;
  }
}

List<String> requisitosPorCategoria(String c) {
  const base = ['DNI vigente', 'Recibo de luz o agua de tu domicilio', 'Selfie de verificación'];
  switch (c) {
    case 'Capital de trabajo':
    case 'Activo fijo':
      return [...base, 'Negocio con al menos 6 meses de funcionamiento', 'RUC (opcional)'];
    case 'Agropecuario':
      return [...base, 'Constancia de posesión o alquiler del terreno o crianza'];
    case 'Especiales':
      return [...base, 'Evaluación del asesor'];
    default:
      return [...base, 'Ingresos demostrables'];
  }
}

/// Imagen del producto: de la app (assets) o de Google Drive. Sobre un degradado del color de su categoría.
class ImagenProducto extends StatelessWidget {
  final ProductoFinanciero producto;
  final double padding;
  const ImagenProducto(this.producto, {super.key, this.padding = 18});

  @override
  Widget build(BuildContext context) {
    final color = colorCategoria(producto.categoria);
    final img = producto.imagen.trim();
    Widget contenido;
    if (img.startsWith('assets/')) {
      contenido = Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(img, fit: BoxFit.contain, errorBuilder: (c, e, s) => _icono(color)),
      );
    } else if (img.isNotEmpty) {
      contenido = ImagenDrive(img, ancho: 500);
    } else {
      contenido = _icono(color);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.05)],
        ),
      ),
      child: contenido,
    );
  }

  Widget _icono(Color color) => Center(child: Icon(Icons.account_balance_wallet_rounded, size: 48, color: color));
}

/// Los 40 productos financieros iniciales (el admin los carga con un botón).
/// Imágenes 3D: Fluent Emoji de Microsoft (licencia MIT, ver assets/creditos/LICENSE-fluent-emoji.txt).
const List<ProductoFinanciero> productosIniciales = [
  ProductoFinanciero(id: 'credito-01', nombre: 'Crédito Bodega', categoria: 'Capital de trabajo', imagen: 'assets/creditos/convenience_store.png', descripcion: 'Surte tu bodega y aprovecha los mejores precios de mayorista.', montoMin: 500, montoMax: 10000, plazoMin: 3, plazoMax: 24, publico: 'Bodegueros'),
  ProductoFinanciero(id: 'credito-02', nombre: 'Crédito Mercado', categoria: 'Capital de trabajo', imagen: 'assets/creditos/shopping_cart.png', descripcion: 'Para tu puesto en el mercado: mercadería, balanzas y vitrinas.', montoMin: 300, montoMax: 8000, plazoMin: 3, plazoMax: 18, publico: 'Comerciantes de mercado'),
  ProductoFinanciero(id: 'credito-03', nombre: 'Crédito Menú y Restaurante', categoria: 'Capital de trabajo', imagen: 'assets/creditos/pot_of_food.png', descripcion: 'Insumos, menaje y mejoras para tu restaurante o menú.', montoMin: 500, montoMax: 10000, plazoMin: 3, plazoMax: 24, publico: 'Restaurantes y menús'),
  ProductoFinanciero(id: 'credito-04', nombre: 'Crédito Panadería', categoria: 'Capital de trabajo', imagen: 'assets/creditos/bread.png', descripcion: 'Harina, insumos y equipos para tu panadería o pastelería.', montoMin: 500, montoMax: 10000, plazoMin: 3, plazoMax: 24, publico: 'Panaderos'),
  ProductoFinanciero(id: 'credito-05', nombre: 'Crédito Salón y Barbería', categoria: 'Capital de trabajo', imagen: 'assets/creditos/barber_pole.png', descripcion: 'Sillones, productos y equipos para tu salón de belleza.', montoMin: 500, montoMax: 8000, plazoMin: 3, plazoMax: 18, publico: 'Estilistas y barberos'),
  ProductoFinanciero(id: 'credito-06', nombre: 'Crédito Ferretería', categoria: 'Capital de trabajo', imagen: 'assets/creditos/hammer_and_wrench.png', descripcion: 'Amplía el stock de tu ferretería.', montoMin: 1000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Ferreterías'),
  ProductoFinanciero(id: 'credito-07', nombre: 'Crédito Textil', categoria: 'Capital de trabajo', imagen: 'assets/creditos/thread.png', descripcion: 'Telas e insumos para tu taller de confecciones.', montoMin: 500, montoMax: 10000, plazoMin: 3, plazoMax: 24, publico: 'Talleres textiles'),
  ProductoFinanciero(id: 'credito-08', nombre: 'Crédito Venta de Ropa', categoria: 'Capital de trabajo', imagen: 'assets/creditos/t_shirt.png', descripcion: 'Mercadería de temporada para tu tienda de ropa.', montoMin: 300, montoMax: 6000, plazoMin: 3, plazoMax: 12, publico: 'Tiendas de ropa'),
  ProductoFinanciero(id: 'credito-09', nombre: 'Crédito Juguería y Cafetería', categoria: 'Capital de trabajo', imagen: 'assets/creditos/hot_beverage.png', descripcion: 'Frutas, insumos y equipos para tu juguería o cafetería.', montoMin: 300, montoMax: 6000, plazoMin: 3, plazoMax: 18, publico: 'Juguerías y cafeterías'),
  ProductoFinanciero(id: 'credito-10', nombre: 'Crédito Campaña Comercial', categoria: 'Capital de trabajo', imagen: 'assets/creditos/shopping_bags.png', descripcion: 'Capital para campañas: Día de la Madre, Fiestas Patrias y más.', montoMin: 500, montoMax: 10000, plazoMin: 2, plazoMax: 6, publico: 'Comerciantes'),
  ProductoFinanciero(id: 'credito-11', nombre: 'Crédito Mototaxi', categoria: 'Activo fijo', imagen: 'assets/creditos/auto_rickshaw.png', descripcion: 'Compra o renueva tu mototaxi y trabaja con lo tuyo.', montoMin: 3000, montoMax: 10000, plazoMin: 12, plazoMax: 24, publico: 'Mototaxistas'),
  ProductoFinanciero(id: 'credito-12', nombre: 'Crédito Moto Delivery', categoria: 'Activo fijo', imagen: 'assets/creditos/motor_scooter.png', descripcion: 'Tu moto para hacer delivery y ganar más.', montoMin: 2000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Repartidores'),
  ProductoFinanciero(id: 'credito-13', nombre: 'Crédito Taxi', categoria: 'Activo fijo', imagen: 'assets/creditos/taxi.png', descripcion: 'Inicial, repuestos o mantenimiento de tu taxi.', montoMin: 2000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Taxistas'),
  ProductoFinanciero(id: 'credito-14', nombre: 'Crédito Maquinaria y Equipos', categoria: 'Activo fijo', imagen: 'assets/creditos/gear.png', descripcion: 'Máquinas y equipos para producir más.', montoMin: 1500, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Pequeñas industrias'),
  ProductoFinanciero(id: 'credito-15', nombre: 'Crédito Equipos de Cómputo', categoria: 'Activo fijo', imagen: 'assets/creditos/laptop.png', descripcion: 'Laptops, impresoras y sistemas para tu negocio.', montoMin: 1000, montoMax: 8000, plazoMin: 6, plazoMax: 24, publico: 'Negocios y profesionales'),
  ProductoFinanciero(id: 'credito-16', nombre: 'Crédito Cocina Industrial', categoria: 'Activo fijo', imagen: 'assets/creditos/cooking.png', descripcion: 'Cocinas, hornos y campanas para tu cocina.', montoMin: 800, montoMax: 8000, plazoMin: 6, plazoMax: 24, publico: 'Restaurantes'),
  ProductoFinanciero(id: 'credito-17', nombre: 'Crédito Máquina de Coser', categoria: 'Activo fijo', imagen: 'assets/creditos/sewing_needle.png', descripcion: 'Máquinas rectas, remalladoras y bordadoras.', montoMin: 500, montoMax: 5000, plazoMin: 3, plazoMax: 18, publico: 'Costureras y sastres'),
  ProductoFinanciero(id: 'credito-18', nombre: 'Crédito Taller Mecánico', categoria: 'Activo fijo', imagen: 'assets/creditos/wrench.png', descripcion: 'Herramientas y equipos para tu taller.', montoMin: 1000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Mecánicos'),
  ProductoFinanciero(id: 'credito-19', nombre: 'Crédito Transporte de Carga', categoria: 'Activo fijo', imagen: 'assets/creditos/delivery_truck.png', descripcion: 'Inicial o reparación de tu vehículo de carga.', montoMin: 3000, montoMax: 10000, plazoMin: 12, plazoMax: 24, publico: 'Transportistas'),
  ProductoFinanciero(id: 'credito-20', nombre: 'Crédito Siembra', categoria: 'Agropecuario', imagen: 'assets/creditos/seedling.png', descripcion: 'Semillas, abonos y mano de obra para tu campaña agrícola.', montoMin: 500, montoMax: 10000, plazoMin: 4, plazoMax: 12, publico: 'Agricultores'),
  ProductoFinanciero(id: 'credito-21', nombre: 'Crédito Ganadería', categoria: 'Agropecuario', imagen: 'assets/creditos/cow.png', descripcion: 'Compra de ganado, pastos y sanidad animal.', montoMin: 1000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Ganaderos'),
  ProductoFinanciero(id: 'credito-22', nombre: 'Crédito Avícola', categoria: 'Agropecuario', imagen: 'assets/creditos/chicken.png', descripcion: 'Pollos BB, alimento y galpones.', montoMin: 500, montoMax: 8000, plazoMin: 3, plazoMax: 12, publico: 'Criadores de aves'),
  ProductoFinanciero(id: 'credito-23', nombre: 'Crédito Riego Tecnificado', categoria: 'Agropecuario', imagen: 'assets/creditos/droplet.png', descripcion: 'Riego por goteo o aspersión para tu chacra.', montoMin: 1000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Agricultores'),
  ProductoFinanciero(id: 'credito-24', nombre: 'Crédito Pesca Artesanal', categoria: 'Agropecuario', imagen: 'assets/creditos/fishing_pole.png', descripcion: 'Redes, motor y aparejos para tu embarcación.', montoMin: 500, montoMax: 8000, plazoMin: 3, plazoMax: 18, publico: 'Pescadores'),
  ProductoFinanciero(id: 'credito-25', nombre: 'Crédito Cosecha y Acopio', categoria: 'Agropecuario', imagen: 'assets/creditos/sheaf_of_rice.png', descripcion: 'Capital para cosechar y acopiar tu producción.', montoMin: 500, montoMax: 10000, plazoMin: 3, plazoMax: 9, publico: 'Productores'),
  ProductoFinanciero(id: 'credito-26', nombre: 'Crédito Maquinaria Agrícola', categoria: 'Agropecuario', imagen: 'assets/creditos/tractor.png', descripcion: 'Motocultor, fumigadora o implementos agrícolas.', montoMin: 3000, montoMax: 10000, plazoMin: 12, plazoMax: 24, publico: 'Agricultores'),
  ProductoFinanciero(id: 'credito-27', nombre: 'Crédito Crianza de Cerdos', categoria: 'Agropecuario', imagen: 'assets/creditos/pig.png', descripcion: 'Lechones, alimento y corrales.', montoMin: 500, montoMax: 8000, plazoMin: 4, plazoMax: 12, publico: 'Criadores'),
  ProductoFinanciero(id: 'credito-28', nombre: 'Crédito Estudios', categoria: 'Personal', imagen: 'assets/creditos/graduation_cap.png', descripcion: 'Pensiones, cursos, maestrías y certificaciones.', montoMin: 500, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Estudiantes y profesionales'),
  ProductoFinanciero(id: 'credito-29', nombre: 'Crédito Campaña Escolar', categoria: 'Personal', imagen: 'assets/creditos/backpack.png', descripcion: 'Útiles, uniformes y matrícula de tus hijos.', montoMin: 300, montoMax: 3000, plazoMin: 3, plazoMax: 10, publico: 'Padres de familia'),
  ProductoFinanciero(id: 'credito-30', nombre: 'Crédito Salud', categoria: 'Personal', imagen: 'assets/creditos/hospital.png', descripcion: 'Tratamientos, operaciones y medicinas.', montoMin: 300, montoMax: 8000, plazoMin: 3, plazoMax: 18, publico: 'Familias'),
  ProductoFinanciero(id: 'credito-31', nombre: 'Crédito Mejora tu Casa', categoria: 'Personal', imagen: 'assets/creditos/house_with_garden.png', descripcion: 'Techo, pisos, baño o cocina nuevos.', montoMin: 1000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Familias'),
  ProductoFinanciero(id: 'credito-32', nombre: 'Crédito Construcción', categoria: 'Personal', imagen: 'assets/creditos/building_construction.png', descripcion: 'Avanza la construcción de tu vivienda o local.', montoMin: 2000, montoMax: 10000, plazoMin: 12, plazoMax: 24, publico: 'Familias y negocios'),
  ProductoFinanciero(id: 'credito-33', nombre: 'Crédito Campaña Navideña', categoria: 'Personal', imagen: 'assets/creditos/christmas_tree.png', descripcion: 'Juguetes, panetones y mercadería para diciembre.', montoMin: 300, montoMax: 5000, plazoMin: 2, plazoMax: 6, publico: 'Comerciantes y familias'),
  ProductoFinanciero(id: 'credito-34', nombre: 'Crédito Libre Disponibilidad', categoria: 'Personal', imagen: 'assets/creditos/money_bag.png', descripcion: 'Úsalo en lo que necesites, sin explicar el destino.', montoMin: 300, montoMax: 10000, plazoMin: 3, plazoMax: 24, publico: 'Trabajadores dependientes e independientes'),
  ProductoFinanciero(id: 'credito-35', nombre: 'Crédito Emprendedor Digital', categoria: 'Personal', imagen: 'assets/creditos/mobile_phone.png', descripcion: 'Celular, internet y publicidad para vender en redes.', montoMin: 300, montoMax: 4000, plazoMin: 3, plazoMax: 12, publico: 'Emprendedores digitales'),
  ProductoFinanciero(id: 'credito-36', nombre: 'Crédito Mujer Emprendedora', categoria: 'Especiales', imagen: 'assets/creditos/woman_office_worker.png', descripcion: 'Condiciones especiales para mujeres que emprenden.', montoMin: 300, montoMax: 8000, plazoMin: 3, plazoMax: 18, publico: 'Mujeres emprendedoras'),
  ProductoFinanciero(id: 'credito-37', nombre: 'Crédito Grupal Solidario', categoria: 'Especiales', imagen: 'assets/creditos/handshake.png', descripcion: 'Préstamo para grupos de 3 a 8 personas que se respaldan entre sí.', montoMin: 300, montoMax: 3000, plazoMin: 3, plazoMax: 12, publico: 'Grupos solidarios'),
  ProductoFinanciero(id: 'credito-38', nombre: 'Compra de Deuda', categoria: 'Especiales', imagen: 'assets/creditos/credit_card.png', descripcion: 'Junta tus deudas en una sola cuota más baja.', montoMin: 1000, montoMax: 10000, plazoMin: 6, plazoMax: 24, publico: 'Clientes con deudas en otras entidades'),
  ProductoFinanciero(id: 'credito-39', nombre: 'Línea Revolvente', categoria: 'Especiales', imagen: 'assets/creditos/repeat_button.png', descripcion: 'Usa, paga y vuelve a usar tu línea de crédito.', montoMin: 300, montoMax: 5000, plazoMin: 1, plazoMax: 12, publico: 'Clientes con buen historial'),
  ProductoFinanciero(id: 'credito-40', nombre: 'Crédito Verde', categoria: 'Especiales', imagen: 'assets/creditos/sun.png', descripcion: 'Paneles solares y equipos que ahorran energía.', montoMin: 1500, montoMax: 10000, plazoMin: 12, plazoMax: 24, publico: 'Hogares y negocios'),
];
