import 'package:flutter_test/flutter_test.dart';
import 'package:credisol/cronograma.dart';
import 'package:credisol/ideas_calculos.dart';

void main() {
  group('Cuotas por temporada', () {
    test('con todos los meses "normal" es igual a la cuota fija', () {
      final i = tasaMensual(60, true);
      final flex = cronogramaPorTemporada(
        monto: 3000,
        meses: List.filled(12, Temporada.normal),
        fechaInicio: DateTime(2026, 1, 1),
        tasaMes: i,
      );
      final fijo = generarCronograma(monto: 3000, tasa: 60, tasaAnual: true, plazo: 12, fechaInicio: DateTime(2026, 1, 1));
      expect(flex.first.cuota, closeTo(fijo.first.cuota, 0.02));
      expect(flex.last.saldo, 0);
    });

    test('la cuota de temporada alta es mayor que la de temporada baja y el saldo termina en 0', () {
      final flex = cronogramaPorTemporada(
        monto: 5000,
        meses: [Temporada.baja, Temporada.normal, Temporada.alta, Temporada.alta, Temporada.normal, Temporada.baja],
        fechaInicio: DateTime(2026, 1, 1),
      );
      expect(flex[2].cuota, greaterThan(flex[0].cuota));
      expect(flex.last.saldo, 0);
      final amortizado = flex.fold(0.0, (s, c) => s + c.amortizacion);
      expect(amortizado, closeTo(5000, 0.05));
    });
  });

  group('Libreta de ventas', () {
    test('sin registros no sugiere monto', () {
      expect(analizarVentas([]).montoSugerido, 0);
    });

    test('ganancia de S/ 100 diarios sugiere un monto entre 300 y 10 000', () {
      final regs = List.generate(10, (k) => RegistroVenta(DateTime(2026, 11, k + 1), 300, 200));
      final a = analizarVentas(regs, plazo: 12);
      expect(a.gananciaMensual, 2600);
      expect(a.cuotaMaxima, closeTo(910, 0.01));
      expect(a.montoSugerido, greaterThanOrEqualTo(300));
      expect(a.montoSugerido, lessThanOrEqualTo(10000));
      expect(a.montoSugerido % 50, 0);
    });

    test('con pérdidas no sugiere préstamo', () {
      final regs = List.generate(7, (k) => RegistroVenta(DateTime(2026, 11, k + 1), 100, 150));
      expect(analizarVentas(regs).montoSugerido, 0);
    });
  });

  group('Planificador de inversión', () {
    const pollo = Insumo('pollo', 'Pollo', '🍗', 'unidad', 22, 48);
    test('calcula inversión, préstamo y ganancia', () {
      final r = evaluarInversion(canasta: {pollo: 50}, aportePropio: 100, rotacionesMes: 4, plazo: 6);
      expect(r.inversion, 1100);
      expect(r.montoPrestamo, 1000);
      expect(r.gananciaMensual, 5200);
      expect(r.conviene, isTrue);
    });

    test('si el aporte cubre todo no hace falta préstamo', () {
      final r = evaluarInversion(canasta: {pollo: 10}, aportePropio: 500, rotacionesMes: 2, plazo: 6);
      expect(r.montoPrestamo, 0);
      expect(r.cuota, 0);
    });
  });

  group('Banca comunal', () {
    test('el código tiene 6 caracteres válidos', () {
      final c = generarCodigoGrupo();
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(c), isTrue);
    });

    test('la cuota de un integrante es positiva', () {
      expect(cuotaIntegrante(1000, 6), greaterThan(1000 / 6));
    });
  });

  group('Inventario con cámara', () {
    test('reconoce etiquetas de ML Kit y no repite mercadería', () {
      final inv = <ArticuloInventario>[];
      final n = agregarEtiquetas(inv, ['Sneakers', 'Shoe', 'Room', 'Fruit']);
      expect(n, 2); // calzado una sola vez; "Room" no es mercadería
      expect(inv.map((a) => a.nombre), containsAll(['Calzado (par)', 'Fruta (kg)']));
      expect(referenciaPara('Shelf'), isNull);
    });

    test('presta hasta el 80 % del valor de remate (60 %) en múltiplos de 50', () {
      final inv = [ArticuloInventario(nombre: 'Calzado', emoji: '👟', precio: 45, cantidad: 100)];
      final r = evaluarInventario(inv, plazo: 6);
      expect(r.valor, 4500);
      expect(r.valorRespaldo, 2700);
      expect(r.montoSugerido, 2150); // 2700 × 0,8 = 2160 → 2150
      expect(r.cuota, greaterThan(0));
      expect(r.nivel, 'Respaldo básico');
    });

    test('un inventario chico no respalda préstamo', () {
      final r = evaluarInventario([ArticuloInventario(nombre: 'Pan', emoji: '🍞', precio: 0.4, cantidad: 50)]);
      expect(r.montoSugerido, 0);
      expect(r.cuota, 0);
      expect(r.nivel, 'Sin respaldo suficiente');
    });
  });
}
