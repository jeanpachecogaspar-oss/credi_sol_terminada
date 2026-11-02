String fmtNum(double v) {
  final partes = v.toStringAsFixed(2).split('.');
  final entero = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$entero.${partes[1]}';
}

/// "Modo privado" (sensor): cuando es true, los montos se muestran ocultos.
bool ocultarMontos = false;

String fmtMoney(double v) => ocultarMontos ? 'S/ ••••' : 'S/ ${fmtNum(v)}';

String fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';