import 'package:firebase_core/firebase_core.dart';

/// Si el error es por un índice faltante, devuelve el enlace de la consola
/// de Firebase que lo crea con un clic.
String? enlaceIndice(Object e) {
  final texto = e is FirebaseException ? (e.message ?? '') : e.toString();
  final m = RegExp(r'https://console\.firebase\.google\.com/\S+').firstMatch(texto);
  return m?.group(0)?.replaceAll(RegExp(r'[.,;)\]]+$'), '');
}

/// Convierte una excepción de Firebase en un mensaje claro en español.
String mensajeError(Object e) {
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción. Si crees que es un error, contacta al administrador.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red e inténtalo de nuevo.';
      case 'not-found':
        return 'El registro ya no existe.';
      case 'failed-precondition':
        if ((e.message ?? '').toLowerCase().contains('index')) {
          return 'Falta crear un índice en Firestore. Pulsa "Crear índice", confirma en la consola y espera unos minutos a que diga "Habilitado".';
        }
        return 'La operación no se pudo completar porque los datos cambiaron. Actualiza e inténtalo de nuevo.';
      case 'aborted':
        return 'Otra persona modificó este registro al mismo tiempo. Inténtalo de nuevo.';
      case 'deadline-exceeded':
        return 'El servidor tardó demasiado en responder. Inténtalo de nuevo.';
      default:
        return 'Ocurrió un error (${e.code}). Inténtalo de nuevo.';
    }
  }
  if (e is StateError) return e.message;
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}
