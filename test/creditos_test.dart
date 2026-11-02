import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/config_prestamos.dart';
import 'package:flutter_application_1/productos_financieros.dart';
import 'package:flutter_application_1/score_screen.dart';
import 'package:flutter_application_1/sensores_camara.dart';

void main() {
  group('productos financieros', () {
    test('son 40, con id único y dentro de los límites de las reglas', () {
      expect(productosIniciales.length, 40);
      expect(productosIniciales.map((p) => p.id).toSet().length, 40);
      for (final p in productosIniciales) {
        expect(p.montoMin, greaterThanOrEqualTo(ConfigPrestamos.montoMinimo), reason: p.nombre);
        expect(p.montoMax, lessThanOrEqualTo(ConfigPrestamos.montoMaximo), reason: p.nombre);
        expect(p.plazoMin, greaterThanOrEqualTo(ConfigPrestamos.plazoMinimo), reason: p.nombre);
        expect(p.plazoMax, lessThanOrEqualTo(ConfigPrestamos.plazoMaximo), reason: p.nombre);
        expect(categoriasCredito, contains(p.categoria));
      }
    });

    test('cada producto tiene su imagen en assets', () {
      for (final p in productosIniciales) {
        expect(File(p.imagen).existsSync(), isTrue, reason: p.imagen);
      }
    });

    test('la cuota "desde" es positiva y menor que el monto', () {
      for (final p in productosIniciales) {
        expect(p.cuotaDesde, greaterThan(0));
        expect(p.cuotaDesde, lessThan(p.montoMin));
      }
    });
  });

  group('score CrediSol', () {
    ScoreCrediSol score({int puntuales = 0, int tarde = 0, int vencidas = 0, double ingreso = 2000}) => calcularScore(
          ingreso: ingreso,
          mesesAntiguedad: 6,
          dniVerificado: true,
          estadoDomicilio: 'verificado',
          cuotasPuntuales: puntuales,
          cuotasTarde: tarde,
          cuotasVencidas: vencidas,
          prestamosPagados: 0,
          cuotaMensualActiva: 0,
        );

    test('pagar puntual sube el score y atrasarse lo baja', () {
      final bueno = score(puntuales: 12);
      final malo = score(puntuales: 4, tarde: 8, vencidas: 2);
      expect(bueno.puntaje, greaterThan(malo.puntaje));
      expect(bueno.puntaje, inInclusiveRange(0, 1000));
      expect(malo.puntaje, inInclusiveRange(0, 1000));
    });

    test('con cuotas vencidas no hay monto preaprobado', () {
      expect(score(puntuales: 12, vencidas: 1).montoPreaprobado, 0);
      expect(score(puntuales: 12).montoPreaprobado, greaterThanOrEqualTo(ConfigPrestamos.montoMinimo));
    });
  });

  test('lee el número de DNI del texto del OCR', () {
    expect(extraerDni('REPUBLICA DEL PERU\nDNI 45678912\nPEREZ'), '45678912');
    expect(extraerDni('I<PER45678912<1<<<<<'), '45678912');
    expect(extraerDni('sin numero'), isNull);
  });
}
