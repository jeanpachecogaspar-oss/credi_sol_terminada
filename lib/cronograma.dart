import 'dart:math' as math;

class CuotaCalc {
  final int numero;
  final DateTime fecha;
  final double cuota;
  final double interes;
  final double amortizacion;
  final double saldo;
  const CuotaCalc(this.numero, this.fecha, this.cuota, this.interes, this.amortizacion, this.saldo);
}

double _r(double v) => (v * 100).roundToDouble() / 100;

DateTime sumarMeses(DateTime f, int meses) {
  final total = f.month - 1 + meses;
  final anio = f.year + total ~/ 12;
  final mes = total % 12 + 1;
  final ultimoDia = DateTime(anio, mes + 1, 0).day;
  return DateTime(anio, mes, f.day > ultimoDia ? ultimoDia : f.day);
}

/// Tasa efectiva mensual (decimal) a partir de una TEA o una tasa mensual en %.
double tasaMensual(double tasa, bool tasaAnual) =>
    tasaAnual ? math.pow(1 + tasa / 100, 1 / 12).toDouble() - 1 : tasa / 100;

List<CuotaCalc> generarCronograma({
  required double monto,
  required double tasa,
  required bool tasaAnual,
  required int plazo,
  required DateTime fechaInicio,
}) {
  final i = tasaMensual(tasa, tasaAnual);

  final cuotaFija = _r(
    i == 0 ? monto / plazo : monto * i / (1 - math.pow(1 + i, -plazo).toDouble()),
  );

  final lista = <CuotaCalc>[];
  var saldo = monto;
  for (var n = 1; n <= plazo; n++) {
    final interes = _r(saldo * i);
    final esUltima = n == plazo;
    final amort = esUltima ? saldo : _r(cuotaFija - interes);
    final cuota = _r(amort + interes);
    saldo = esUltima ? 0.0 : _r(saldo - amort);
    lista.add(CuotaCalc(n, sumarMeses(fechaInicio, n), cuota, interes, amort, saldo));
  }
  return lista;
}

double totalCuotas(List<CuotaCalc> c) => _r(c.fold(0.0, (s, x) => s + x.cuota));
double totalIntereses(List<CuotaCalc> c) => _r(c.fold(0.0, (s, x) => s + x.interes));

/// TCEA (%) a partir de los flujos reales: desembolso y cuotas mensuales.
/// Se obtiene la TIR mensual por bisección y se anualiza: (1 + TIR)^12 - 1.
double calcularTcea(double monto, List<double> cuotas) {
  if (monto <= 0 || cuotas.isEmpty) return 0;
  double vpn(double i) {
    var v = -monto;
    for (var n = 0; n < cuotas.length; n++) {
      v += cuotas[n] / math.pow(1 + i, n + 1);
    }
    return v;
  }

  if (vpn(0) <= 0) return 0;
  var bajo = 0.0, alto = 1.0;
  for (var k = 0; k < 100; k++) {
    final medio = (bajo + alto) / 2;
    if (vpn(medio) > 0) {
      bajo = medio;
    } else {
      alto = medio;
    }
  }
  final tir = (bajo + alto) / 2;
  return (math.pow(1 + tir, 12).toDouble() - 1) * 100;
}
