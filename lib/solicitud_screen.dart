import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'cronograma.dart';
import 'datos_personales.dart';
import 'errores.dart';
import 'formato.dart';
import 'apis_peru.dart';
import 'location_service.dart';
import 'navegacion_cliente.dart';
import 'ubicar_negocio_screen.dart';
import 'validacion_identidad.dart';

/// Solicitud de préstamo en 3 pasos:
/// 1. Datos personales  2. Fotos (solo cámara)  3. Resumen, consentimiento y envío.
/// Los datos se guardan en `usuarios/{uid}` y se reutilizan en futuras solicitudes.
class SolicitudScreen extends StatefulWidget {
  final double monto;
  final double tasa;
  final bool tasaAnual;
  final int plazo;
  final DateTime fechaInicio;

  /// Producto financiero elegido en el catálogo (opcional).
  final String? productoId;
  final String? productoNombre;

  /// Se llama cuando la solicitud se envió (ej. para quitarla de "Mi selección").
  final VoidCallback? alEnviar;

  const SolicitudScreen({
    super.key,
    required this.monto,
    required this.tasa,
    required this.tasaAnual,
    required this.plazo,
    required this.fechaInicio,
    this.productoId,
    this.productoNombre,
    this.alEnviar,
  });

  @override
  State<SolicitudScreen> createState() => _SolicitudScreenState();
}

class _SolicitudScreenState extends State<SolicitudScreen> {
  static const Color azul = AppColors.azul;
  static const List<String> _pasos = ['Tus datos', 'Fotos', 'Confirmar'];

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _distritoCtrl = TextEditingController();
  final _ocupacionCtrl = TextEditingController();
  final _ingresoCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  DateTime? _nacimiento;
  String? _errorNacimiento;

  // RUC del negocio (opcional), validado con SUNAT vía APIsPERU.
  final _rucCtrl = TextEditingController();
  EmpresaRuc? _empresa;
  bool _consultandoRuc = false;

  /// Dónde queda el negocio (lo marca el cliente en el mapa; el asesor lo usa para la visita).
  UbicacionNegocio? _negocio;
  String? _errorRuc;

  /// Fotos tomadas en esta sesión (JPEG comprimido).
  final Map<String, Uint8List> _fotosNuevas = {};

  /// Resultado de la validación automática de cada foto nueva (ML Kit + GPS).
  final Map<String, ResultadoValidacion> _validaciones = {};

  /// Foto que se está analizando (para mostrar "Analizando…").
  String? _analizando;

  /// Fotos ya registradas antes (tipo -> fecha), según `fotosVerificacion` del perfil.
  final Map<String, DateTime?> _fotosExistentes = {};

