import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'formato.dart';
import 'ideas_calculos.dart';
import 'navegacion_cliente.dart';
import 'ui_comun.dart';

/// IDEA DISRUPTIVA 1: Planificador de inversión.
///
/// El emprendedor ARRASTRA la mercadería o los insumos que quiere comprar a su "canasta".
/// La app calcula al instante cuánto necesita prestarse, cuánto ganará por mes, la cuota
/// y si la ganancia alcanza para pagarla. Así pide el monto justo y no se sobreendeuda.
class PlanificadorInversionScreen extends StatefulWidget {
  const PlanificadorInversionScreen({super.key});

  @override
  State<PlanificadorInversionScreen> createState() => _PlanificadorInversionScreenState();
}

class _PlanificadorInversionScreenState extends State<PlanificadorInversionScreen> {
  String _rubro = insumosPorRubro.keys.first;
  final Map<Insumo, int> _canasta = {};
  double _aporte = 0;
  int _rotaciones = 4;
  int _plazo = 6;
  bool _resaltar = false;

  void _agregar(Insumo i) {
    HapticFeedback.selectionClick();
    setState(() => _canasta[i] = (_canasta[i] ?? 0) + 1);
  }

  void _quitar(Insumo i) {
    setState(() {
      final n = (_canasta[i] ?? 0) - 1;
      if (n <= 0) {
        _canasta.remove(i);
      } else {
        _canasta[i] = n;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = evaluarInversion(canasta: _canasta, aportePropio: _aporte, rotacionesMes: _rotaciones, plazo: _plazo);
    final insumos = insumosPorRubro[_rubro]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Planificador de inversión')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('Mantén presionado un producto y arrástralo a tu canasta. También puedes tocar el +.',
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          const Text('Rubro de tu negocio', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final k in insumosPorRubro.keys)
                ChoiceChip(
                  label: Text(k),
                  selected: _rubro == k,
                  onSelected: (_) => setState(() {
                    _rubro = k;
                    _canasta.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: insumos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, k) {
                final ins = insumos[k];
                final tarjeta = _TarjetaInsumo(insumo: ins, onAgregar: () => _agregar(ins));
                return LongPressDraggable<Insumo>(
                  data: ins,
                  hapticFeedbackOnStart: true,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(scale: 1.08, child: Opacity(opacity: 0.9, child: tarjeta)),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: tarjeta),
                  child: tarjeta,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          DragTarget<Insumo>(
            onWillAcceptWithDetails: (_) {
              setState(() => _resaltar = true);
              return true;
            },
            onLeave: (_) => setState(() => _resaltar = false),
            onAcceptWithDetails: (d) {
              _resaltar = false;
              _agregar(d.data);
            },
            builder: (context, candidatos, rechazados) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _resaltar ? AppColors.azul.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _resaltar ? AppColors.azul : Colors.grey.shade300,
                  width: _resaltar ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_basket_rounded, color: AppColors.azul),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Mi canasta de inversión', style: TextStyle(fontWeight: FontWeight.w700))),
                      if (_canasta.isNotEmpty)
                        TextButton(onPressed: () => setState(_canasta.clear), child: const Text('Vaciar')),
                    ],
                  ),
                  if (_canasta.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                        child: Text('Suelta aquí los productos',
                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    for (final e in _canasta.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(e.key.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.key.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${e.value} × ${fmtMoney(e.key.costo)} = ${fmtMoney(e.key.costo * e.value)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            IconButton(
                                onPressed: () => _quitar(e.key),
                                icon: const Icon(Icons.remove_circle_outline_rounded)),
                            Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            IconButton(
                                onPressed: () => _agregar(e.key),
                                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.azul)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          tarjetaBlanca(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pongo de mi bolsillo: ${fmtMoney(_aporte)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _aporte.clamp(0, 5000).toDouble(),
                  max: 5000,
                  divisions: 100,
                  onChanged: (v) => setState(() => _aporte = v),
                ),
                Text('Veces que vendo y repongo al mes: $_rotaciones',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _rotaciones.toDouble(),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  onChanged: (v) => setState(() => _rotaciones = v.round()),
                ),
                Text('Plazo del préstamo: $_plazo meses', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _plazo.toDouble(),
                  min: 1,
                  max: 24,
                  divisions: 23,
                  onChanged: (v) => setState(() => _plazo = v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_canasta.isNotEmpty) _resultado(context, r),
        ],
      ),
    );
  }

  Widget _resultado(BuildContext context, ResultadoInversion r) {
    final (color, icono, titulo, texto) = r.montoPrestamo == 0
        ? (AppColors.verde, Icons.savings_rounded, 'No necesitas préstamo',
            'Tu aporte cubre toda la inversión.')
        : r.conviene
            ? (AppColors.verde, Icons.thumb_up_alt_rounded, 'Te conviene',
                'Tu ganancia cubre la cuota con holgura.')
            : r.ajustado
                ? (AppColors.ambar, Icons.warning_amber_rounded, 'Ajustado',
                    'La ganancia apenas cubre la cuota. Sube el plazo, tu aporte o tus ventas.')
                : (AppColors.rojo, Icons.block_rounded, 'No te conviene así',
                    'La cuota sería mayor que tu ganancia. Reduce la compra o alarga el plazo.');
    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
                    Text(texto, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          filaDato('Inversión total', fmtMoney(r.inversion)),
          filaDato('Venta esperada', fmtMoney(r.ventaEsperada)),
          filaDato('Ganancia por vuelta', fmtMoney(r.gananciaPorRotacion)),
          filaDato('Ganancia al mes', fmtMoney(r.gananciaMensual)),
          filaDato('Préstamo necesario', fmtMoney(r.montoPrestamo), destacado: true),
          filaDato('Cuota mensual', r.cuota == 0 ? '—' : '${fmtMoney(r.cuota)} × $_plazo'),
          filaDato('Te queda al mes', fmtMoney(r.gananciaNeta)),
          if (r.mesesRecupero > 0) filaDato('Recuperas la inversión', 'en ${r.mesesRecupero} meses'),
          if (r.montoPrestamo > 0) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                Clipboard.setData(ClipboardData(text: r.montoPrestamo.toStringAsFixed(0)));
                tabCliente.value = tabSimular;
                Navigator.popUntil(context, (route) => route.isFirst);
                messenger.showSnackBar(SnackBar(
                  content: Text('Simula ${fmtMoney(r.montoPrestamo)} a $_plazo meses (monto copiado).'),
                ));
              },
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Simular este préstamo'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaInsumo extends StatelessWidget {
  final Insumo insumo;
  final VoidCallback onAgregar;
  const _TarjetaInsumo({required this.insumo, required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(insumo.emoji, style: const TextStyle(fontSize: 26)),
              const Spacer(),
              InkWell(
                onTap: onAgregar,
                borderRadius: BorderRadius.circular(20),
                child: const Icon(Icons.add_circle_rounded, color: AppColors.azul),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(insumo.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          const Spacer(),
          Text('Costo ${fmtMoney(insumo.costo)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          if (insumo.precioVenta > 0)
            Text('Vende ${fmtMoney(insumo.precioVenta)}',
                style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
