import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'config_prestamos.dart';
import 'formato.dart';
import 'ui_comun.dart';

/// Fotos de verificación. Se guardan en `usuarios/{uid}/documentos/{tipo}`
/// como JPEG en base64, porque el plan Spark no incluye Firebase Storage.
/// Ver docs/migracion_storage.md.
class TipoFoto {
  final String id;
  final String titulo;
  final String instruccion;
  final bool frontal;
  const TipoFoto(this.id, this.titulo, this.instruccion, {this.frontal = false});
}

const List<TipoFoto> fotosRequeridas = [
  TipoFoto('selfie', 'Selfie', 'Tu rostro de frente, con buena luz y sin lentes oscuros.', frontal: true),
  TipoFoto('dni_frontal', 'DNI (frente)', 'La cara del DNI con tu foto. Que se lean todos los datos.'),
  TipoFoto('dni_posterior', 'DNI (reverso)', 'La parte de atrás del DNI, completa y sin reflejos.'),
  TipoFoto('recibo_servicio', 'Recibo de luz o agua',
      'Un recibo reciente de tu domicilio, completo y legible. Lo comparamos con tu dirección y tu GPS.'),
];

/// Límite de la imagen ya comprimida. En base64 ocupa ~4/3 (≈ 240 000 caracteres),
/// por debajo de los 250 000 que permiten las reglas de Firestore.
const int maxBytesFoto = 180 * 1024;

const List<String> camposDatosPersonales = [
  'nombre', 'dni', 'fechaNacimiento', 'celular', 'direccion', 'distrito', 'ocupacion', 'ingresoMensual',
];

// ----------------- Validaciones -----------------

String? validarNombre(String? v) {
  final t = (v ?? '').trim();
  if (t.length < 5 || !t.contains(' ')) return 'Escribe tus nombres y apellidos';
  if (t.length > 100) return 'Máximo 100 caracteres';
  return null;
}

String? validarDni(String? v) =>
    RegExp(r'^[0-9]{8}$').hasMatch((v ?? '').trim()) ? null : 'El DNI debe tener 8 dígitos';

String? validarCelular(String? v) =>
    RegExp(r'^9[0-9]{8}$').hasMatch((v ?? '').trim()) ? null : 'Celular de 9 dígitos que empiece con 9';

int edad(DateTime nacimiento, [DateTime? hoy]) {
  final h = hoy ?? DateTime.now();
  var e = h.year - nacimiento.year;
  if (h.month < nacimiento.month || (h.month == nacimiento.month && h.day < nacimiento.day)) e--;
  return e;
}

String? validarTexto(String? v, String campo, {int max = 100}) {
  final t = (v ?? '').trim();
  if (t.length < 3) return 'Ingresa tu $campo';
  if (t.length > max) return 'Máximo $max caracteres';
  return null;
}

String? validarIngreso(String? v) {
  final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
  if (n == null || n <= 0) return 'Ingresa tu ingreso mensual aproximado';
  if (n > 1000000) return 'Revisa el monto';
  return null;
}

/// True si el perfil ya tiene todos los datos personales que pide la solicitud.
bool perfilCompleto(Map<String, dynamic>? d) =>
    d != null && camposDatosPersonales.every((c) => d[c] != null && d[c].toString().isNotEmpty);

// ----------------- Vista para el administrador -----------------

/// Filas con los datos personales del cliente y acceso a sus fotos.
class DatosPersonalesAdmin extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> d;
  const DatosPersonalesAdmin({super.key, required this.uid, required this.d});

  @override
  Widget build(BuildContext context) {
    final nac = aFecha(d['fechaNacimiento']);
    final consentimiento = aFecha(d['fechaConsentimiento']);
    final fotos = d['fotosVerificacion'] is Map ? (d['fotosVerificacion'] as Map) : const {};
    final completas = fotosRequeridas.every((f) => fotos[f.id] != null);

    String texto(String c) => (d[c] ?? '').toString().isEmpty ? '—' : d[c].toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filaDato('DNI', texto('dni')),
        filaDato('Nacimiento', nac == null ? '—' : '${fmtFecha(nac)} (${edad(nac)} años)'),
        filaDato('Celular', texto('celular')),
        filaDato('Dirección', texto('direccion')),
        filaDato('Distrito', texto('distrito')),
        filaDato('Ocupación', texto('ocupacion')),
        filaDato('Ingreso mensual', d['ingresoMensual'] is num ? fmtMoney(aNum(d['ingresoMensual'])) : '—'),
        filaDato(
          'Consentimiento',
          d['consentimientoDatos'] == true && consentimiento != null ? 'Sí · ${fechaHora(consentimiento)}' : 'No registrado',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DocumentosClienteScreen(uid: uid, nombre: texto('nombre'))),
            ),
            icon: Icon(completas ? Icons.badge_rounded : Icons.badge_outlined, size: 18),
            label: Text(completas ? 'Ver fotos de identidad' : 'Ver fotos de identidad (incompletas)'),
          ),
        ),
      ],
    );
  }
}

