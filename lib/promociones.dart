import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_drive.dart';
import 'drive_imagen.dart';
import 'errores.dart';
import 'formato.dart';
import 'ui_comun.dart';

/// Campañas y promociones de CrediSol: para TODOS los clientes o solo para clientes ELEGIDOS.
/// Ej.: "Campaña escolar: sin comisión", "Tasa preferencial para clientes puntuales".

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

class Promocion {
  final String id;
  final String titulo;
  final String descripcion;
  final String imagen;
  final String tipo;
  final double valor;
  final double montoMinimo;
  final String para;
  final List<String> clientes;
  final bool activo;
  final DateTime? fechaFin;

  const Promocion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.imagen,
    required this.tipo,
    required this.valor,
    required this.montoMinimo,
    required this.para,
    required this.clientes,
    required this.activo,
    required this.fechaFin,
  });

  factory Promocion.desde(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final fin = d['fechaFin'];
    return Promocion(
      id: doc.id,
      titulo: (d['titulo'] ?? '').toString(),
      descripcion: (d['descripcion'] ?? '').toString(),
      imagen: (d['imagen'] ?? '').toString(),
      tipo: d['tipo'] == 'monto' ? 'monto' : 'porcentaje',
      valor: _num(d['valor']),
      montoMinimo: _num(d['montoMinimo']),
      para: d['para'] == 'seleccionados' ? 'seleccionados' : 'todos',
      clientes: (d['clientes'] as List? ?? []).map((e) => e.toString()).toList(),
      activo: d['activo'] != false,
      fechaFin: fin is Timestamp ? fin.toDate() : null,
    );
  }

  bool get vigente {
    if (!activo) return false;
    final f = fechaFin;
    if (f == null) return true;
    final hoy = DateTime.now();
    return !DateTime(f.year, f.month, f.day).isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  /// Texto corto del beneficio: "10 % dscto." o "S/ 5.00 dscto."
  String get etiqueta =>
      tipo == 'porcentaje' ? '${_sinDecimales(valor)} % dscto.' : 'S/ ${valor.toStringAsFixed(2)} dscto.';

  /// Descuento que da sobre [subtotal] (0 si no alcanza el mínimo).
  double descuentoPara(double subtotal) {
    if (!vigente || subtotal <= 0 || subtotal < montoMinimo) return 0;
    final d = tipo == 'porcentaje' ? subtotal * valor / 100 : valor;
    final r = d.clamp(0, subtotal).toDouble();
    return (r * 100).roundToDouble() / 100;
  }

  static String _sinDecimales(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Promociones visibles para el cliente [uid]: las de "todos" y las dirigidas a él.
/// Son dos consultas porque las reglas solo permiten leer las que le corresponden.
Stream<List<Promocion>> promocionesDelCliente(String uid) {
  final col = FirebaseFirestore.instance.collection('promociones');
  final generales = col.where('para', isEqualTo: 'todos').snapshots();
  final personales = col.where('clientes', arrayContains: uid).snapshots();

  late StreamController<List<Promocion>> ctrl;
  List<Promocion> a = [], b = [];
  final subs = <StreamSubscription>[];

  void emitir() {
    final todas = <String, Promocion>{for (final p in [...a, ...b]) p.id: p};
    final lista = todas.values.where((p) => p.vigente).toList()
      ..sort((x, y) => (y.para == 'seleccionados' ? 1 : 0).compareTo(x.para == 'seleccionados' ? 1 : 0));
    ctrl.add(lista);
  }

  ctrl = StreamController<List<Promocion>>(
    onListen: () {
      subs.add(generales.listen((s) {
        a = s.docs.map(Promocion.desde).toList();
        emitir();
      }, onError: ctrl.addError));
      subs.add(personales.listen((s) {
        b = s.docs.map(Promocion.desde).toList();
        emitir();
      }, onError: ctrl.addError));
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return ctrl.stream;
}


// ======================= CLIENTE =======================

class CarruselPromociones extends StatefulWidget {
  final Stream<List<Promocion>> stream;
  final VoidCallback? onTap;
  const CarruselPromociones({super.key, required this.stream, this.onTap});

  @override
  State<CarruselPromociones> createState() => _CarruselPromocionesState();
}

class _CarruselPromocionesState extends State<CarruselPromociones> {
  final PageController _pagina = PageController(viewportFraction: 0.9);
  int _actual = 0;

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Promocion>>(
      stream: widget.stream,
      builder: (context, snap) {
        final promos = snap.data ?? const <Promocion>[];
        if (snap.hasError) debugPrint('Promociones: ${snap.error}');
        if (promos.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _pagina,
                itemCount: promos.length,
                onPageChanged: (i) => setState(() => _actual = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TarjetaPromocion(promo: promos[i], onTap: widget.onTap),
                ),
              ),
            ),
            if (promos.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < promos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _actual ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _actual ? AppColors.azul : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class TarjetaPromocion extends StatelessWidget {
  final Promocion promo;
  final VoidCallback? onTap;
  const TarjetaPromocion({super.key, required this.promo, this.onTap});

  @override
  Widget build(BuildContext context) {
    final personal = promo.para == 'seleccionados';
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      color: AppColors.azulOscuro,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (promo.imagen.isNotEmpty) ImagenDrive(promo.imagen, ancho: 900),
            // Degradado para que el texto se lea sobre cualquier foto.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.azulOscuro.withValues(alpha: 0.92),
                    AppColors.azulOscuro.withValues(alpha: promo.imagen.isEmpty ? 0.75 : 0.15),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: personal ? AppColors.dorado : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      personal ? 'SOLO PARA TI' : 'PROMOCIÓN',
                      style: TextStyle(
                        color: personal ? AppColors.texto : Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    child: Text(
                      promo.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (promo.descripcion.isNotEmpty) promo.descripcion,
                      if (promo.fechaFin != null) 'hasta el ${fmtFecha(promo.fechaFin!)}',
                    ].join(' · '),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ======================= ADMIN =======================

/// Lista de promociones para el administrador.
class PromocionesAdmin extends StatefulWidget {
  const PromocionesAdmin({super.key});

  @override
  State<PromocionesAdmin> createState() => _PromocionesAdminState();
}
class _CampoImagen extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCambio;
  const _CampoImagen({required this.controller, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: ImagenDrive(controller.text, ancho: 800, iconoVacio: Icons.add_photo_alternate_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          onChanged: (_) => onCambio(),
          decoration: const InputDecoration(
            labelText: 'Enlace de la imagen (Google Drive)',
            hintText: 'https://drive.google.com/file/d/…',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            if (!ConfigDrive.configurado) {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Conectar carpeta de Drive'),
                  content: const Text(
                    'Para elegir imágenes desde la app, configura el ID de la carpeta compartida y la clave de API '
                    'en lib/config_drive.dart.\n\n'
                    'Mientras tanto, en Drive abre la imagen > Compartir > "Cualquier persona con el enlace" > '
                    'Copiar enlace, y pégalo en el campo.',
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
                ),
              );
              return;
            }
            final enlace = await elegirImagenDrive(context);
            if (enlace != null) {
              controller.text = enlace;
              onCambio();
            }
          },
          icon: const Icon(Icons.add_to_drive),
          label: const Text('Elegir de Google Drive'),
        ),
      ],
    );
  }
}




class _PromocionesAdminState extends State<PromocionesAdmin> with AutomaticKeepAliveClientMixin {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _crear();
  }

  void _crear() {
    _stream = FirebaseFirestore.instance.collection('promociones').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return errorConsulta(context, 'No se pudieron cargar las promociones', snap.error!, () => setState(_crear));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final promos = snap.data!.docs.map(Promocion.desde).toList()
            ..sort((a, b) => (b.vigente ? 1 : 0).compareTo(a.vigente ? 1 : 0));
          if (promos.isEmpty) {
            return mensajeVacio(Icons.local_offer_outlined, 'Sin promociones',
                'Crea promociones para todos tus clientes o solo para algunos.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: promos.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = promos[i];
              return Opacity(
                opacity: p.vigente ? 1 : 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 130,
                      child: TarjetaPromocion(
                        promo: p,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FormPromocion(promo: p))),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                      child: Text(
                        [
                          p.para == 'todos' ? 'Para todos los clientes' : 'Para ${p.clientes.length} cliente(s)',
                          if (!p.activo) 'Pausada',
                          if (p.activo && !p.vigente) 'Vencida',
                        ].join(' · '),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nuevaPromo',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _FormPromocion())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva promoción'),
      ),
    );
  }
}

class _FormPromocion extends StatefulWidget {
  final Promocion? promo;
  const _FormPromocion({this.promo});

  @override
  State<_FormPromocion> createState() => _FormPromocionState();
}

class _FormPromocionState extends State<_FormPromocion> {
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _imagen;
  late String _para;
  late Set<String> _clientes;
  late bool _activo;
  DateTime? _fechaFin;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.promo;
    _titulo = TextEditingController(text: p?.titulo ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _imagen = TextEditingController(text: p?.imagen ?? '');
    _para = p?.para ?? 'todos';
    _clientes = {...?p?.clientes};
    _activo = p?.activo ?? true;
    _fechaFin = p?.fechaFin;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _imagen.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    final titulo = _titulo.text.trim();
    if (titulo.length < 3) {
      messenger.showSnackBar(const SnackBar(content: Text('Escribe un título')));
      return;
    }
    if (_para == 'seleccionados' && _clientes.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Elige al menos un cliente')));
      return;
    }
    setState(() => _guardando = true);
    final datos = {
      'titulo': titulo,
      'descripcion': _descripcion.text.trim(),
      'imagen': _imagen.text.trim(),
      'para': _para,
      'clientes': _para == 'todos' ? <String>[] : _clientes.toList(),
      'activo': _activo,
      'fechaFin': _fechaFin == null ? null : Timestamp.fromDate(_fechaFin!),
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };
    try {
      final col = FirebaseFirestore.instance.collection('promociones');
      if (widget.promo == null) {
        await col.add({...datos, 'fechaCreacion': FieldValue.serverTimestamp()});
      } else {
        await col.doc(widget.promo!.id).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final p = widget.promo;
    if (p == null) return;
    if (!await confirmar(context, 'Eliminar promoción', '¿Eliminar "${p.titulo}"?', 'Eliminar')) return;
    try {
      await FirebaseFirestore.instance.collection('promociones').doc(p.id).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? hoy.add(const Duration(days: 7)),
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Válida hasta',
    );
    if (f != null) setState(() => _fechaFin = f);
  }

  Future<void> _elegirClientes() async {
    final r = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(builder: (_) => _SelectorClientes(inicial: _clientes)),
    );
    if (r != null) setState(() => _clientes = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promo == null ? 'Nueva promoción' : 'Editar promoción'),
        actions: [
          if (widget.promo != null)
            IconButton(tooltip: 'Eliminar', onPressed: _eliminar, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CampoImagen(controller: _imagen, onCambio: () => setState(() {})),
          const SizedBox(height: 16),
          TextField(
            controller: _titulo,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título', hintText: 'Ej. Campaña escolar sin comisión'),
          ),
          TextField(
            controller: _descripcion,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Beneficio', hintText: 'Ej. Tasa preferencial para clientes puntuales'),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(_fechaFin == null ? 'Sin fecha de fin' : 'Válida hasta el ${fmtFecha(_fechaFin!)}'),
            trailing: _fechaFin == null
                ? TextButton(onPressed: _elegirFecha, child: const Text('Elegir'))
                : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _fechaFin = null)),
            onTap: _elegirFecha,
          ),
          const Divider(),
          const SizedBox(height: 4),
          const Text('¿Para quién es?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'todos', label: Text('Todos'), icon: Icon(Icons.groups_rounded)),
              ButtonSegment(value: 'seleccionados', label: Text('Clientes elegidos'), icon: Icon(Icons.person_pin_rounded)),
            ],
            selected: {_para},
            onSelectionChanged: (s) => setState(() => _para = s.first),
          ),
          if (_para == 'seleccionados') ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _elegirClientes,
              icon: const Icon(Icons.checklist_rounded),
              label: Text(_clientes.isEmpty ? 'Elegir clientes' : '${_clientes.length} cliente(s) elegido(s)'),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo estos clientes verán la promoción en su app.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
            title: const Text('Promoción activa'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar promoción'),
          ),
        ],
      ),
    );
  }
}

/// Lista de clientes con casillas, para dirigir una promoción.
class _SelectorClientes extends StatefulWidget {
  final Set<String> inicial;
  const _SelectorClientes({required this.inicial});

  @override
  State<_SelectorClientes> createState() => _SelectorClientesState();
}

class _SelectorClientesState extends State<_SelectorClientes> {
  late final Set<String> _elegidos = {...widget.inicial};
  late final Future<QuerySnapshot<Map<String, dynamic>>> _futuro =
      FirebaseFirestore.instance.collection('usuarios').where('rol', isEqualTo: 'cliente').get();
  String _buscar = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Elegir clientes (${_elegidos.length})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _elegidos), child: const Text('Listo')),
        ],
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.hasError) {
            return mensajeVacio(Icons.error_outline_rounded, 'No se pudieron cargar los clientes', mensajeError(snap.error!));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final q = _buscar.toLowerCase();
          final docs = snap.data!.docs.where((d) {
            final x = d.data();
            return q.isEmpty ||
                (x['nombre'] ?? '').toString().toLowerCase().contains(q) ||
                (x['email'] ?? '').toString().toLowerCase().contains(q) ||
                (x['dni'] ?? '').toString().contains(q);
          }).toList()
            ..sort((a, b) => (a.data()['nombre'] ?? '').toString().compareTo((b.data()['nombre'] ?? '').toString()));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _buscar = v.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, correo o DNI',
                    prefixIcon: Icon(Icons.search_rounded),
                    fillColor: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final x = d.data();
                    final nombre = (x['nombre'] ?? 'Sin nombre').toString();
                    return CheckboxListTile(
                      value: _elegidos.contains(d.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _elegidos.add(d.id);
                        } else {
                          _elegidos.remove(d.id);
                        }
                      }),
                      secondary: CircleAvatar(
                        backgroundColor: AppColors.azul.withValues(alpha: 0.12),
                        child: Text(nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(nombre),
                      subtitle: Text((x['email'] ?? '').toString()),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
