import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'cronograma.dart';
import 'formato.dart';
import 'ideas_calculos.dart';
import 'soporte.dart';
import 'ui_comun.dart';

/// IDEA DISRUPTIVA 2: Cuotas por temporada.
///
/// Los negocios de Huancayo no venden igual todo el año (campaña escolar, Navidad, cosecha).
/// El cliente marca sus meses de venta ALTA, NORMAL o BAJA y la app arma un cronograma que
/// cobra más cuando vende más y menos cuando vende menos, con la misma tasa. Lo compara con
/// la cuota fija y permite pedirlo al asesor por WhatsApp.
class CuotasTemporadaScreen extends StatefulWidget {
  const CuotasTemporadaScreen({super.key});

  @override
  State<CuotasTemporadaScreen> createState() => _CuotasTemporadaScreenState();
}

class _CuotasTemporadaScreenState extends State<CuotasTemporadaScreen> {
  static const _meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
  double _monto = 3000;
  int _plazo = 12;
  String _rubro = rubrosTemporada.first;
  late List<Temporada> _temporadas;
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    _aplicarRubro();
  }

  /// Mes calendario (1–12) de la cuota número [n] (1 = primer mes después del desembolso).
  int _mesDeCuota(int n) => sumarMeses(_inicio, n).month;

  void _aplicarRubro() {
    _temporadas = List.generate(_plazo, (k) => temporadaSugerida(_rubro, _mesDeCuota(k + 1)));
  }

  void _cambiarPlazo(int p) {
    setState(() {
      _plazo = p;
      if (_temporadas.length > p) {
        _temporadas = _temporadas.sublist(0, p);
      } else {
        for (var k = _temporadas.length; k < p; k++) {
          _temporadas.add(temporadaSugerida(_rubro, _mesDeCuota(k + 1)));
        }
      }
    });
  }

  Color _color(Temporada t) => switch (t) {
        Temporada.alta => AppColors.verde,
        Temporada.normal => AppColors.azul,
        Temporada.baja => AppColors.ambar,
      };

  @override
  Widget build(BuildContext context) {
    final flex = cronogramaPorTemporada(monto: _monto, meses: _temporadas, fechaInicio: _inicio);
    final fijo = generarCronograma(
      monto: _monto,
      tasa: ConfigPrestamos.tasa,
      tasaAnual: ConfigPrestamos.tasaAnual,
      plazo: _plazo,
      fechaInicio: _inicio,
    );
    final maxCuota = flex.fold(0.0, (m, c) => c.cuota > m ? c.cuota : m);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuotas por temporada')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('Paga más cuando vendes más y menos en tus meses flojos. Toca un mes para cambiarlo.',
              style: TextStyle(color: Paleta.gris700)),
          const SizedBox(height: 12),
          tarjetaBlanca(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monto: ${fmtMoney(_monto)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _monto,
                  min: ConfigPrestamos.montoMinimo,
                  max: ConfigPrestamos.montoMaximo,
                  divisions: ((ConfigPrestamos.montoMaximo - ConfigPrestamos.montoMinimo) / 100).round(),
                  onChanged: (v) => setState(() => _monto = (v / 100).round() * 100.0),
                ),
                Text('Plazo: $_plazo meses', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _plazo.toDouble(),
                  min: 3,
                  max: ConfigPrestamos.plazoMaximo.toDouble(),
                  divisions: ConfigPrestamos.plazoMaximo - 3,
                  onChanged: (v) => _cambiarPlazo(v.round()),
                ),
                const Text('Mi rubro', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final r in rubrosTemporada)
                      ChoiceChip(
                        label: Text(r),
                        selected: _rubro == r,
                        onSelected: (_) => setState(() {
                          _rubro = r;
                          _aplicarRubro();
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final t in Temporada.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 12, height: 12, decoration: BoxDecoration(color: _color(t), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${t.nombre} (×${t.factor})', style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Barras: una por cuota; la altura es el monto. Al tocar, cambia la temporada.
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: flex.length,
              itemBuilder: (context, k) {
                final c = flex[k];
                final t = _temporadas[k];
                final alto = maxCuota == 0 ? 0.0 : (c.cuota / maxCuota) * 110;
                return GestureDetector(
                  onTap: () => setState(() => _temporadas[k] = t.siguiente),
                  child: Container(
                    width: 46,
                    margin: const EdgeInsets.only(right: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(
                          child: Text(ocultarMontos ? '••' : c.cuota.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: alto,
                          decoration: BoxDecoration(
                            color: _color(t),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_meses[_mesDeCuota(k + 1) - 1], style: const TextStyle(fontSize: 11)),
                        Text('${k + 1}', style: TextStyle(fontSize: 10, color: Paleta.gris500)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          tarjetaBlanca(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _comparar('Cuota fija', fmtMoney(fijo.first.cuota), totalCuotas(fijo))),
                    Container(width: 1, height: 60, color: Paleta.gris300),
                    Expanded(
                      child: _comparar(
                        'Por temporada',
                        flex.isEmpty
                            ? '—'
                            : '${fmtMoney(flex.map((c) => c.cuota).reduce((a, b) => a < b ? a : b))} – ${fmtMoney(maxCuota)}',
                        totalCuotas(flex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Misma tasa (${ConfigPrestamos.descripcionTasa}). Si pagas más al inicio, pagas menos intereses; '
                  'si dejas los meses fuertes para el final, pagas un poco más.',
                  style: TextStyle(fontSize: 12, color: Paleta.gris600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              final detalle = [
                for (var k = 0; k < flex.length; k++)
                  '${k + 1}. ${_meses[_mesDeCuota(k + 1) - 1]}: S/ ${flex[k].cuota.toStringAsFixed(2)} (${_temporadas[k].nombre})',
              ].join('\n');
              abrirWhatsApp(
                context,
                mensaje: 'Hola, quiero un préstamo de S/ ${_monto.toStringAsFixed(0)} a $_plazo meses con CUOTAS POR TEMPORADA '
                '(rubro: $_rubro):\n$detalle',
              );
            },
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Pedir este plan a mi asesor'),
          ),
        ],
      ),
    );
  }

  Widget _comparar(String titulo, String cuota, double total) {
    return Column(
      children: [
        Text(titulo, style: TextStyle(color: Paleta.gris600, fontSize: 12.5)),
        const SizedBox(height: 4),
        FittedBox(child: Text(cuota, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        const SizedBox(height: 2),
        Text('Total ${fmtMoney(total)}', style: TextStyle(fontSize: 12, color: Paleta.gris700)),
      ],
    );
  }
}
