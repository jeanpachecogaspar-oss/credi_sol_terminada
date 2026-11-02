import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/cronograma.dart';
import 'package:flutter_application_1/datos_personales.dart';

void main() {
  group('validaciones de datos personales', () {
    test('DNI de 8 dígitos', () {
      expect(validarDni('12345678'), isNull);
      expect(validarDni('1234567'), isNotNull);
      expect(validarDni('1234567a'), isNotNull);
    });

    test('celular peruano de 9 dígitos que empieza con 9', () {
      expect(validarCelular('987654321'), isNull);
      expect(validarCelular('887654321'), isNotNull);
      expect(validarCelular('98765432'), isNotNull);
    });

    test('edad exacta: cumple 18 el mismo día', () {
      final hoy = DateTime(2026, 10, 15);
      expect(edad(DateTime(2008, 10, 15), hoy), 18);
      expect(edad(DateTime(2008, 10, 16), hoy), 17);
    });

    test('nombre requiere nombres y apellidos', () {
      expect(validarNombre('María López'), isNull);
      expect(validarNombre('María'), isNotNull);
    });
  });

  group('generarCronograma', () {
    test('la suma de amortizaciones es igual al monto y el saldo final es 0', () {
      final c = generarCronograma(
        monto: 1000,
        tasa: 60,
        tasaAnual: true,
        plazo: 12,
        fechaInicio: DateTime(2026, 1, 31),
      );
      expect(c.length, 12);
      expect(c.last.saldo, 0);
      final amort = c.fold(0.0, (s, x) => s + x.amortizacion);
      expect(amort, closeTo(1000, 0.01));
      expect(totalCuotas(c), closeTo(1000 + totalIntereses(c), 0.01));
    });

    test('las fechas respetan el último día del mes', () {
      final c = generarCronograma(
        monto: 500,
        tasa: 3,
        tasaAnual: false,
        plazo: 2,
        fechaInicio: DateTime(2026, 1, 31),
      );
      expect(c[0].fecha, DateTime(2026, 2, 28));
      expect(c[1].fecha, DateTime(2026, 3, 31));
    });

    test('tasa 0 reparte el monto en cuotas iguales', () {
      final c = generarCronograma(
        monto: 1200,
        tasa: 0,
        tasaAnual: true,
        plazo: 12,
        fechaInicio: DateTime(2026, 1, 1),
      );
      expect(c.every((x) => x.cuota == 100), isTrue);
    });
  });

  group('calcularTcea', () {
    test('sin comisiones la TCEA coincide con la TEA', () {
      final c = generarCronograma(
        monto: 5000,
        tasa: 60,
        tasaAnual: true,
        plazo: 24,
        fechaInicio: DateTime(2026, 1, 1),
      );
      final tcea = calcularTcea(5000, c.map((x) => x.cuota).toList());
      expect(tcea, closeTo(60, 0.1));
    });

    test('un cargo adicional eleva la TCEA por encima de la TEA', () {
      final c = generarCronograma(
        monto: 5000,
        tasa: 60,
        tasaAnual: true,
        plazo: 12,
        fechaInicio: DateTime(2026, 1, 1),
      );
      final tcea = calcularTcea(5000, c.map((x) => x.cuota + 10).toList());
      expect(tcea, greaterThan(60));
    });
  });
}