/// Muestra la selfie y el DNI del cliente. Se cargan solo al abrir esta pantalla
/// (3 lecturas) para no gastar datos ni lecturas en las listas.
class DocumentosClienteScreen extends StatefulWidget {
  final String uid;
  final String nombre;
  const DocumentosClienteScreen({super.key, required this.uid, required this.nombre});

  @override
  State<DocumentosClienteScreen> createState() => _DocumentosClienteScreenState();
}

class _DocumentosClienteScreenState extends State<DocumentosClienteScreen> {
  late Future<List<DocumentSnapshot<Map<String, dynamic>>>> _futuro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final col = FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).collection('documentos');
    _futuro = Future.wait([for (final f in fotosRequeridas) col.doc(f.id).get()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Identidad · ${widget.nombre}')),
      body: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.hasError) {
            return errorConsulta(context, 'No se pudieron cargar las fotos', snap.error!, () => setState(_cargar));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              tarjetaBlanca(
                child: const Text(
                  'La app ya revisó cada foto en el celular del cliente: rostro en la selfie, número de DNI '
                  'y dirección del recibo frente a su GPS. Confirma tú que la selfie corresponda a la foto del DNI '
                  'y revisa con atención las fotos marcadas "Revisar".',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < fotosRequeridas.length; i++) ...[
                _foto(fotosRequeridas[i], docs[i].data()),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _foto(TipoFoto tipo, Map<String, dynamic>? d) {
    Uint8List? bytes;
    try {
      final b64 = d?['imagenBase64'];
      if (b64 is String && b64.isNotEmpty) bytes = base64Decode(b64);
    } catch (_) {
      bytes = null;
    }
    final fecha = aFecha(d?['fecha']);

    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tipo.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (fecha != null) Text(fechaHora(fecha), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          if (d?['validacion'] is Map) ...[
            const SizedBox(height: 8),
            _validacion(Map<String, dynamic>.from(d!['validacion'] as Map)),
          ],
          const SizedBox(height: 10),
          if (bytes == null)
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
              child: Text('El cliente no ha enviado esta foto', style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _FotoCompleta(titulo: tipo.titulo, bytes: bytes!)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
        ],
      ),
    );
  }
}

/// Resultado de la validación automática guardado con la foto.
Widget _validacion(Map<String, dynamic> v) {
  final estado = (v['estado'] ?? '').toString();
  final ok = estado == 'verificado';
  final color = ok ? AppColors.verde : AppColors.ambar;
  final distancia = v['distanciaGpsMetros'];
  final filas = <(String, String)>[
    if ((v['empresa'] ?? '').toString().isNotEmpty) ('Empresa', v['empresa'].toString()),
    if (v['direccionRecibo'] != null) ('Dirección en recibo', v['direccionRecibo'].toString()),
    if (v['coincidenciaDireccion'] is num)
      ('Coincide con la ingresada', '${((v['coincidenciaDireccion'] as num) * 100).round()} %'),
    if (v['distritoGps'] != null) ('Distrito según GPS', v['distritoGps'].toString()),
    if (distancia is num)
      ('Distancia recibo–GPS', distancia < 1000 ? '$distancia m' : '${(distancia / 1000).toStringAsFixed(1)} km'),
  ];
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(ok ? Icons.verified_rounded : Icons.report_outlined, color: color, size: 18),
            const SizedBox(width: 6),
            Text(ok ? 'Verificado por la app' : 'Revisar',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        if ((v['mensaje'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(v['mensaje'].toString(), style: const TextStyle(fontSize: 12.5)),
        ],
        for (final f in filas)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('${f.$1}: ${f.$2}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
      ],
    ),
  );
}

class _FotoCompleta extends StatelessWidget {
  final String titulo;
  final Uint8List bytes;
  const _FotoCompleta({required this.titulo, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(titulo), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(bytes))),
    );
  }
}

/// Texto del consentimiento para el tratamiento de datos personales.
String textoConsentimiento() =>
    'Autorizo a ${ConfigEmpresa.nombre} a tratar mis datos personales (nombres, DNI, fecha de nacimiento, '
    'celular, dirección, ocupación, ingresos, ubicación y las fotografías de mi rostro, de mi DNI y de un recibo '
    'de servicios de mi domicilio) con la '
    'finalidad de verificar mi identidad, evaluar mi solicitud y gestionar el préstamo y su cobranza, '
    'conforme a la Ley N.° 29733, Ley de Protección de Datos Personales, y su reglamento. Mis datos no se '
    'compartirán con terceros salvo obligación legal. Puedo ejercer mis derechos de acceso, rectificación, '
    'cancelación y oposición escribiendo a ${ConfigEmpresa.correoDatos}.';
