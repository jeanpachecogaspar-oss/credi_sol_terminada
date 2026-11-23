import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);
  static const Color dorado = Color(0xFFF2B705);
  static const Color verde = Color(0xFF2E9E6B);
  static const Color ambar = Color(0xFFB38600);
  static const Color gris = Color(0xFF6B7A90);
  static const Color fondo = Color(0xFFF4F7FC);
  static const Color campo = Color(0xFFF7F8FA);
  static const Color texto = Color(0xFF1A1A2E);
}

class AppTheme {
  static OutlineInputBorder _borde(Color color, double ancho) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: ancho),
      );

  static ThemeData get claro => _crear(Brightness.light);
  static ThemeData get oscuro => _crear(Brightness.dark);

  /// Un solo tema para los dos modos: cambia solo lo que depende del fondo.
  static ThemeData _crear(Brightness brillo) {
    final dark = brillo == Brightness.dark;
    final fondo = dark ? PaletaOscura.fondo : AppColors.fondo;
    final texto = dark ? PaletaOscura.texto : AppColors.texto;
    final campo = dark ? PaletaOscura.campo : AppColors.campo;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.azul,
      brightness: brillo,
    ).copyWith(
      primary: AppColors.azul,
      onPrimary: Colors.white,
      secondary: AppColors.dorado,
      error: AppColors.rojo,
      surface: dark ? PaletaOscura.superficie : Colors.white,
      onSurface: texto,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brillo);

    return base.copyWith(
      scaffoldBackgroundColor: fondo,
      textTheme: base.textTheme.apply(
        bodyColor: texto,
        displayColor: texto,
      ),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(color: scheme.surface, surfaceTintColor: Colors.transparent),
      // Encabezado único para todas las pantallas (cliente y administrador):
      // azul de la marca con esquinas inferiores redondeadas, igual que el de Inicio.
      appBarTheme: AppBarTheme(
        // En modo oscuro, un azul más profundo para no encandilar.
        backgroundColor: dark ? AppColors.azulOscuro : AppColors.azul,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      // Pestañas dentro del encabezado azul.
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xCCFFFFFF),
        indicatorColor: Colors.white,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.azul,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.azul),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.azul,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: campo,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14),
        hintStyle: TextStyle(color: dark ? Colors.grey.shade600 : Colors.grey.shade400),
        border: _borde(Colors.transparent, 0),
        enabledBorder: _borde(Colors.transparent, 0),
        focusedBorder: _borde(AppColors.azul, 1.5),
        errorBorder: _borde(AppColors.rojo, 1),
        focusedErrorBorder: _borde(AppColors.rojo, 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFFE8ECF4) : AppColors.texto,
        contentTextStyle: TextStyle(color: dark ? AppColors.texto : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.azul,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.azul),
      dividerTheme: DividerThemeData(color: dark ? PaletaOscura.borde : const Color(0xFFE8ECF3), thickness: 1),
    );
  }
}

/// Colores del modo oscuro (fondos azul noche, no negro puro: se lee mejor y cansa menos).
class PaletaOscura {
  static const Color fondo = Color(0xFF0F141C);
  static const Color superficie = Color(0xFF1A212C);
  static const Color campo = Color(0xFF232C39);
  static const Color texto = Color(0xFFE8ECF4);
  static const Color borde = Color(0xFF2C3645);
}

/// Colores que cambian según el modo claro/oscuro, para las pantallas que
/// antes tenían colores fijos (tarjetas blancas, textos grises).
/// Al cambiar de modo, [ControlTema] redibuja toda la app para que se apliquen.
class Paleta {
  static bool oscuro = false;

  static Color get fondo => oscuro ? PaletaOscura.fondo : AppColors.fondo;
  static Color get superficie => oscuro ? PaletaOscura.superficie : Colors.white;
  static Color get campo => oscuro ? PaletaOscura.campo : AppColors.campo;
  static Color get texto => oscuro ? PaletaOscura.texto : AppColors.texto;
  static Color get borde => oscuro ? PaletaOscura.borde : const Color(0xFFE8ECF3);
  static Color get placeholder => oscuro ? PaletaOscura.campo : const Color(0xFFEFF3F9);

  // Grises: en oscuro se invierte la escala para mantener el contraste.
  static Color get gris200 => oscuro ? Colors.grey.shade800 : Colors.grey.shade200;
  static Color get gris300 => oscuro ? Colors.grey.shade700 : Colors.grey.shade300;
  static Color get gris400 => oscuro ? Colors.grey.shade600 : Colors.grey.shade400;
  static Color get gris500 => Colors.grey.shade500;
  static Color get gris600 => oscuro ? Colors.grey.shade400 : Colors.grey.shade600;
  static Color get gris700 => oscuro ? Colors.grey.shade300 : Colors.grey.shade700;
  static Color get gris800 => oscuro ? Colors.grey.shade200 : Colors.grey.shade800;
}

/// Modo de apariencia elegido por el usuario en Ajustes (Claro / Oscuro / Según el celular).
/// La app SIEMPRE empieza en claro: solo se oscurece si el usuario lo elige. Se guarda en el celular.
class ControlTema {
  static final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.light);
  static const _clave = 'modo_tema';

  static Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      modo.value = ThemeMode.values.firstWhere(
        (m) => m.name == p.getString(_clave),
        orElse: () => ThemeMode.light,
      );
    } catch (_) {}
  }

  static Future<void> cambiar(ThemeMode nuevo) async {
    modo.value = nuevo;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_clave, nuevo.name);
    } catch (_) {}
  }

  /// ¿Se ve oscuro ahora? Considera el modo del celular si eligió "Según el celular".
  static bool esOscuro(ThemeMode m) =>
      m == ThemeMode.dark ||
      (m == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  /// Redibuja todos los widgets (incluidos los `const`) para que tomen los colores de [Paleta].
  /// No reinicia pantallas ni pierde lo escrito: solo vuelve a pintar.
  static void redibujarTodo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(marcar);
  }
}

/// Selector "Apariencia": Claro / Oscuro / Según el celular.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ControlTema.modo,
      builder: (context, modo, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dark_mode_outlined, color: AppColors.azul),
                const SizedBox(width: 16),
                Text('Apariencia', style: TextStyle(fontWeight: FontWeight.w600, color: Paleta.texto)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Claro')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Oscuro')),
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.smartphone_rounded), label: Text('Celular')),
                ],
                selected: {modo},
                onSelectionChanged: (s) => ControlTema.cambiar(s.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
