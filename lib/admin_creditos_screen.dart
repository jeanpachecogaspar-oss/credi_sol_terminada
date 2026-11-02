import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_drive.dart';
import 'config_prestamos.dart';
import 'drive_imagen.dart';
import 'errores.dart';
import 'formato.dart';
import 'productos_financieros.dart';
import 'promociones.dart';
import 'ui_comun.dart';

/// Pestaña "Créditos" del administrador: catálogo de productos financieros y campañas.
class AdminCreditosScreen extends StatelessWidget {
  const AdminCreditosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Productos financieros'),
          bottom: const TabBar(tabs: [Tab(text: 'Créditos'), Tab(text: 'Campañas')]),
        ),
        body: const TabBarView(children: [_ProductosAdmin(), PromocionesAdmin()]),
      ),
    );
  }
}

/// Carga o actualiza los 40 productos iniciales (no los duplica).
Future<void> cargarProductosIniciales(BuildContext context) async {
  final ok = await confirmar(
    context,
    'Cargar catálogo',
    'Se cargarán ${productosIniciales.length} productos financieros con su imagen '
        '(capital de trabajo, activo fijo, agropecuario, personal y especiales). '
        'Si ya existen, se actualizan.',
    'Cargar',
  );
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final db = FirebaseFirestore.instance;
    final lote = db.batch();
    for (final p in productosIniciales) {
      lote.set(db.collection('productosFinancieros').doc(p.id), {
        ...p.aMapa(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    }
    await lote.commit();
    messenger.showSnackBar(SnackBar(content: Text('Se cargaron ${productosIniciales.length} productos')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(mensajeError(e))));
  }
}

class _ProductosAdmin extends StatefulWidget {
  const _ProductosAdmin();

  @override
  State<_ProductosAdmin> createState() => _ProductosAdminState();
}

class _ProductosAdminState extends State<_ProductosAdmin> with AutomaticKeepAliveClientMixin {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _crear();
  }

  void _crear() {
    _stream = FirebaseFirestore.instance.collection('productosFinancieros').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return errorConsulta(context, 'No se pudo cargar el catálogo', snap.error!, () => setState(_crear));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final productos = snap.data!.docs.map(ProductoFinanciero.desde).toList()
            ..sort((a, b) {
              final c = categoriasCredito.indexOf(a.categoria).compareTo(categoriasCredito.indexOf(b.categoria));
              return c != 0 ? c : a.nombre.compareTo(b.nombre);
            });
          if (productos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/creditos/money_bag.png', width: 110),
                    const SizedBox(height: 14),
                    const Text('Aún no hay productos financieros',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Carga el catálogo inicial de 40 créditos con imagen o crea los tuyos.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => cargarProductosIniciales(context),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Cargar los 40 productos'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: productos.length + 1,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Row(
                  children: [
                    Expanded(
                      child: Text('${productos.length} productos',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    TextButton.icon(
                      onPressed: () => cargarProductosIniciales(context),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Recargar los 40'),
                    ),
                  ],
                );
              }
              final p = productos[i - 1];
              return tarjetaBlanca(
                padding: const EdgeInsets.all(10),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FormProducto(producto: p))),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(width: 60, height: 60, child: ImagenProducto(p, padding: 8)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${fmtMoney(p.montoMin)} – ${fmtMoney(p.montoMax)} · ${p.plazoMin}–${p.plazoMax} meses',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                            ),
                            Text(p.categoria,
                                style: TextStyle(color: colorCategoria(p.categoria), fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Switch(
                        value: p.activo,
                        onChanged: (v) => FirebaseFirestore.instance
                            .collection('productosFinancieros')
                            .doc(p.id)
                            .update({'activo': v}).catchError((e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeError(e))));
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nuevoCredito',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _FormProducto())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo crédito'),
      ),
    );
  }
}

class _FormProducto extends StatefulWidget {
  final ProductoFinanciero? producto;
  const _FormProducto({this.producto});

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _publico;
  late final TextEditingController _imagen;
  late String _categoria;
  late RangeValues _montos;
  late RangeValues _plazos;
  late bool _activo;
  bool _guardando = false;

  static const double _min = ConfigPrestamos.montoMinimo;
  static const double _max = ConfigPrestamos.montoMaximo;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _publico = TextEditingController(text: p?.publico ?? '');
    _imagen = TextEditingController(text: p?.imagen ?? '');
    _categoria = p?.categoria ?? categoriasCredito.first;
    _montos = RangeValues(p?.montoMin ?? 500, p?.montoMax ?? 5000);
    _plazos = RangeValues((p?.plazoMin ?? 3).toDouble(), (p?.plazoMax ?? 12).toDouble());
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _publico.dispose();
    _imagen.dispose();
    super.dispose();
  }

  ProductoFinanciero get _vista => ProductoFinanciero(
        id: widget.producto?.id ?? 'nuevo',
        nombre: _nombre.text,
        categoria: _categoria,
        descripcion: _descripcion.text,
        imagen: _imagen.text.trim(),
        montoMin: _montos.start,
        montoMax: _montos.end,
        plazoMin: _plazos.start.round(),
        plazoMax: _plazos.end.round(),
        publico: _publico.text.trim(),
        activo: _activo,
      );

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_nombre.text.trim().length < 3) {
      messenger.showSnackBar(const SnackBar(content: Text('Escribe el nombre del crédito')));
      return;
    }
    setState(() => _guardando = true);
    final datos = {
      ..._vista.aMapa(),
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };
    try {
      final col = FirebaseFirestore.instance.collection('productosFinancieros');
      if (widget.producto == null) {
        await col.add(datos);
      } else {
        await col.doc(widget.producto!.id).set(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final p = widget.producto;
    if (p == null) return;
    if (!await confirmar(context, 'Eliminar crédito', '¿Eliminar "${p.nombre}" del catálogo?', 'Eliminar')) return;
    try {
      await FirebaseFirestore.instance.collection('productosFinancieros').doc(p.id).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  /// Galería de las imágenes 3D incluidas en la app + opción de Google Drive.
  Future<void> _elegirImagen() async {
    final imagenes = {for (final p in productosIniciales) p.imagen}.toList();
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            const Text('Elige una imagen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (ConfigDrive.configurado)
              TextButton.icon(
                onPressed: () async {
                  final enlace = await elegirImagenDrive(ctx);
                  if (enlace != null && ctx.mounted) Navigator.pop(ctx, enlace);
                },
                icon: const Icon(Icons.add_to_drive),
                label: const Text('Elegir de Google Drive'),
              ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final img in imagenes)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, img),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                        child: Image.asset(img),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (r != null) setState(() => _imagen.text = r);
  }

  @override
  Widget build(BuildContext context) {
    final v = _vista;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.producto == null ? 'Nuevo crédito' : 'Editar crédito'),
        actions: [
          if (widget.producto != null)
            IconButton(tooltip: 'Eliminar', onPressed: _eliminar, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _elegirImagen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(height: 170, child: ImagenProducto(v, padding: 30)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _imagen,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Imagen (de la app o enlace de Drive)',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
              ),
              IconButton(onPressed: _elegirImagen, icon: const Icon(Icons.photo_library_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nombre,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Crédito Bodega'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcion,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          TextField(
            controller: _publico,
            decoration: const InputDecoration(labelText: 'Dirigido a', hintText: 'Ej. Bodegueros'),
          ),
          const SizedBox(height: 14),
          Text('Categoría', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categoriasCredito)
                ChoiceChip(label: Text(c), selected: _categoria == c, onSelected: (_) => setState(() => _categoria = c)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Monto: ${fmtMoney(_montos.start)} a ${fmtMoney(_montos.end)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          RangeSlider(
            values: _montos,
            min: _min,
            max: _max,
            divisions: ((_max - _min) / 100).round(),
            onChanged: (r) => setState(() => _montos = r),
          ),
          Text('Plazo: ${_plazos.start.round()} a ${_plazos.end.round()} meses',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          RangeSlider(
            values: _plazos,
            min: ConfigPrestamos.plazoMinimo.toDouble(),
            max: ConfigPrestamos.plazoMaximo.toDouble(),
            divisions: ConfigPrestamos.plazoMaximo - ConfigPrestamos.plazoMinimo,
            onChanged: (r) => setState(() => _plazos = r),
          ),
          Text('Tasa: ${ConfigPrestamos.descripcionTasa} (la del negocio)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _activo,
            onChanged: (x) => setState(() => _activo = x),
            title: const Text('Visible para los clientes'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
