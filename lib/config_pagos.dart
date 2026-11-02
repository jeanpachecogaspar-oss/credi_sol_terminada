/// Datos donde el cliente paga sus cuotas. Se muestran en "Pagar cuota".
///
/// REEMPLAZAR antes de publicar con los datos reales. Mientras [cuenta] o [cci]
/// sigan con ceros de ejemplo, la opción "Transferencia" no se muestra al cliente,
/// para que nadie transfiera a una cuenta inexistente.
///
/// Yape: la app abre Yape (paquete com.bcp.innovacxion.yapeapp, declarado en
/// `<queries>` del AndroidManifest). Yape no ofrece un enlace público para precargar
/// el monto: el cliente copia el número y el monto desde la app.
class ConfigPagos {
  static const String titular = 'JEAN PACHECO GASPAR';
  static const String yapeNumero = '946 304 875';
  static const String plinNumero = '946 304 875';
  static const String banco = 'BCP';
  static const String cuenta = '000-0000000-0-00';
  static const String cci = '000-000-000000000000-00';

  static bool _esEjemplo(String v) => v.replaceAll(RegExp(r'[^0-9]'), '').replaceAll('0', '').isEmpty;

  /// True solo cuando la cuenta y el CCI ya son reales.
  static bool get transferenciaDisponible => !_esEjemplo(cuenta) && !_esEjemplo(cci);

  static List<String> get medios => ['Yape', 'Plin', if (transferenciaDisponible) 'Transferencia'];
}

/// Agencias de CrediSol que se muestran en el mapa "Pagar cerca de ti".
/// REEMPLAZAR por las direcciones y coordenadas reales (en Google Maps: clic derecho > copiar coordenadas).
class ConfigAgencias {
  static const List<({String nombre, String direccion, double lat, double lng})> agencias = [
    (nombre: 'CrediSol – Agencia Principal', direccion: 'Plaza Constitución, Huancayo', lat: -12.0686, lng: -75.2103),
  ];
}
