import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';
import 'app_theme.dart';
import 'avisos.dart';
import 'formato.dart';
import 'ideas_calculos.dart';
import 'navegacion_cliente.dart';
import 'ui_comun.dart';

/// IDEA DISRUPTIVA 5: Inventario con cámara.
///
/// Muchos emprendedores no tienen casa propia ni papeles que dejar en garantía, pero sí tienen
/// mercadería. El cliente FOTOGRAFÍA su stock y la IA del celular (Google ML Kit, sin internet,
/// las fotos no salen del equipo) reconoce qué mercadería hay. El cliente ajusta cantidades y
/// la app calcula cuánto vale su inventario y qué préstamo respalda: una garantía sin papeles.
class InventarioCamaraScreen extends StatefulWidget {
  const InventarioCamaraScreen({super.key});

  @override
  State<InventarioCamaraScreen> createState() => _InventarioCamaraScreenState();
}

class _InventarioCamaraScreenState extends State<InventarioCamaraScreen> {
  final List<ArticuloInventario> _inventario = [];
  final List<File> _fotos = [];
  int _plazo = 6;
  bool _analizando = false;

  Future<void> _fotografiar(ImageSource fuente) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final foto = await ImagePicker().pickImage(
        source: fuente,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (foto == null) return;
      setState(() => _analizando = true);
      final lector = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.55));
      try {
        final etiquetas = await lector.processImage(InputImage.fromFilePath(foto.path));
        final nuevas = agregarEtiquetas(_inventario, etiquetas.map((e) => e.label));
        HapticFeedback.mediumImpact();
        setState(() => _fotos.add(File(foto.path)));
        messenger.mostrarAviso(SnackBar(
          content: Text(nuevas > 0
              ? 'Reconocí $nuevas mercadería${nuevas == 1 ? '' : 's'} nueva${nuevas == 1 ? '' : 's'}. Ajusta las cantidades.'
              : 'No reconocí mercadería nueva. Acércate más o agrégala a mano.'),
        ));
      } finally {
        await lector.close();
        if (mounted) setState(() => _analizando = false);
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _analizando = false);
      messenger.mostrarAviso(SnackBar(
        content: Text(e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
            ? 'Permite el acceso a la cámara y a las fotos desde los ajustes del celular.'
            : 'No se pudo abrir la cámara o la galería.'),
      ));
    }
  }

  Future<void> _editarPrecio(ArticuloInventario a) async {
    final ctrl = TextEditingController(text: a.precio.toStringAsFixed(2));
    final valor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio de ${a.nombre}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'S/ ', labelText: 'Costo por unidad'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (valor != null && valor >= 0) setState(() => a.precio = valor);
  }

  Future<void> _agregarManual() async {
    final ref = await showModalBottomSheet<ReferenciaInventario>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final opciones = {for (final r in referenciasInventario.values) r.nombre: r}.values.toList();
        return ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Agregar mercadería', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            for (final r in opciones)
              ListTile(
                leading: Text(r.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(r.nombre),
                trailing: Text(fmtMoney(r.precio)),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        );
      },
    );
    if (ref == null) return;
    setState(() {
      final ya = _inventario.where((a) => a.nombre == ref.nombre);
      if (ya.isNotEmpty) {
        ya.first.cantidad++;
      } else {
        _inventario.add(ArticuloInventario(nombre: ref.nombre, emoji: ref.emoji, precio: ref.precio, detectado: false));
      }
    });
  }

  void _cambiarCantidad(ArticuloInventario a, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      a.cantidad = (a.cantidad + delta).clamp(0, 9999);
      if (a.cantidad == 0) _inventario.remove(a);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = evaluarInventario(_inventario, plazo: _plazo);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario con cámara')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          tarjetaBlanca(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.azul.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.azul),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu mercadería es tu garantía. Toma fotos de tus estantes: la IA de tu celular '
                    'reconoce los productos y calcula cuánto préstamo respalda. Las fotos no salen de tu equipo.',
                    style: TextStyle(color: Paleta.gris700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _analizando ? null : () => _fotografiar(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _analizando ? null : () => _fotografiar(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          if (_analizando) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text('Reconociendo mercadería…', style: TextStyle(color: Paleta.gris600, fontSize: 12.5)),
          ],
          if (_fotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_fotos[i], width: 72, height: 72, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          tarjetaBlanca(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Mi inventario', style: TextStyle(fontWeight: FontWeight.w700))),
                    TextButton.icon(
                      onPressed: _agregarManual,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (_inventario.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('Toma una foto de tu mercadería para empezar',
                          style: TextStyle(color: Paleta.gris500, fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  for (final a in _inventario)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(a.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _editarPrecio(a),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(a.nombre,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                      if (a.detectado) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.azul),
                                      ],
                                    ],
                                  ),
                                  Text('${a.cantidad} × ${fmtMoney(a.precio)} = ${fmtMoney(a.subtotal)}  ✎',
                                      style: TextStyle(fontSize: 12, color: Paleta.gris600)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _cambiarCantidad(a, -1),
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          GestureDetector(
                            onLongPress: () => _cambiarCantidad(a, 10),
                            child: Text('${a.cantidad}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          IconButton(
                            onPressed: () => _cambiarCantidad(a, 1),
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.azul),
                          ),
                        ],
                      ),
                    ),
                if (_inventario.isNotEmpty)
                  Text('✨ = reconocido por la IA · toca un producto para cambiar su precio · '
                      'mantén presionada la cantidad para sumar 10',
                      style: TextStyle(fontSize: 11, color: Paleta.gris500)),
              ],
            ),
          ),
          if (_inventario.isNotEmpty) ...[
            const SizedBox(height: 14),
            tarjetaBlanca(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(r.nivel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: r.montoSugerido == 0
                            ? AppColors.rojo
                            : r.variedad >= 4
                                ? AppColors.verde
                                : AppColors.ambar,
                      )),
                  Text(
                    r.montoSugerido == 0
                        ? 'Tu inventario aún no alcanza para respaldar un préstamo. Agrega más mercadería.'
                        : 'Mientras más variada sea tu mercadería, menor es el riesgo y mejor tu respaldo.',
                    style: TextStyle(color: Paleta.gris700, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  filaDato('Valor de tu inventario', fmtMoney(r.valor)),
                  filaDato('Valor de respaldo (60 %)', fmtMoney(r.valorRespaldo)),
                  filaDato('Préstamo que respalda', fmtMoney(r.montoSugerido), destacado: true),
                  if (r.montoSugerido > 0) ...[
                    filaDato('Cuota mensual', '${fmtMoney(r.cuota)} × $_plazo'),
                    const SizedBox(height: 8),
                    Text('Plazo: $_plazo meses', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _plazo.toDouble(),
                      min: 1,
                      max: 24,
                      divisions: 23,
                      onChanged: (v) => setState(() => _plazo = v.round()),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Clipboard.setData(ClipboardData(text: r.montoSugerido.toStringAsFixed(0)));
                        tabCliente.value = tabSimular;
                        Navigator.popUntil(context, (route) => route.isFirst);
                        messenger.mostrarAviso(SnackBar(
                          content: Text('Simula ${fmtMoney(r.montoSugerido)} a $_plazo meses (monto copiado).'),
                        ));
                      },
                      icon: const Icon(Icons.calculate_rounded),
                      label: const Text('Simular este préstamo'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
