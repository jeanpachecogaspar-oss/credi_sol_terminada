import 'dart:math' as math;
import 'config_prestamos.dart';
import 'cronograma.dart';

/// Cálculos de las 5 ideas disruptivas (sin Flutter, para poder probarlos con `flutter test`).

double _r(double v) => (v * 100).roundToDouble() / 100;

/// Tasa efectiva mensual del negocio (decimal).
double get tasaMensualNegocio => tasaMensual(ConfigPrestamos.tasa, ConfigPrestamos.tasaAnual);

// ======================= 1. CUOTAS POR TEMPORADA =======================

/// Tipo de mes según las ventas del negocio.
enum Temporada { baja, normal, alta }

extension TemporadaInfo on Temporada {
  /// Cuánto paga ese mes respecto de la cuota normal.
  double get factor => switch (this) { Temporada.baja => 0.5, Temporada.normal => 1.0, Temporada.alta => 1.6 };
  String get nombre => switch (this) { Temporada.baja => 'Baja', Temporada.normal => 'Normal', Temporada.alta => 'Alta' };
  Temporada get siguiente => Temporada.values[(index + 1) % Temporada.values.length];
}

/// Cronograma con cuotas que suben en los meses de temporada alta y bajan en los de temporada baja.
/// La cuota base C cumple: monto = Σ factor_k · C / (1+i)^k, así el valor presente es el mismo
/// que el de un préstamo con cuota fija y la tasa no cambia.
List<CuotaCalc> cronogramaPorTemporada({
  required double monto,
  required List<Temporada> meses,
  required DateTime fechaInicio,
  double? tasaMes,
}) {
  final i = tasaMes ?? tasaMensualNegocio;
  if (monto <= 0 || meses.isEmpty) return const [];
  var suma = 0.0;
  for (var k = 0; k < meses.length; k++) {
    suma += meses[k].factor / math.pow(1 + i, k + 1);
  }
  final base = monto / suma;
  final lista = <CuotaCalc>[];
  var saldo = monto;
  for (var k = 0; k < meses.length; k++) {
    final n = k + 1;
    final interes = _r(saldo * i);
    final esUltima = n == meses.length;
    var cuota = _r(base * meses[k].factor);
    var amort = _r(cuota - interes);
    if (esUltima) {
      amort = _r(saldo);
      cuota = _r(amort + interes);
    }
    saldo = esUltima ? 0.0 : _r(saldo - amort);
    lista.add(CuotaCalc(n, sumarMeses(fechaInicio, n), cuota, interes, amort, saldo));
  }
  return lista;
}

/// Temporadas sugeridas para un rubro, mes a mes desde [inicio] (1 = enero).
Temporada temporadaSugerida(String rubro, int mes) {
  switch (rubro) {
    case 'Bodega / abarrotes':
      return mes == 12 || mes == 7 ? Temporada.alta : (mes == 2 ? Temporada.baja : Temporada.normal);
    case 'Agricultura':
      // Cosecha en Junín: abril–julio. Siembra (más gasto, menos ingreso): setiembre–noviembre.
      if (mes >= 4 && mes <= 7) return Temporada.alta;
      if (mes >= 9 && mes <= 11) return Temporada.baja;
      return Temporada.normal;
    case 'Útiles y regalos':
      if (mes == 3 || mes == 12) return Temporada.alta;
      if (mes == 1 || mes == 8) return Temporada.baja;
      return Temporada.normal;
    case 'Ropa y calzado':
      if (mes == 12 || mes == 7 || mes == 5) return Temporada.alta;
      if (mes == 2) return Temporada.baja;
      return Temporada.normal;
    default:
      return Temporada.normal;
  }
}

const rubrosTemporada = ['Bodega / abarrotes', 'Agricultura', 'Útiles y regalos', 'Ropa y calzado', 'Otro'];

// ======================= 2. LIBRETA DE VENTAS =======================

class RegistroVenta {
  final DateTime fecha;
  final double ventas;
  final double gastos;
  const RegistroVenta(this.fecha, this.ventas, this.gastos);
  double get ganancia => ventas - gastos;

