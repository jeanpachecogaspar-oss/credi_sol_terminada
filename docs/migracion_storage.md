# Fotos de identidad: almacenamiento actual y migración a Firebase Storage

## Cómo funciona hoy (plan Spark, sin Storage)

- Cada cliente tiene 3 fotos: `selfie`, `dni_frontal` y `dni_posterior`.
- Se toman **solo con la cámara** (`image_picker`, `ImageSource.camera`) y se comprimen en el celular a JPEG
  de máximo 1024 px y calidad 55. Normalmente quedan entre 60 y 160 KB. La app rechaza fotos de más de 180 KB.
- Se guardan en base64 dentro de Firestore:
  `usuarios/{uid}/documentos/{tipo}` → `{ tipo, imagenBase64, mime, bytes, fecha }`.
- En `usuarios/{uid}` se guarda solo la fecha de cada foto en `fotosVerificacion.{tipo}`. Así la app sabe
  qué fotos existen **sin descargarlas**.
- Las reglas de Firestore limitan cada foto a 250 000 caracteres en base64 y exigen las 3 fotos para crear
  una solicitud.

### Costos y límites

| Concepto | Valor aproximado |
|---|---|
| Tamaño por foto en Firestore | 80–240 KB (base64 ocupa un 33 % más que el JPEG) |
| Espacio por cliente | ~0,5 MB |
| Clientes que caben en 1 GB gratis de Spark | ~2 000 (sin contar el resto de datos) |
| Lecturas al revisar las fotos de un cliente | 3 (solo al abrir "Ver fotos de identidad") |
| Límite de Firestore por documento | 1 MB (cada foto va en su propio documento) |

Las fotos no se leen en las listas, solo en la pantalla de identidad, para no gastar lecturas ni datos móviles.

## Cuándo migrar

Conviene migrar a Firebase Storage cuando:
- haya más de ~1 000 clientes con fotos,
- se necesiten fotos de mayor resolución, o
- el proyecto pase al plan Blaze (requiere tarjeta; Storage tiene 5 GB gratis).

## Pasos de la migración

1. Activar el plan Blaze y Storage en la consola de Firebase.
2. Agregar la dependencia: `flutter pub add firebase_storage`.
3. Publicar reglas de Storage equivalentes:
   ```
   match /b/{bucket}/o {
     match /usuarios/{uid}/documentos/{tipo} {
       allow read: if request.auth.uid == uid || <es admin>;
       allow write: if request.auth.uid == uid
         && tipo in ['selfie.jpg', 'dni_frontal.jpg', 'dni_posterior.jpg']
         && request.resource.size < 2 * 1024 * 1024
         && request.resource.contentType == 'image/jpeg';
     }
   }
   ```
   Para comprobar "es admin" desde Storage se usa `firestore.get(...)` en las reglas de Storage, o un custom claim.
4. En `solicitud_screen.dart`, subir los bytes con `putData` a `usuarios/{uid}/documentos/{tipo}.jpg` y guardar
   en el documento de Firestore solo `{ tipo, ruta, bytes, fecha }`, sin `imagenBase64`.
5. En `datos_personales.dart` (`DocumentosClienteScreen`), mostrar la imagen con `getDownloadURL()` o `getData()`.
6. Migrar las fotos existentes con un script de administrador: leer cada `documentos/{tipo}`, decodificar
   `imagenBase64`, subirlo a Storage y borrar el campo `imagenBase64`.
7. Ajustar `firestore.rules` (`documentos/{tipo}`) para aceptar `ruta` en lugar de `imagenBase64`.

## Limitación importante

Las fotos se revisan **manualmente**. La app no comprueba automáticamente que la selfie corresponda al DNI ni
que el DNI sea auténtico. Para eso haría falta un servicio de verificación de identidad (por ejemplo, la
validación con RENIEC mediante un proveedor autorizado).
