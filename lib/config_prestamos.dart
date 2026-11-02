/// Condiciones del producto de préstamo.
///
/// IMPORTANTE: la tasa y los límites también se validan en `firestore.rules`
/// (función `solicitudValida`). Si cambias un valor aquí, cámbialo también allí
/// y vuelve a publicar las reglas; si no, las solicitudes serán rechazadas.
class ConfigPrestamos {
  /// Tasa del negocio. Con [tasaAnual] = true se interpreta como TEA (%).
  static const double tasa = 60.0;
  static const bool tasaAnual = true;

  static const double montoMinimo = 300;
  static const double montoMaximo = 10000;
  static const int plazoMinimo = 1;
  static const int plazoMaximo = 24;

  /// Sin comisiones ni seguros, la TCEA coincide con la TEA.
  /// Si en el futuro se agregan cargos, deben sumarse a cada cuota antes de
  /// calcular la TCEA con `calcularTcea`.
  static String get descripcionTasa => tasaAnual ? '$tasa% TEA' : '$tasa% mensual';
}

/// Datos de la empresa usados en el consentimiento (Ley N.° 29733).
/// REEMPLAZAR antes de publicar (Fase 5) por la razón social, el RUC y el correo reales.
class ConfigEmpresa {
  static const String nombre = 'Jean Pacheco Gaspar';
  static const String correoDatos = 'jean@gmail.com';
  static const String versionConsentimiento = '2026-11';

  /// WhatsApp de atención al cliente, con código de país y sin espacios ni "+".
  /// REEMPLAZAR por el número real de soporte.
  static const String whatsappSoporte = '51946304875';
}