  Map<String, dynamic> aMapa() => {'f': fecha.millisecondsSinceEpoch, 'v': ventas, 'g': gastos};
  factory RegistroVenta.desde(Map<String, dynamic> m) => RegistroVenta(
        DateTime.fromMillisecondsSinceEpoch((m['f'] as num).toInt()),
        (m['v'] as num).toDouble(),
        (m['g'] as num).toDouble(),
      );
}

class AnalisisVentas {
  final int dias;
  final double ventaPromedio;
  final double gananciaPromedio;
  final double gananciaMensual;
  final double cuotaMaxima;
  final double montoSugerido;
  final int plazo;
  const AnalisisVentas({
    required this.dias,
    required this.ventaPromedio,
    required this.gananciaPromedio,
    required this.gananciaMensual,
    required this.cuotaMaxima,
    required this.montoSugerido,
    required this.plazo,
  });
}

/// Días de trabajo al mes y parte de la ganancia que se puede destinar a la cuota.
const int diasLaborablesMes = 26;
const double porcentajeCuota = 0.35;

/// Analiza la libreta: ganancia promedio diaria × 26 días = ganancia mensual; la cuota no debe pasar
/// del 35 % de esa ganancia; el monto sugerido es el valor presente de esa cuota al plazo elegido.
AnalisisVentas analizarVentas(List<RegistroVenta> registros, {int plazo = 12, double? tasaMes}) {
  if (registros.isEmpty) {
    return AnalisisVentas(
        dias: 0, ventaPromedio: 0, gananciaPromedio: 0, gananciaMensual: 0, cuotaMaxima: 0, montoSugerido: 0, plazo: plazo);
  }
  final i = tasaMes ?? tasaMensualNegocio;
  final n = registros.length;
  final venta = registros.fold(0.0, (s, r) => s + r.ventas) / n;
  final ganancia = registros.fold(0.0, (s, r) => s + r.ganancia) / n;
  final mensual = math.max(0.0, ganancia * diasLaborablesMes);
  final cuota = mensual * porcentajeCuota;
  var monto = i == 0 ? cuota * plazo : cuota * (1 - math.pow(1 + i, -plazo)) / i;
  monto = (monto / 50).floor() * 50.0; // múltiplos de S/ 50
  if (monto < ConfigPrestamos.montoMinimo) monto = 0;
  if (monto > ConfigPrestamos.montoMaximo) monto = ConfigPrestamos.montoMaximo;
  return AnalisisVentas(
    dias: n,
    ventaPromedio: _r(venta),
    gananciaPromedio: _r(ganancia),
    gananciaMensual: _r(mensual),
    cuotaMaxima: _r(cuota),
    montoSugerido: monto,
    plazo: plazo,
  );
}

// ======================= 3. PLANIFICADOR DE INVERSIÓN =======================

/// Insumo o mercadería que el emprendedor arrastra a su "canasta de inversión".
class Insumo {
  final String id;
  final String nombre;
  final String emoji;
  final String unidad;
  final double costo; // costo por unidad
  final double precioVenta; // precio de venta por unidad
  const Insumo(this.id, this.nombre, this.emoji, this.unidad, this.costo, this.precioVenta);
  double get margen => precioVenta - costo;
}

class ResultadoInversion {
  final double inversion;
  final double ventaEsperada;
  final double gananciaPorRotacion;
  final double gananciaMensual;
  final double montoPrestamo;
  final double cuota;
  final double gananciaNeta;
  final int mesesRecupero; // meses para recuperar la inversión con la ganancia neta (0 = no se recupera)
  const ResultadoInversion({
    required this.inversion,
    required this.ventaEsperada,
    required this.gananciaPorRotacion,
    required this.gananciaMensual,
    required this.montoPrestamo,
    required this.cuota,
    required this.gananciaNeta,
    required this.mesesRecupero,
  });

  /// "Conviene" si la ganancia mensual cubre la cuota con al menos 30 % de holgura.
  bool get conviene => cuota > 0 && gananciaMensual >= cuota * 1.3;
  bool get ajustado => cuota > 0 && gananciaMensual >= cuota && !conviene;
}

