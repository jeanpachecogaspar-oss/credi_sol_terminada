import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'config_drive.dart';

/// Imágenes alojadas en Google Drive.
///
/// En Drive, la imagen (o la carpeta que la contiene) debe estar compartida como
/// "Cualquier persona con el enlace · Lector". Se acepta cualquiera de estos formatos:
///   https://drive.google.com/file/d/ID/view?usp=sharing
///   https://drive.google.com/open?id=ID
///   https://drive.google.com/uc?id=ID&export=view
///   ID (solo el identificador)
/// Si el enlace no es de Drive (por ejemplo una URL directa .jpg), se usa tal cual.

final RegExp _reIdArchivo = RegExp(r'/d/([a-zA-Z0-9_-]{20,})');
final RegExp _reIdParam = RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})');
final RegExp _reSoloId = RegExp(r'^[a-zA-Z0-9_-]{20,}$');

/// Extrae el ID de un archivo de Drive, o null si el texto no es de Drive.
String? idDrive(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return null;
  if (_reSoloId.hasMatch(t)) return t;
  if (!t.contains('google')) return null;
  return _reIdArchivo.firstMatch(t)?.group(1) ?? _reIdParam.firstMatch(t)?.group(1);
}

/// Convierte un enlace de Drive en una URL que se puede mostrar como imagen.
/// [ancho] es el tamaño pedido a Drive (más chico = carga más rápida).
String urlImagen(String texto, {int ancho = 800}) {
  final id = idDrive(texto);
  if (id == null) return texto.trim();
  return 'https://drive.google.com/thumbnail?id=$id&sz=w$ancho';
}

/// Imagen de red con marcador mientras carga y un ícono si falla.
class ImagenDrive extends StatelessWidget {
  final String? enlace;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int ancho;
  final IconData iconoVacio;

  const ImagenDrive(
    this.enlace, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.ancho = 800,
    this.iconoVacio = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final e = (enlace ?? '').trim();
    if (e.isEmpty) return _marcador(iconoVacio);
    return Image.network(
      urlImagen(e, ancho: ancho),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sincrono) {
        if (sincrono) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progreso) {
        if (progreso == null) return child;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            _marcador(null),
            child,
          ],
        );
      },
      errorBuilder: (context, error, stack) => _marcador(Icons.broken_image_outlined),
    );
  }

  Widget _marcador(IconData? icono) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEFF3F9),
      alignment: Alignment.center,
      child: icono == null ? null : Icon(icono, color: AppColors.gris.withValues(alpha: 0.6), size: 32),
    );
  }
}

/// Un archivo de imagen dentro de la carpeta de Drive configurada.
class ArchivoDrive {
  final String id;
  final String nombre;
  const ArchivoDrive(this.id, this.nombre);
  String get enlace => 'https://drive.google.com/file/d/$id/view';
}

/// Lista las imágenes de la carpeta pública de Drive configurada en [ConfigDrive].
/// Usa la API de Drive v3 con una clave de API (sin iniciar sesión).
Future<List<ArchivoDrive>> listarCarpetaDrive() async {
  if (!ConfigDrive.configurado) {
    throw StateError('Falta configurar la carpeta de Drive y la clave de API en lib/config_drive.dart.');
  }
  final q = "'${ConfigDrive.carpetaId}' in parents and mimeType contains 'image/' and trashed = false";
  final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
    'q': q,
    'key': ConfigDrive.apiKey,
    'fields': 'files(id,name)',
    'pageSize': '200',
    'orderBy': 'name',
  });

  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await cliente.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 20));
    final cuerpo = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw StateError('Drive respondió ${res.statusCode}. Revisa que la carpeta sea pública '
          'y que la clave de API tenga habilitada la "Google Drive API".');
    }
    final datos = jsonDecode(cuerpo) as Map<String, dynamic>;
    final archivos = (datos['files'] as List? ?? []).cast<Map<String, dynamic>>();
    return [
      for (final a in archivos) ArchivoDrive(a['id'].toString(), (a['name'] ?? '').toString()),
    ];
  } on SocketException {
    throw StateError('Sin conexión a internet.');
  } finally {
    cliente.close();
  }
}

/// Hoja inferior para elegir una imagen de la carpeta de Drive. Devuelve el enlace o null.
Future<String?> elegirImagenDrive(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => const _SelectorDrive(),
  );
}

class _SelectorDrive extends StatefulWidget {
  const _SelectorDrive();

  @override
  State<_SelectorDrive> createState() => _SelectorDriveState();
}

class _SelectorDriveState extends State<_SelectorDrive> {
  late Future<List<ArchivoDrive>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = listarCarpetaDrive();
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: alto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Imágenes de Google Drive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Sube las fotos a la carpeta compartida y aparecerán aquí.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ArchivoDrive>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final e = snap.error;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            e is StateError ? e.message : 'No se pudo leer la carpeta de Drive.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => setState(() => _futuro = listarCarpetaDrive()),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final archivos = snap.data ?? [];
                if (archivos.isEmpty) {
                  return Center(
                    child: Text('La carpeta no tiene imágenes.', style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: archivos.length,
                  itemBuilder: (context, i) {
                    final a = archivos[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, a.enlace),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: ImagenDrive(a.id, ancho: 300, width: double.infinity),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(a.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
