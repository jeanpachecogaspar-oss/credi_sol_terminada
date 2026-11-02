import 'package:flutter/foundation.dart';

/// Pestañas del cliente.
const int tabInicio = 0;
const int tabCreditos = 1;
const int tabSimular = 2;
const int tabPrestamos = 3;
const int tabPerfil = 4;

/// Pestaña activa del cliente.
final ValueNotifier<int> tabCliente = ValueNotifier<int>(tabInicio);