ResultadoInversion evaluarInversion({
  required Map<Insumo, int> canasta,
  required double aportePropio,
  required int rotacionesMes,
  required int plazo,
}) {
  var inversion = 0.0, venta = 0.0;
  canasta.forEach((ins, cant) {
    inversion += ins.costo * cant;
    venta += ins.precioVenta * cant;
  });
  final porRotacion = venta - inversion;
  final mensual = porRotacion * rotacionesMes;
  var prestamo = math.max(0.0, inversion - aportePropio);
  if (prestamo > 0 && prestamo < ConfigPrestamos.montoMinimo) prestamo = ConfigPrestamos.montoMinimo;
  prestamo = math.min(prestamo, ConfigPrestamos.montoMaximo);
  var cuota = 0.0;
  if (prestamo > 0) {
    final c = generarCronograma(
      monto: prestamo,
      tasa: ConfigPrestamos.tasa,
      tasaAnual: ConfigPrestamos.tasaAnual,
      plazo: plazo,
      fechaInicio: DateTime(2026, 1, 1),
    );
    cuota = c.first.cuota;
  }
  final neta = mensual - cuota;
  final meses = neta > 0 ? (inversion / neta).ceil() : 0;
  return ResultadoInversion(
    inversion: _r(inversion),
    ventaEsperada: _r(venta),
    gananciaPorRotacion: _r(porRotacion),
    gananciaMensual: _r(mensual),
    montoPrestamo: _r(prestamo),
    cuota: _r(cuota),
    gananciaNeta: _r(neta),
    mesesRecupero: meses,
  );
}

/// Catálogo de insumos por rubro (precios referenciales de Huancayo).
const Map<String, List<Insumo>> insumosPorRubro = {
  'Pollería / restaurante': [
    Insumo('pollo', 'Pollo entero', '🍗', 'unidad', 22, 48),
    Insumo('papa', 'Papa amarilla (saco 50 kg)', '🥔', 'saco', 70, 120),
    Insumo('arroz', 'Arroz (saco 50 kg)', '🍚', 'saco', 160, 230),
    Insumo('aceite', 'Aceite (caja 12 L)', '🫒', 'caja', 95, 150),
    Insumo('gaseosa', 'Gaseosas (paquete 6)', '🥤', 'paquete', 24, 42),
    Insumo('balon', 'Balón de gas (gasto)', '🔥', 'unidad', 45, 0),
  ],
  'Bodega': [
    Insumo('azucar', 'Azúcar (saco 50 kg)', '🧂', 'saco', 175, 215),
    Insumo('leche', 'Leche (caja 24 latas)', '🥛', 'caja', 85, 105),
    Insumo('fideos', 'Fideos (fardo 20 kg)', '🍝', 'fardo', 70, 92),
    Insumo('menestras', 'Menestras (saco 25 kg)', '🫘', 'saco', 140, 180),
    Insumo('galletas', 'Galletas (caja)', '🍪', 'caja', 30, 42),
    Insumo('detergente', 'Detergente (caja)', '🧴', 'caja', 60, 78),
  ],
  'Bazar / ropa': [
    Insumo('polos', 'Polos (docena)', '👕', 'docena', 120, 216),
    Insumo('casacas', 'Casacas (media docena)', '🧥', 'media doc.', 210, 360),
    Insumo('zapatillas', 'Zapatillas (par)', '👟', 'par', 65, 110),
    Insumo('mochilas', 'Mochilas (docena)', '🎒', 'docena', 180, 300),
    Insumo('medias', 'Medias (docena)', '🧦', 'docena', 25, 48),
  ],
  'Agro / crianza': [
    // En agro, el "precio de venta" es lo que aporta a la cosecha o a la venta de animales.
    Insumo('semilla', 'Semilla de papa (saco)', '🌱', 'saco', 90, 300),
    Insumo('abono', 'Abono (saco 50 kg)', '🪴', 'saco', 85, 170),
    Insumo('cuyes', 'Cuyes para engorde', '🐹', 'unidad', 12, 30),
    Insumo('truchas', 'Alevinos de trucha (millar)', '🐟', 'millar', 180, 600),
    Insumo('alimento', 'Alimento balanceado (saco)', '🌾', 'saco', 95, 160),
  ],
};

