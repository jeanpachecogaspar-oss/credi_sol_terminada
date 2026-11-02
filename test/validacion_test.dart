import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/apis_peru.dart';
import 'package:flutter_application_1/validacion_identidad.dart';

void main() {
  test('normaliza texto leído por OCR', () {
    expect(ValidadorIdentidad.normalizar('Av. Perú  N° 123, Jesús María'), 'AV PERU N 123 JESUS MARIA');
    expect(ValidadorIdentidad.normalizar('I<PER12345678<<'), 'I<PER12345678<<');
  });

  test('el resultado se guarda con estado y mensaje', () {
    const r = ResultadoValidacion(true, 'verificado', 'ok', {'dniLeido': true});
    expect(r.aMapa(), {'estado': 'verificado', 'mensaje': 'ok', 'dniLeido': true});
    const x = ResultadoValidacion.rechazo('no');
    expect(x.aceptada, isFalse);
    expect(x.estado, 'rechazado');
  });

  test('nombre de RENIEC con mayúscula inicial', () {
    const p = PersonaDni(dni: '12345678', nombres: 'JUAN CARLOS', apellidoPaterno: 'PEREZ', apellidoMaterno: 'LOPEZ');
    expect(p.nombreCompleto, 'Juan Carlos Perez Lopez');
  });
}
