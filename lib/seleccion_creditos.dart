import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'productos_financieros.dart';

/// Un crédito elegido por el cliente, con el monto y el plazo que quiere.
class CreditoElegido {
  final ProductoFinanciero producto;
  double monto;
  int plazo;
  CreditoElegido(this.producto, this.monto, this.plazo);

  double get cuota => cuotaMensual(monto, plazo);
  double get total => cuota * plazo;

  Map<String, dynamic> aJson() => {
        'id': producto.id,
        'nombre': producto.nombre,
        'categoria': producto.categoria,
        'imagen': producto.imagen,
        'descripcion': producto.descripcion,
        'montoMin': producto.montoMin,
        'montoMax': producto.montoMax,
        'plazoMin': producto.plazoMin,
        'plazoMax': producto.plazoMax,
        'monto': monto,
        'plazo': plazo,
      };

  static CreditoElegido? desdeJson(Map<String, dynamic> j) {
    try {
      final p = ProductoFinanciero(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        categoria: j['categoria'] as String,
        descripcion: (j['descripcion'] ?? '') as String,
        imagen: (j['imagen'] ?? '') as String,
        montoMin: (j['montoMin'] as num).toDouble(),
        montoMax: (j['montoMax'] as num).toDouble(),
        plazoMin: (j['plazoMin'] as num).toInt(),
        plazoMax: (j['plazoMax'] as num).toInt(),
      );
      return CreditoElegido(p, (j['monto'] as num).toDouble(), (j['plazo'] as num).toInt());
    } catch (_) {
      return null;
    }
  }
}

/// "Mi selección": el carrito de créditos del cliente. Se guarda en el celular
/// (no se pierde al cerrar la app) y es propio de cada usuario.
class SeleccionCreditos extends ChangeNotifier {
  SeleccionCreditos._();
  static final SeleccionCreditos instancia = SeleccionCreditos._();

  final Map<String, CreditoElegido> _items = {};
  String? _uid;

  List<CreditoElegido> get items => _items.values.toList();
  int get cantidad => _items.length;
  bool get vacia => _items.isEmpty;
  bool contiene(String id) => _items.containsKey(id);
  double get cuotaTotal => _items.values.fold(0.0, (s, c) => s + c.cuota);
  double get montoTotal => _items.values.fold(0.0, (s, c) => s + c.monto);

  String get _clave => 'seleccion_creditos_${_uid ?? ''}';

  /// Carga la selección guardada del usuario (al iniciar sesión).
  Future<void> cargar(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    _items.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_clave);
      if (texto != null) {
        for (final j in (jsonDecode(texto) as List).cast<Map<String, dynamic>>()) {
          final c = CreditoElegido.desdeJson(j);
          if (c != null) _items[c.producto.id] = c;
        }
      }
    } catch (e) {
      debugPrint('Selección: no se pudo cargar: $e');
    }
    notifyListeners();
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode([for (final c in _items.values) c.aJson()]));
    } catch (e) {
      debugPrint('Selección: no se pudo guardar: $e');
    }
  }

  void agregar(ProductoFinanciero p, double monto, int plazo) {
    _items[p.id] = CreditoElegido(p, monto, plazo);
    notifyListeners();
    _guardar();
  }

  void actualizar(String id, {double? monto, int? plazo}) {
    final c = _items[id];
    if (c == null) return;
    if (monto != null) c.monto = monto;
    if (plazo != null) c.plazo = plazo;
    notifyListeners();
    _guardar();
  }

  void quitar(String id) {
    _items.remove(id);
    notifyListeners();
    _guardar();
  }

  /// Al cerrar sesión: no se muestran los créditos de otro usuario.
  void olvidarUsuario() {
    _uid = null;
    _items.clear();
    notifyListeners();
  }
}
