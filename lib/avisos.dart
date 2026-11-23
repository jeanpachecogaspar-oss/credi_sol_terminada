import 'package:flutter/material.dart';

/// Avisos de acciones (SnackBar) consistentes en toda la app.
///
/// Flutter pone los SnackBar en cola: si el usuario hace varias acciones seguidas,
/// cada aviso esperaba ~4 s a que terminara el anterior y aparecía tarde, cuando ya
/// no correspondía a lo que acababa de hacer. Aquí el aviso nuevo reemplaza al anterior.
extension AvisosCrediSol on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> mostrarAviso(SnackBar aviso) {
    hideCurrentSnackBar();
    return showSnackBar(aviso);
  }
}