// ======================= 4. BANCA COMUNAL =======================

/// Máximo y mínimo de integrantes de un grupo solidario.
const int minIntegrantesGrupo = 3;
const int maxIntegrantesGrupo = 5;

/// Cuota mensual de un integrante para su parte del préstamo grupal.
double cuotaIntegrante(double monto, int plazo) {
  if (monto <= 0 || plazo <= 0) return 0;
  return generarCronograma(
    monto: monto,
    tasa: ConfigPrestamos.tasa,
    tasaAnual: ConfigPrestamos.tasaAnual,
    plazo: plazo,
    fechaInicio: DateTime(2026, 1, 1),
  ).first.cuota;
}

/// Código de 6 caracteres fácil de dictar (sin 0/O ni 1/I).
String generarCodigoGrupo([math.Random? azar]) {
  const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = azar ?? math.Random.secure();
  return List.generate(6, (_) => letras[r.nextInt(letras.length)]).join();
}

// ======================= 5. INVENTARIO CON CÁMARA =======================

/// Precio referencial de una mercadería que la IA del celular puede reconocer en una foto.
class ReferenciaInventario {
  final String nombre;
  final String emoji;
  final double precio; // valor de costo por unidad (referencial, Huancayo)
  const ReferenciaInventario(this.nombre, this.emoji, this.precio);
}

/// Etiquetas del modelo base de Google ML Kit (en inglés) → mercadería con precio referencial.
/// Se busca por palabra clave, así "Sneakers" o "Running shoe" caen en "Calzado".
const Map<String, ReferenciaInventario> referenciasInventario = {
  'shoe': ReferenciaInventario('Calzado (par)', '👟', 45),
  'sneaker': ReferenciaInventario('Calzado (par)', '👟', 45),
  'boot': ReferenciaInventario('Calzado (par)', '👟', 45),
  'jacket': ReferenciaInventario('Casaca', '🧥', 60),
  'jeans': ReferenciaInventario('Pantalón', '👖', 35),
  'denim': ReferenciaInventario('Pantalón', '👖', 35),
  'shirt': ReferenciaInventario('Polo o camisa', '👕', 18),
  'jersey': ReferenciaInventario('Polo o camisa', '👕', 18),
  'clothing': ReferenciaInventario('Prenda de vestir', '👕', 25),
  'dress': ReferenciaInventario('Vestido', '👗', 40),
  'hat': ReferenciaInventario('Gorro o sombrero', '🧢', 15),
  'cap': ReferenciaInventario('Gorro o sombrero', '🧢', 15),
  'bag': ReferenciaInventario('Bolso o mochila', '👜', 35),
  'glasses': ReferenciaInventario('Lentes', '🕶️', 20),
  'bread': ReferenciaInventario('Pan y panificados', '🍞', 0.4),
  'cake': ReferenciaInventario('Torta o queque', '🎂', 35),
  'cookie': ReferenciaInventario('Galletas (paquete)', '🍪', 1.5),
  'candy': ReferenciaInventario('Golosinas (paquete)', '🍬', 4),
  'fruit': ReferenciaInventario('Fruta (kg)', '🍎', 4),
  'vegetable': ReferenciaInventario('Verduras (kg)', '🥕', 3),
  'egg': ReferenciaInventario('Huevos (jaba)', '🥚', 14),
  'bottle': ReferenciaInventario('Bebida embotellada', '🥤', 2.5),
  'drink': ReferenciaInventario('Bebida embotellada', '🥤', 2.5),
  'juice': ReferenciaInventario('Jugo o néctar', '🧃', 3),
  'food': ReferenciaInventario('Abarrotes', '🛒', 5),
  'toy': ReferenciaInventario('Juguete', '🧸', 20),
  'flower': ReferenciaInventario('Flores y plantas', '💐', 8),
  'plant': ReferenciaInventario('Flores y plantas', '💐', 8),
  'mobile phone': ReferenciaInventario('Celular', '📱', 450),
  'computer': ReferenciaInventario('Computadora', '💻', 1500),
  'television': ReferenciaInventario('Televisor', '📺', 900),
  'tool': ReferenciaInventario('Herramienta', '🛠️', 30),
  'chair': ReferenciaInventario('Silla', '🪑', 60),
  'furniture': ReferenciaInventario('Mueble', '🛋️', 250),
  'musical instrument': ReferenciaInventario('Instrumento musical', '🎸', 300),
  'guitar': ReferenciaInventario('Instrumento musical', '🎸', 300),
  'jewelry': ReferenciaInventario('Joyas y bisutería', '💍', 30),
  'paper': ReferenciaInventario('Útiles de escritorio', '📒', 3),
  'cosmetics': ReferenciaInventario('Cosméticos', '💄', 15),
};

