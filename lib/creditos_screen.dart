import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'formato.dart';
import 'productos_financieros.dart';
import 'promociones.dart';
import 'seleccion_creditos.dart';
import 'solicitud_screen.dart';
import 'ui_comun.dart';

/// Pestaña "Créditos" del cliente: catálogo de productos financieros con imagen,
/// filtros, buscador y acceso a "Mi selección".
class CreditosScreen extends StatefulWidget {
  const CreditosScreen({super.key});

  @override
  State<CreditosScreen> createState() => _CreditosScreenState();
}

class _CreditosScreenState extends State<CreditosScreen> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  late final Stream<List<Promocion>> _promos;
  final TextEditingController _buscarCtrl = TextEditingController();
  String _categoria = '';
  String _buscar = '';

  @override
  void initState() {
    super.initState();
    _crear();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _promos = promocionesDelCliente(uid).asBroadcastStream();
    SeleccionCreditos.instancia.cargar(uid);
  }

  void _crear() {
    _stream = FirebaseFirestore.instance.collection('productosFinancieros').where('activo', isEqualTo: true).snapshots();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos para ti'),
        actions: const [BotonSeleccion(), SizedBox(width: 6)],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return errorConsulta(context, 'No se pudo cargar el catálogo', snap.error!, () => setState(_crear));
          }
          final todos = (snap.data?.docs ?? []).map(ProductoFinanciero.desde).toList()
            ..sort((a, b) {
              final c = categoriasCredito.indexOf(a.categoria).compareTo(categoriasCredito.indexOf(b.categoria));
              return c != 0 ? c : a.nombre.compareTo(b.nombre);
            });
          final q = _buscar.toLowerCase();
          final lista = todos
              .where((p) => _categoria.isEmpty || p.categoria == _categoria)
              .where((p) =>
                  q.isEmpty ||
                  p.nombre.toLowerCase().contains(q) ||
                  p.descripcion.toLowerCase().contains(q) ||
                  p.publico.toLowerCase().contains(q))
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CarruselPromociones(stream: _promos),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: _buscarCtrl,
                    onChanged: (v) => setState(() => _buscar = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Busca: bodega, mototaxi, estudios…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: Colors.white,
                      suffixIcon: _buscar.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _buscarCtrl.clear();
                                setState(() => _buscar = '');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: filtroChips(
                  opciones: [('', 'Todos'), for (final c in categoriasCredito) (c, c)],
                  actual: _categoria,
                  onChanged: (c) => setState(() => _categoria = c),
                ),
              ),
              if (!snap.hasData)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (lista.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: mensajeVacio(
                    Icons.account_balance_outlined,
                    todos.isEmpty ? 'Pronto tendremos créditos' : 'Sin resultados',
                    todos.isEmpty ? 'El catálogo aún no está cargado.' : 'Prueba con otra búsqueda o categoría.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.7,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TarjetaCredito(producto: lista[i]),
                      childCount: lista.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: SeleccionCreditos.instancia,
        builder: (context, _) {
          final s = SeleccionCreditos.instancia;
          if (s.vacia) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'miSeleccion',
            onPressed: () => abrirSeleccion(context),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: Text('Mi selección (${s.cantidad}) · ${fmtMoney(s.cuotaTotal)}/mes'),
          );
        },
      ),
    );
  }
}

void abrirSeleccion(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const MiSeleccionScreen()));
}

/// Ícono de "Mi selección" con la cantidad de créditos elegidos.
class BotonSeleccion extends StatelessWidget {
  const BotonSeleccion({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SeleccionCreditos.instancia,
      builder: (context, _) {
        final n = SeleccionCreditos.instancia.cantidad;
        return IconButton(
          tooltip: 'Mi selección',
          onPressed: () => abrirSeleccion(context),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text('$n'),
            backgroundColor: AppColors.rojo,
            child: const Icon(Icons.shopping_bag_outlined),
          ),
        );
      },
    );
  }
}