  late final List<CuotaCalc> _cuotas;
  int _paso = 0;
  bool _cargandoPerfil = true;
  String? _errorPerfil;
  bool _tomandoFoto = false;
  bool _aceptoDatos = false;
  bool _aceptoCondiciones = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cuotas = generarCronograma(
      monto: widget.monto,
      tasa: widget.tasa,
      tasaAnual: widget.tasaAnual,
      plazo: widget.plazo,
      fechaInicio: widget.fechaInicio,
    );
    if (widget.productoNombre != null) _destinoCtrl.text = widget.productoNombre!;
    _cargarPerfil();
  }

  Future<void> _consultarRuc() async {
    final ruc = _rucCtrl.text.trim();
    if (!RegExp(r'^(10|15|17|20)\d{9}$').hasMatch(ruc)) {
      setState(() => _errorRuc = 'El RUC tiene 11 dígitos y empieza con 10 o 20');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _consultandoRuc = true;
      _errorRuc = null;
      _empresa = null;
    });
    try {
      final e = await ApisPeru.ruc(ruc);
      if (!mounted) return;
      setState(() {
        _empresa = e;
        if (!e.activoHabido) _errorRuc = 'SUNAT: ${e.estado} / ${e.condicion}. El asesor lo revisará.';
      });
    } on ApisPeruError catch (e) {
      if (mounted) setState(() => _errorRuc = e.mensaje);
    } finally {
      if (mounted) setState(() => _consultandoRuc = false);
    }
  }

  Widget _campoNegocio() {
    final n = _negocio;
    return Material(
      color: n == null ? AppColors.campo : AppColors.verde.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(n == null ? Icons.add_location_alt_outlined : Icons.location_on_rounded,
            color: n == null ? azul : AppColors.verde),
        title: Text(n == null ? 'Ubica tu negocio en el mapa' : 'Negocio ubicado'),
        subtitle: Text(
          n == null
              ? 'Recomendado: tu asesor lo usará para visitarte. No rastreamos tu ubicación.'
              : (n.direccion.isEmpty ? 'Punto marcado en el mapa' : n.direccion),
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final r = await Navigator.push<UbicacionNegocio>(
            context,
            MaterialPageRoute(builder: (_) => UbicarNegocioScreen(inicial: _negocio)),
          );
          if (r != null && mounted) setState(() => _negocio = r);
        },
      ),
    );
  }

  Widget _campoRuc() {
    final e = _empresa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _rucCtrl,
                keyboardType: TextInputType.number,
                maxLength: 11,
                onChanged: (v) {
                  if (_empresa != null || _errorRuc != null) {
                    setState(() {
                      _empresa = null;
                      _errorRuc = null;
                    });
                  }
                  if (v.trim().length == 11) _consultarRuc();
                },
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'RUC de tu negocio (opcional)',
                  errorText: _errorRuc,
                  errorMaxLines: 3,
                  prefixIcon: const Icon(Icons.storefront_outlined, color: azul),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _consultandoRuc ? null : _consultarRuc,
                child: _consultandoRuc
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Validar'),
              ),
            ),
          ],
        ),
        if (e != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.verde, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${e.razonSocial}${e.direccion.isNotEmpty ? '\n${e.direccion}' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _dniCtrl, _celularCtrl, _direccionCtrl,
      _distritoCtrl, _ocupacionCtrl, _ingresoCtrl, _destinoCtrl, _rucCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => totalCuotas(_cuotas);
  double get _intereses => totalIntereses(_cuotas);
  double get _tcea => double.parse(
        calcularTcea(widget.monto, _cuotas.map((c) => c.cuota).toList()).toStringAsFixed(2),
      );

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  // ---------------- Carga de datos guardados ----------------

  Future<void> _cargarPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _cargandoPerfil = true;
      _errorPerfil = null;
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final d = snap.data() ?? {};
      _nombreCtrl.text = (d['nombre'] ?? '').toString();
      _dniCtrl.text = (d['dni'] ?? '').toString();
      _celularCtrl.text = (d['celular'] ?? '').toString();
      _direccionCtrl.text = (d['direccion'] ?? '').toString();
      _distritoCtrl.text = (d['distrito'] ?? '').toString();
      _ocupacionCtrl.text = (d['ocupacion'] ?? '').toString();
      if (d['ingresoMensual'] is num) {
        _ingresoCtrl.text = (d['ingresoMensual'] as num).toStringAsFixed(0);
      }
      final nac = d['fechaNacimiento'];
      if (nac is Timestamp) _nacimiento = nac.toDate();
      final fotos = d['fotosVerificacion'];
      if (fotos is Map) {
        for (final f in fotosRequeridas) {
          if (fotos.containsKey(f.id)) {
            final v = fotos[f.id];
            _fotosExistentes[f.id] = v is Timestamp ? v.toDate() : null;
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
      _errorPerfil = mensajeError(e);
    } finally {
      if (mounted) setState(() => _cargandoPerfil = false);
    }
  }

  // ---------------- Paso 1 ----------------

  Future<void> _elegirNacimiento() async {
    final hoy = DateTime.now();
    final limite = DateTime(hoy.year - 18, hoy.month, hoy.day);
    final f = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 30, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: limite,
      helpText: 'Fecha de nacimiento',
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (f != null) {
      setState(() {
        _nacimiento = f;
        _errorNacimiento = null;
      });
    }
  }

  bool _validarPaso1() {
    final okForm = _formKey.currentState?.validate() ?? false;
    String? errNac;
    if (_nacimiento == null) {
      errNac = 'Selecciona tu fecha de nacimiento';
    } else if (edad(_nacimiento!) < 18) {
      errNac = 'Debes ser mayor de 18 años';
    }
    setState(() => _errorNacimiento = errNac);
    return okForm && errNac == null;
  }

  // ---------------- Paso 2 ----------------

  Future<void> _tomarFoto(TipoFoto tipo) async {
    final esRecibo = tipo.id == 'recibo_servicio';
    var reintentar = false;
    setState(() => _tomandoFoto = true);
    try {
      // Solo cámara (nunca galería). image_picker comprime el JPEG en el celular.
      // El recibo se toma con más resolución para poder leer su texto.
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: tipo.frontal ? CameraDevice.front : CameraDevice.rear,
        maxWidth: esRecibo ? 1280 : 1024,
        maxHeight: esRecibo ? 1280 : 1024,
        imageQuality: esRecibo ? 45 : 55,
        requestFullMetadata: false,
      );
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      if (bytes.length > maxBytesFoto) {
        _msg('La foto quedó muy pesada (${(bytes.length / 1024).round()} KB). '
            'Tómala de nuevo sobre un fondo liso y con buena luz.');
        return;
      }

      // Validación automática en el celular antes de aceptar la foto.
      setState(() => _analizando = tipo.id);
      final resultado = await _validar(tipo, foto.path);
      if (!mounted) return;
      setState(() => _analizando = null);
      if (!resultado.aceptada) {
        reintentar = await _avisoRechazo(tipo, resultado.mensaje);
        return;
      }
      setState(() {
        _fotosNuevas[tipo.id] = bytes;
        _validaciones[tipo.id] = resultado;
      });
      if (resultado.estado == 'revisar') _msg(resultado.mensaje);
    } on PlatformException catch (e) {
      debugPrint('Cámara: $e');
      _msg(e.code == 'camera_access_denied'
          ? 'Permite el acceso a la cámara desde los ajustes del celular.'
          : 'No se pudo abrir la cámara. Inténtalo de nuevo.');
    } catch (e) {
      debugPrint('Cámara: $e');
      _msg('No se pudo tomar la foto. Inténtalo de nuevo.');
    } finally {
      if (mounted) {
        setState(() {
          _tomandoFoto = false;
          _analizando = null;
        });
        if (reintentar) _tomarFoto(tipo);
      }
    }
  }

  Future<ResultadoValidacion> _validar(TipoFoto tipo, String ruta) async {
    final dni = _dniCtrl.text.trim();
    switch (tipo.id) {
      case 'selfie':
        return ValidadorIdentidad.selfie(ruta);
      case 'dni_frontal':
        return ValidadorIdentidad.dniFrente(ruta, dni);
      case 'dni_posterior':
        return ValidadorIdentidad.dniReverso(ruta, dni);
      case 'recibo_servicio':
        Position? gps;
        try {
          gps = await LocationService.posicionActual();
        } catch (e) {
          debugPrint('GPS para el recibo: $e');
        }
        return ValidadorIdentidad.recibo(
          ruta,
          direccion: _direccionCtrl.text.trim(),
          distrito: _distritoCtrl.text.trim(),
          gps: gps,
        );
      default:
        return const ResultadoValidacion(true, 'revisar', '');
    }
  }

  /// Explica por qué se rechazó la foto. Devuelve true si el cliente quiere tomarla de nuevo.
  Future<bool> _avisoRechazo(TipoFoto tipo, String mensaje) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: AppColors.rojo, size: 44),
        title: Text('${tipo.titulo}: foto no válida'),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tomar de nuevo')),
        ],
      ),
    );
    return r == true;
  }

  bool _tieneFoto(String id) => _fotosNuevas.containsKey(id) || _fotosExistentes.containsKey(id);

  // ---------------- Navegación ----------------

  void _siguiente() {
    FocusScope.of(context).unfocus();
    if (_paso == 0 && !_validarPaso1()) {
      _msg('Revisa los datos marcados en rojo');
      return;
    }
    if (_paso == 1) {
      final faltan = fotosRequeridas.where((f) => !_tieneFoto(f.id)).map((f) => f.titulo).toList();
      if (faltan.isNotEmpty) {
        _msg('Falta: ${faltan.join(', ')}');
        return;
      }
    }
    setState(() => _paso++);
  }

  void _atras() {
    if (_paso > 0) setState(() => _paso--);
  }

  // ---------------- Paso 3: envío ----------------

  Future<void> _enviar() async {
    if (!_aceptoDatos) {
      _msg('Debes autorizar el tratamiento de tus datos personales para continuar');
      return;
    }
    if (!_aceptoCondiciones) {
      _msg('Confirma que los datos son correctos para continuar');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final db = FirebaseFirestore.instance;

      final pendientes = await db
          .collection('prestamos')
          .where('clienteId', isEqualTo: user.uid)
          .where('estado', isEqualTo: 'Pendiente')
          .limit(1)
          .get();
      if (pendientes.docs.isNotEmpty) {
        _msg('Ya tienes una solicitud en revisión. Espera su respuesta.');
        return;
      }

      final perfilRef = db.collection('usuarios').doc(user.uid);
      final nombre = _nombreCtrl.text.trim();
      final batch = db.batch();

      // 1. Datos personales + consentimiento (se reutilizan en futuras solicitudes).
      batch.update(perfilRef, {
        'nombre': nombre,
        'dni': _dniCtrl.text.trim(),
        'fechaNacimiento': Timestamp.fromDate(DateTime(_nacimiento!.year, _nacimiento!.month, _nacimiento!.day)),
        'celular': _celularCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'distrito': _distritoCtrl.text.trim(),
        'ocupacion': _ocupacionCtrl.text.trim(),
        'ingresoMensual': double.parse(_ingresoCtrl.text.trim().replaceAll(',', '.')),
        'consentimientoDatos': true,
        'fechaConsentimiento': FieldValue.serverTimestamp(),
        'versionConsentimiento': ConfigEmpresa.versionConsentimiento,
        'fechaActualizacion': FieldValue.serverTimestamp(),
        for (final id in _fotosNuevas.keys) 'fotosVerificacion.$id': FieldValue.serverTimestamp(),
      });

      // 2. Fotos nuevas (base64; ver docs/migracion_storage.md).
      for (final e in _fotosNuevas.entries) {
        batch.set(perfilRef.collection('documentos').doc(e.key), {
          'tipo': e.key,
          'imagenBase64': base64Encode(e.value),
          'mime': 'image/jpeg',
          'bytes': e.value.length,
          'fecha': FieldValue.serverTimestamp(),
          if (_validaciones[e.key] != null) 'validacion': _validaciones[e.key]!.aMapa(),
        });
      }

      // 3. La solicitud. Las cuotas se generan al aprobar.
      batch.set(db.collection('prestamos').doc(), {
        'clienteId': user.uid,
        'clienteNombre': nombre,
        'clienteEmail': user.email ?? '',
        'monto': widget.monto,
        'tasa': widget.tasa,
        'tasaAnual': widget.tasaAnual,
        'plazoMeses': widget.plazo,
        'cuotaMensual': _cuotas.first.cuota,
        'totalAPagar': _total,
        'totalIntereses': _intereses,
        'saldoPendiente': _total,
        'tcea': _tcea,
        'destino': _destinoCtrl.text.trim(),
        if (widget.productoId != null) 'productoId': widget.productoId,
        if (widget.productoNombre != null) 'productoNombre': widget.productoNombre,
        if (_negocio != null) 'ubicacionNegocio': _negocio!.aMapa(),
        if (_empresa != null) 'ruc': _empresa!.ruc,
        if (_empresa != null) 'razonSocial': _empresa!.razonSocial,
        'estado': 'Pendiente',
        'fechaSolicitud': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      widget.alEnviar?.call();
      if (!mounted) return;
      tabCliente.value = tabPrestamos;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Un administrador la revisará pronto.')),
      );
    } catch (e) {
      debugPrint('Error al enviar solicitud: $e');
      _msg('No se pudo enviar la solicitud. ${mensajeError(e)}');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0 && !_enviando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_enviando) _atras();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Solicitar préstamo')),
        body: _cargandoPerfil
            ? const Center(child: CircularProgressIndicator())
            : _errorPerfil != null
                ? _errorCarga()
                : Column(
                    children: [
                      _indicador(),
                      Expanded(
                        child: switch (_paso) {
                          0 => _paso1(),
                          1 => _paso2(),
                          _ => _paso3(),
                        },
                      ),
                      _barraInferior(),
                    ],
                  ),
      ),
    );
  }

  Widget _errorCarga() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_errorPerfil!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargarPerfil, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _indicador() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          for (var i = 0; i < _pasos.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _pasos.length - 1 ? 8 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= _paso ? azul : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${i + 1}. ${_pasos[i]}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: i == _paso ? FontWeight.bold : FontWeight.w500,
                        color: i <= _paso ? AppColors.texto : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barraInferior() {
    final ultimo = _paso == _pasos.length - 1;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
        ),
        child: Row(
          children: [
            if (_paso > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _enviando ? null : _atras,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _enviando || _tomandoFoto ? null : (ultimo ? _enviar : _siguiente),
                child: _enviando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : Text(ultimo ? 'Enviar solicitud' : 'Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Paso 1: datos personales ----------

  Widget _paso1() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Estos datos se guardan en tu perfil y se usarán en tus próximas solicitudes.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          _campo(_nombreCtrl, 'Nombres y apellidos', Icons.person_outline_rounded,
              validator: validarNombre, mayusculas: true),
          _campo(_dniCtrl, 'DNI', Icons.badge_outlined,
              validator: validarDni, numerico: true, maxLength: 8),
          _selectorNacimiento(),
          _campo(_celularCtrl, 'Celular', Icons.phone_android_rounded,
              validator: validarCelular, numerico: true, maxLength: 9),
          _campo(_direccionCtrl, 'Dirección', Icons.home_outlined,
              validator: (v) => validarTexto(v, 'dirección', max: 200)),
          _campo(_distritoCtrl, 'Distrito', Icons.location_city_rounded,
              validator: (v) => validarTexto(v, 'distrito')),
          _campo(_ocupacionCtrl, 'Ocupación', Icons.work_outline_rounded,
              validator: (v) => validarTexto(v, 'ocupación')),
          _campo(_ingresoCtrl, 'Ingreso mensual aproximado', Icons.payments_outlined,
              validator: validarIngreso, decimal: true, prefijo: 'S/ '),
          _campoRuc(),
          _campoNegocio(),
        ],
      ),
    );
  }

  Widget _campo(
    TextEditingController c,
    String label,
    IconData icono, {
    required String? Function(String?) validator,
    bool numerico = false,
    bool decimal = false,
    bool mayusculas = false,
    int? maxLength,
    String? prefijo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        validator: validator,
        maxLength: maxLength,
        textCapitalization: mayusculas ? TextCapitalization.words : TextCapitalization.sentences,
        keyboardType: numerico
            ? TextInputType.number
            : decimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
        inputFormatters: [
          if (numerico) FilteringTextInputFormatter.digitsOnly,
          if (decimal) FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefijo,
          counterText: '',
          prefixIcon: Icon(icono, color: azul, size: 20),
        ),
      ),
    );
  }

  Widget _selectorNacimiento() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _elegirNacimiento,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            errorText: _errorNacimiento,
            prefixIcon: const Icon(Icons.cake_outlined, color: azul, size: 20),
          ),
          child: Text(
            _nacimiento == null ? 'Seleccionar' : '${fmtFecha(_nacimiento!)} (${edad(_nacimiento!)} años)',
            style: TextStyle(fontSize: 15, color: _nacimiento == null ? Colors.grey.shade500 : null),
          ),
        ),
      ),
    );
  }

  // ---------- Paso 2: fotos ----------

  Widget _paso2() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Toma las fotos con la cámara del celular. La app revisa cada foto al instante (rostro, número de DNI '
          'y dirección del recibo frente a tu GPS). Solo las verá el personal que evalúa tu solicitud.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
        ),
        const SizedBox(height: 16),
        for (final f in fotosRequeridas) ...[
          _tarjetaFoto(f),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _tarjetaFoto(TipoFoto tipo) {
    final nueva = _fotosNuevas[tipo.id];
    final existe = _fotosExistentes.containsKey(tipo.id);
    final fechaExistente = _fotosExistentes[tipo.id];
    final validacion = _validaciones[tipo.id];
    final lista = nueva != null || existe;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lista ? AppColors.verde.withValues(alpha: 0.5) : const Color(0xFFE8ECF3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: AppColors.campo,
              child: nueva != null
                  ? Image.memory(nueva, fit: BoxFit.cover)
                  : Icon(
                      existe
                          ? Icons.check_circle_rounded
                          : (tipo.frontal
                              ? Icons.face_rounded
                              : (tipo.id == 'recibo_servicio' ? Icons.receipt_long_outlined : Icons.badge_outlined)),
                      color: existe ? AppColors.verde : Colors.grey.shade400,
                      size: 34,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tipo.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                if (_analizando == tipo.id)
                  Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text('Analizando la foto…', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                    ],
                  )
                else if (validacion != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        validacion.estado == 'verificado' ? Icons.verified_rounded : Icons.info_outline_rounded,
                        size: 16,
                        color: validacion.estado == 'verificado' ? AppColors.verde : AppColors.ambar,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          validacion.mensaje,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: validacion.estado == 'verificado' ? AppColors.verde : AppColors.ambar,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    nueva != null
                        ? 'Foto lista (${(nueva.length / 1024).round()} KB)'
                        : existe
                            ? 'Registrada${fechaExistente != null ? ' el ${fmtFecha(fechaExistente)}' : ''}. Puedes reemplazarla.'
                            : tipo.instruccion,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: _tomandoFoto ? null : () => _tomarFoto(tipo),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: Text(lista ? 'Tomar de nuevo' : 'Tomar foto'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Paso 3: resumen y consentimiento ----------

  Widget _paso3() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _tarjeta(
          'Tu préstamo',
          [
            _fila('Monto solicitado', fmtMoney(widget.monto), destacado: true),
            _fila('Tasa', '${widget.tasa}% ${widget.tasaAnual ? 'anual (TEA)' : 'mensual'}'),
            _fila('Plazo', '${widget.plazo} meses'),
            _fila('Cuota mensual', fmtMoney(_cuotas.first.cuota)),
            _fila('Intereses totales', fmtMoney(_intereses)),
            _fila('TCEA', '${_tcea.toStringAsFixed(2)}%'),
            _fila('Total a pagar', fmtMoney(_total), destacado: true),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sin comisiones ni seguros. Las fechas de pago se calculan desde el día en que se aprueba tu préstamo.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        _tarjeta(
          'Tus datos',
          [
            if (widget.productoNombre != null) _fila('Producto', widget.productoNombre!),
            if (_empresa != null) _fila('Negocio', '${_empresa!.razonSocial} (RUC ${_empresa!.ruc})'),
            if (_negocio != null) _fila('Ubicación', _negocio!.direccion.isEmpty ? 'Marcada en el mapa' : _negocio!.direccion),
            _fila('Nombre', _nombreCtrl.text.trim()),
            _fila('DNI', _dniCtrl.text.trim()),
            _fila('Celular', _celularCtrl.text.trim()),
            _fila('Distrito', _distritoCtrl.text.trim()),
            _fila('Ocupación', _ocupacionCtrl.text.trim()),
            _fila('Fotos', '${fotosRequeridas.where((f) => _tieneFoto(f.id)).length} de ${fotosRequeridas.length}'),
          ],
          accion: TextButton(onPressed: () => setState(() => _paso = 0), child: const Text('Editar')),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _destinoCtrl,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: '¿Para qué usarás el préstamo? (opcional)',
            prefixIcon: Icon(Icons.edit_note_rounded, color: azul),
          ),
        ),
        const SizedBox(height: 4),
        _check(
          _aceptoDatos,
          (v) => setState(() => _aceptoDatos = v),
          'Autorizo el tratamiento de mis datos personales.',
          detalle: textoConsentimiento(),
        ),
        _check(
          _aceptoCondiciones,
          (v) => setState(() => _aceptoCondiciones = v),
          'Confirmo que mis datos son correctos y entiendo que el préstamo está sujeto a aprobación.',
        ),
      ],
    );
  }

  Widget _tarjeta(String titulo, List<Widget> filas, {Widget? accion}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: azul.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (accion != null) accion,
            ],
          ),
          ...filas,
        ],
      ),
    );
  }

  Widget _check(bool valor, ValueChanged<bool> onChanged, String texto, {String? detalle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!valor),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: valor, activeColor: azul, onChanged: (v) => onChanged(v ?? false)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(texto, style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        if (detalle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 0, 8),
            child: Text(detalle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
          ),
      ],
    );
  }

  Widget _fila(String titulo, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: destacado ? 17 : 14.5,
                fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
                color: destacado ? azul : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