/// Busca la mercadería que corresponde a una etiqueta de ML Kit; null si no es mercadería.
ReferenciaInventario? referenciaPara(String etiqueta) {
  final e = etiqueta.toLowerCase();
  for (final k in referenciasInventario.entries) {
    if (e.contains(k.key)) return k.value;
  }
  return null;
}

/// Mercadería contada en el inventario (detectada por la cámara o agregada a mano).
class ArticuloInventario {
  final String nombre;
  final String emoji;
  double precio;
  int cantidad;
  final bool detectado; // true si lo reconoció la IA
  ArticuloInventario({
    required this.nombre,
    required this.emoji,
    required this.precio,
    this.cantidad = 1,
    this.detectado = true,
  });
  double get subtotal => precio * cantidad;
}

/// Une las etiquetas de una foto con el inventario: si la mercadería ya estaba no la repite.
/// Devuelve cuántas mercaderías nuevas agregó.
int agregarEtiquetas(List<ArticuloInventario> inventario, Iterable<String> etiquetas) {
  var nuevas = 0;
  for (final et in etiquetas) {
    final ref = referenciaPara(et);
    if (ref == null || inventario.any((a) => a.nombre == ref.nombre)) continue;
    inventario.add(ArticuloInventario(nombre: ref.nombre, emoji: ref.emoji, precio: ref.precio));
    nuevas++;
  }
  return nuevas;
}

class ResultadoInventario {
  final double valor; // valor de costo de toda la mercadería
  final double valorRespaldo; // lo que valdría si hubiera que rematarla (60 %)
  final double montoSugerido; // préstamo que el inventario respalda
  final double cuota;
  final int variedad; // mercaderías distintas
  const ResultadoInventario({
    required this.valor,
    required this.valorRespaldo,
    required this.montoSugerido,
    required this.cuota,
    required this.variedad,
  });

  /// Más variedad = menos riesgo (si una mercadería no se vende, las otras sí).
  String get nivel => montoSugerido == 0
      ? 'Sin respaldo suficiente'
      : variedad >= 4
          ? 'Respaldo fuerte'
          : variedad >= 2
              ? 'Respaldo medio'
              : 'Respaldo básico';
}

/// El inventario funciona como garantía: se valora al 60 % (precio de remate) y se presta
/// hasta el 80 % de ese valor, dentro de los límites de CrediSol.
ResultadoInventario evaluarInventario(List<ArticuloInventario> inventario, {int plazo = 6}) {
  final valor = inventario.fold(0.0, (s, a) => s + a.subtotal);
  final respaldo = valor * 0.6;
  var monto = (respaldo * 0.8 / 50).floorToDouble() * 50; // múltiplos de S/ 50
  if (monto < ConfigPrestamos.montoMinimo) monto = 0;
  monto = math.min(monto, ConfigPrestamos.montoMaximo);
  var cuota = 0.0;
  if (monto > 0) {
    cuota = generarCronograma(
      monto: monto,
      tasa: ConfigPrestamos.tasa,
      tasaAnual: ConfigPrestamos.tasaAnual,
      plazo: plazo,
      fechaInicio: DateTime(2026, 1, 1),
    ).first.cuota;
  }
  return ResultadoInventario(
    valor: _r(valor),
    valorRespaldo: _r(respaldo),
    montoSugerido: monto,
    cuota: _r(cuota),
    variedad: inventario.where((a) => a.cantidad > 0).length,
  );
}
