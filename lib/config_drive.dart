/// Carpeta de Google Drive con las imágenes de productos financieros y promociones.
///
/// 1. En Google Drive crea una carpeta (ej. "CrediSol - Imágenes") y sube las fotos.
/// 2. Compártela: "Cualquier persona con el enlace" (Lector).
/// 3. Copia el ID de la carpeta (la parte final de https://drive.google.com/drive/folders/ID).
/// 4. Opcional, para el botón "Elegir de Drive": en Google Cloud Console habilita "Google Drive API"
///    y crea una Clave de API restringida a esa API.
/// Sin clave, el administrador igual puede pegar el enlace de cada imagen.
class ConfigDrive {
  static const String carpetaId = '';
  static const String apiKey = '';

  static bool get configurado => carpetaId.isNotEmpty && apiKey.isNotEmpty;
}