class _TarjetaCredito extends StatelessWidget {
  final ProductoFinanciero producto;
  const _TarjetaCredito({required this.producto});

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final color = colorCategoria(p.categoria);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetalleCreditoScreen(producto: p)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: 'credito-${p.id}', child: ImagenProducto(p)),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        p.categoria,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: ListenableBuilder(
                      listenable: SeleccionCreditos.instancia,
                      builder: (context, _) => SeleccionCreditos.instancia.contiene(p.id)
                          ? const CircleAvatar(
                              radius: 13,
                              backgroundColor: AppColors.verde,
                              child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                p.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'desde ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    TextSpan(
                      text: '${fmtMoney(p.cuotaDesde)}/mes',
                      style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle del crédito con simulador (monto y plazo) y botón para agregarlo a "Mi selección".
class DetalleCreditoScreen extends StatefulWidget {
  final ProductoFinanciero producto;
  const DetalleCreditoScreen({super.key, required this.producto});

  @override
  State<DetalleCreditoScreen> createState() => _DetalleCreditoScreenState();
}

class _DetalleCreditoScreenState extends State<DetalleCreditoScreen> {
  late double _monto;
  late int _plazo;

  ProductoFinanciero get p => widget.producto;

  @override
  void initState() {
    super.initState();
    final elegido = SeleccionCreditos.instancia.items.where((c) => c.producto.id == p.id).firstOrNull;
    _monto = elegido?.monto ?? _redondear((p.montoMin + p.montoMax) / 2);
    _plazo = elegido?.plazo ?? ((p.plazoMin + p.plazoMax) / 2).round();
  }

  double _redondear(double v) => ((v / 100).round() * 100).toDouble().clamp(p.montoMin, p.montoMax).toDouble();

  @override
  Widget build(BuildContext context) {
    final cuota = cuotaMensual(_monto, _plazo);
    final color = colorCategoria(p.categoria);
    final pasosMonto = ((p.montoMax - p.montoMin) / 100).round();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(tag: 'credito-${p.id}', child: ImagenProducto(p, padding: 48)),
            ),
            actions: const [BotonSeleccion(), SizedBox(width: 6)],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.categoria.toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(p.nombre, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(p.descripcion, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                  if (p.publico.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('Para: ${p.publico}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  tarjetaBlanca(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Simula tu crédito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _filaSlider('Monto', fmtMoney(_monto)),
                        Slider(
                          value: _monto,
                          min: p.montoMin,
                          max: p.montoMax,
                          divisions: pasosMonto > 0 ? pasosMonto : null,
                          onChanged: (v) => setState(() => _monto = _redondear(v)),
                        ),
                        _filaSlider('Plazo', '$_plazo ${_plazo == 1 ? 'mes' : 'meses'}'),
                        Slider(
                          value: _plazo.toDouble(),
                          min: p.plazoMin.toDouble(),
                          max: p.plazoMax.toDouble(),
                          divisions: p.plazoMax > p.plazoMin ? p.plazoMax - p.plazoMin : null,
                          onChanged: (v) => setState(() => _plazo = v.round()),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cuota mensual', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(end: cuota),
                                    duration: const Duration(milliseconds: 300),
                                    builder: (context, v, _) => Text(
                                      fmtMoney(v),
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(ConfigPrestamos.descripcionTasa,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text('Total ${fmtMoney(cuota * _plazo)}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Requisitos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final r in p.requisitosVisibles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.verde),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    SeleccionCreditos.instancia.agregar(p, _monto, _plazo);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${p.nombre} agregado a tu selección'),
                      action: SnackBarAction(label: 'Ver', onPressed: () => abrirSeleccion(context)),
                    ));
                  },
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Agregar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => solicitarCredito(context, p, _monto, _plazo),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Solicitar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaSlider(String t, String v) => Row(
        children: [
          Text(t, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      );
}

/// Lleva el crédito a la solicitud de 3 pasos (datos, fotos validadas con IA y confirmación).
void solicitarCredito(BuildContext context, ProductoFinanciero p, double monto, int plazo) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SolicitudScreen(
        monto: monto,
        tasa: ConfigPrestamos.tasa,
        tasaAnual: ConfigPrestamos.tasaAnual,
        plazo: plazo,
        fechaInicio: DateTime.now(),
        productoId: p.id,
        productoNombre: p.nombre,
        alEnviar: () => SeleccionCreditos.instancia.quitar(p.id),
      ),
    ),
  );
}

/// "Mi selección": el carrito de créditos. Compara cuotas, revisa que la cuota total
/// no supere el 40 % del ingreso declarado y envía la solicitud de cada crédito.
class MiSeleccionScreen extends StatefulWidget {
  const MiSeleccionScreen({super.key});

  @override
  State<MiSeleccionScreen> createState() => _MiSeleccionScreenState();
}

class _MiSeleccionScreenState extends State<MiSeleccionScreen> {
  double? _ingreso;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('usuarios').doc(uid).get().then((d) {
        final v = d.data()?['ingresoMensual'];
        if (mounted && v is num) setState(() => _ingreso = v.toDouble());
      }).catchError((Object e) => debugPrint('Selección: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = SeleccionCreditos.instancia;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi selección de créditos')),
      body: ListenableBuilder(
        listenable: sel,
        builder: (context, _) {
          if (sel.vacia) {
            return mensajeVacio(Icons.playlist_add_rounded, 'Aún no eliges créditos',
                'En la pestaña Créditos toca un producto y pulsa "Agregar".');
          }
          final ratio = (_ingreso != null && _ingreso! > 0) ? sel.cuotaTotal / _ingreso! : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.azul, AppColors.azulOscuro]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${sel.cantidad} ${sel.cantidad == 1 ? 'crédito elegido' : 'créditos elegidos'}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 4),
                    Text('${fmtMoney(sel.cuotaTotal)} al mes',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('Monto total ${fmtMoney(sel.montoTotal)} · ${ConfigPrestamos.descripcionTasa}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                    if (ratio != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          color: ratio > 0.4 ? const Color(0xFFFF8A80) : const Color(0xFFB9F6CA),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ratio > 0.4
                            ? 'Tu cuota sería el ${(ratio * 100).round()} % de tu ingreso: supera el 40 % recomendado.'
                            : 'Tu cuota sería el ${(ratio * 100).round()} % de tu ingreso. ¡Está dentro de lo saludable!',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final c in sel.items) ...[
                _ItemSeleccion(credito: c),
                const SizedBox(height: 12),
              ],
              Text(
                'Envías una solicitud a la vez. Al enviarla, el crédito sale de tu selección.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemSeleccion extends StatelessWidget {
  final CreditoElegido credito;
  const _ItemSeleccion({required this.credito});

  @override
  Widget build(BuildContext context) {
    final c = credito;
    final p = c.producto;
    return Dismissible(
      key: ValueKey('sel-${p.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => SeleccionCreditos.instancia.quitar(p.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.rojo, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: tarjetaBlanca(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 64, height: 64, child: ImagenProducto(p, padding: 8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${fmtMoney(c.monto)} en ${c.plazo} meses',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text('${fmtMoney(c.cuota)}/mes',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ajustar',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetalleCreditoScreen(producto: p)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => solicitarCredito(context, p, c.monto, c.plazo),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Solicitar este crédito'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
