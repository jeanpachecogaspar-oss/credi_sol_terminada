import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'errores.dart';
import 'formato.dart';
import 'ideas_calculos.dart';
import 'ui_comun.dart';

/// IDEA DISRUPTIVA 4: Banca comunal (préstamo grupal solidario).
///
/// Muchos comerciantes de mercado no califican solos porque no tienen historial. Con la
/// banca comunal, de 3 a 5 vecinos o socios forman un grupo con un CÓDIGO, cada uno elige
/// su monto y todos se respaldan entre sí (garantía solidaria). Cuando el grupo está completo,
/// el creador lo envía al asesor, que lo aprueba o rechaza desde el panel web.
///
/// Firestore: `gruposComunales/{codigo}` (ver firestore.rules).
class BancaComunalScreen extends StatelessWidget {
  const BancaComunalScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('gruposComunales');

  Future<String> _miNombre() async {
    final u = FirebaseAuth.instance.currentUser!;
    try {
      final d = await FirebaseFirestore.instance.collection('usuarios').doc(u.uid).get();
      final n = (d.data()?['nombre'] ?? '').toString().trim();
      if (n.isNotEmpty) return n;
    } catch (_) {}
    return u.email ?? 'Integrante';
  }

  Future<void> _crear(BuildContext context) async {
    final datos = await showModalBottomSheet<(String, int, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => const _FormGrupo(crear: true),
    );
    if (datos == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final nombre = await _miNombre();
      String codigo = generarCodigoGrupo();
      for (var intento = 0; intento < 5; intento++) {
        final existe = await _col.doc(codigo).get();
        if (!existe.exists) break;
        codigo = generarCodigoGrupo();
      }
      await _col.doc(codigo).set({
        'nombre': datos.$1,
        'codigo': codigo,
        'creadorId': uid,
        'creadorNombre': nombre,
        'plazoMeses': datos.$2,
        'miembros': [uid],
        'detalle': {
          uid: {'nombre': nombre, 'monto': datos.$3},
        },
        'estado': 'Formando',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
      messenger.showSnackBar(SnackBar(content: Text('Grupo creado. Comparte el código $codigo con tus socios.')));
    } catch (e) {
      debugPrint('Crear grupo: $e');
      messenger.showSnackBar(SnackBar(content: Text('No se pudo crear el grupo. ${mensajeError(e)}')));
    }
  }

  Future<void> _unirme(BuildContext context) async {
    final datos = await showModalBottomSheet<(String, int, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => const _FormGrupo(crear: false),
    );
    if (datos == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final codigo = datos.$1.toUpperCase().trim();
    try {
      final nombre = await _miNombre();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final ref = _col.doc(codigo);
        final snap = await tx.get(ref);
        final d = snap.data();
        if (d == null) throw StateError('No existe un grupo con el código $codigo.');
        if (d['estado'] != 'Formando') throw StateError('Este grupo ya fue enviado al asesor.');
        final miembros = (d['miembros'] as List? ?? []).map((e) => e.toString()).toList();
        if (miembros.contains(uid)) throw StateError('Ya eres parte de este grupo.');
        if (miembros.length >= maxIntegrantesGrupo) {
          throw StateError('El grupo ya tiene $maxIntegrantesGrupo integrantes.');
        }
        tx.update(ref, {
          'miembros': FieldValue.arrayUnion([uid]),
          'detalle.$uid': {'nombre': nombre, 'monto': datos.$3},
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
      });
      messenger.showSnackBar(const SnackBar(content: Text('¡Te uniste al grupo!')));
    } catch (e) {
      debugPrint('Unirme al grupo: $e');
      messenger.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();
    return Scaffold(
      appBar: AppBar(title: const Text('Banca comunal')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.where('miembros', arrayContains: uid).snapshots(),
        builder: (context, snap) {
          final grupos = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              tarjetaBlanca(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.diversity_3_rounded, color: AppColors.azul, size: 30),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Pide en grupo y respáldense entre todos',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Forma un grupo de $minIntegrantesGrupo a $maxIntegrantesGrupo socios o vecinos de tu mercado. '
                      'Cada uno elige su monto y paga su propia cuota; si alguien se atrasa, el grupo lo respalda. '
                      'Ideal si es tu primer préstamo.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _crear(context),
                            icon: const Icon(Icons.group_add_rounded),
                            label: const Text('Crear grupo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _unirme(context),
                            icon: const Icon(Icons.vpn_key_rounded),
                            label: const Text('Unirme'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (snap.hasError)
                mensajeVacio(Icons.error_outline_rounded, 'No se pudieron cargar tus grupos', mensajeError(snap.error!))
              else if (!snap.hasData)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (grupos.isEmpty)
                mensajeVacio(Icons.groups_2_outlined, 'Aún no estás en un grupo',
                    'Crea uno y comparte el código, o únete con el código que te pasó un socio.')
              else
                for (final g in grupos) ...[
                  _TarjetaGrupo(doc: g, uid: uid),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaGrupo extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String uid;
  const _TarjetaGrupo({required this.doc, required this.uid});

  Future<void> _enviar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await doc.reference.update({
        'estado': 'Enviado',
        'fechaEnvio': FieldValue.serverTimestamp(),
      });
      messenger.showSnackBar(const SnackBar(content: Text('Grupo enviado al asesor. Te avisaremos su respuesta.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo enviar. ${mensajeError(e)}')));
    }
  }

  Future<void> _cambiarMonto(BuildContext context, double actual, String nombre) async {
    final nuevo = await showModalBottomSheet<(String, int, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => _FormGrupo(crear: false, soloMonto: true, montoInicial: actual),
    );
    if (nuevo == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await doc.reference.update({
        'detalle.$uid': {'nombre': nombre, 'monto': nuevo.$3},
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo cambiar. ${mensajeError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final codigo = doc.id;
    final estado = (d['estado'] ?? 'Formando').toString();
    final plazo = (d['plazoMeses'] as num?)?.toInt() ?? 12;
    final miembros = (d['miembros'] as List? ?? []).map((e) => e.toString()).toList();
    final detalle = (d['detalle'] as Map?)?.cast<String, dynamic>() ?? {};
    final esCreador = d['creadorId'] == uid;
    var total = 0.0, cuotaTotal = 0.0;
    for (final m in miembros) {
      final monto = aNum((detalle[m] as Map?)?['monto']);
      total += monto;
      cuotaTotal += cuotaIntegrante(monto, plazo);
    }
    final completo = miembros.length >= minIntegrantesGrupo;

    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((d['nombre'] ?? 'Grupo').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('$plazo meses · ${miembros.length}/$maxIntegrantesGrupo integrantes',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                  ],
                ),
              ),
              chipEstado(estado),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.azul.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('Código: '),
                  Text(codigo,
                      style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.azul)),
                  const Spacer(),
                  const Icon(Icons.copy_rounded, size: 18, color: AppColors.azul),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final m in miembros)
            Builder(builder: (context) {
              final info = (detalle[m] as Map?)?.cast<String, dynamic>() ?? {};
              final nombre = (info['nombre'] ?? 'Integrante').toString();
              final monto = aNum(info['monto']);
              final yo = m == uid;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: (yo ? AppColors.azul : AppColors.gris).withValues(alpha: 0.15),
                  child: Text(nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
                      style: TextStyle(color: yo ? AppColors.azul : AppColors.gris, fontWeight: FontWeight.w700)),
                ),
                title: Text(yo ? '$nombre (tú)' : nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${fmtMoney(monto)} · cuota ${fmtMoney(cuotaIntegrante(monto, plazo))}'),
                trailing: yo && estado == 'Formando'
                    ? IconButton(
                        tooltip: 'Cambiar mi monto',
                        onPressed: () => _cambiarMonto(context, monto, nombre),
                        icon: const Icon(Icons.edit_rounded, size: 20),
                      )
                    : (m == d['creadorId'] ? const Icon(Icons.star_rounded, color: AppColors.dorado) : null),
              );
            }),
          const Divider(height: 18),
          filaDato('Préstamo del grupo', fmtMoney(total), destacado: true),
          filaDato('Cuota del grupo', '${fmtMoney(cuotaTotal)} / mes'),
          if (estado == 'Rechazado' && (d['motivo'] ?? '').toString().isNotEmpty)
            filaDato('Motivo', d['motivo'].toString()),
          if (estado == 'Formando') ...[
            const SizedBox(height: 8),
            if (!completo)
              Text('Faltan ${minIntegrantesGrupo - miembros.length} integrante(s) para poder enviarlo.',
                  style: const TextStyle(color: AppColors.ambar, fontWeight: FontWeight.w600))
            else if (esCreador)
              ElevatedButton.icon(
                onPressed: () => _enviar(context),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Enviar al asesor'),
              )
            else
              Text('El creador del grupo lo enviará al asesor.', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

/// Formulario: crear (nombre + plazo + monto), unirse (código + monto) o solo cambiar el monto.
class _FormGrupo extends StatefulWidget {
  final bool crear;
  final bool soloMonto;
  final double? montoInicial;
  const _FormGrupo({required this.crear, this.soloMonto = false, this.montoInicial});

  @override
  State<_FormGrupo> createState() => _FormGrupoState();
}

class _FormGrupoState extends State<_FormGrupo> {
  final _form = GlobalKey<FormState>();
  final _texto = TextEditingController();
  late double _monto = widget.montoInicial ?? 1000;
  int _plazo = 6;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.soloMonto ? 'Cambiar mi monto' : (widget.crear ? 'Crear grupo' : 'Unirme a un grupo');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (!widget.soloMonto)
              TextFormField(
                controller: _texto,
                autofocus: true,
                textCapitalization: widget.crear ? TextCapitalization.sentences : TextCapitalization.characters,
                maxLength: widget.crear ? 40 : 6,
                decoration: InputDecoration(
                  labelText: widget.crear ? 'Nombre del grupo (ej. Socias del Mercado Modelo)' : 'Código del grupo',
                  prefixIcon: Icon(widget.crear ? Icons.groups_rounded : Icons.vpn_key_rounded),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (widget.crear) return t.length < 3 ? 'Escribe un nombre' : null;
                  return RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(t) ? null : 'El código tiene 6 letras o números';
                },
              ),
            if (widget.crear) ...[
              Text('Plazo del grupo: $_plazo meses', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: _plazo.toDouble(),
                min: 3,
                max: 12,
                divisions: 9,
                onChanged: (v) => setState(() => _plazo = v.round()),
              ),
            ],
            Text('Mi parte: ${fmtMoney(_monto)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _monto,
              min: ConfigPrestamos.montoMinimo,
              max: 3000,
              divisions: 27,
              onChanged: (v) => setState(() => _monto = (v / 100).round() * 100.0),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (!(_form.currentState?.validate() ?? false)) return;
                Navigator.pop(context, (_texto.text.trim(), _plazo, _monto));
              },
              child: Text(widget.soloMonto ? 'Guardar' : (widget.crear ? 'Crear grupo' : 'Unirme')),
            ),
          ],
        ),
      ),
    );
  }
}
