import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoUbicacion { ok, servicioApagado, denegado, denegadoPermanente }

class LocationService {
  static const LocationSettings _ajustes = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 20),
  );

  static EstadoUbicacion _desdePermiso(LocationPermission p) {
    switch (p) {
      case LocationPermission.deniedForever:
        return EstadoUbicacion.denegadoPermanente;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return EstadoUbicacion.denegado;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return EstadoUbicacion.ok;
    }
  }

  /// Revisa el estado actual sin mostrar diálogos.
  static Future<EstadoUbicacion> estado() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return EstadoUbicacion.servicioApagado;
    }
    return _desdePermiso(await Geolocator.checkPermission());
  }

  /// Pide el permiso si todavía no se dio.
  static Future<EstadoUbicacion> solicitar() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return EstadoUbicacion.servicioApagado;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    return _desdePermiso(permiso);
  }

  static Future<Position> posicionActual() {
    return Geolocator.getCurrentPosition(locationSettings: _ajustes);
  }

  static Map<String, dynamic> mapa(Position p) => {
        'lat': p.latitude,
        'lng': p.longitude,
        'precision': p.accuracy,
        'fecha': FieldValue.serverTimestamp(),
      };

  static Future<void> guardar(String uid, Position p) {
    return FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
      {'ubicacion': mapa(p)},
      SetOptions(merge: true),
    );
  }
}