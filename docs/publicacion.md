# Publicación en Google Play: lista de verificación

## Ya configurado

| Elemento | Valor | Dónde |
|---|---|---|
| Nombre visible | CrediSol | `android/app/src/main/AndroidManifest.xml` (`android:label`) |
| Identificador | `pe.credisol.app` (permanente) | `android/app/build.gradle.kts` (`applicationId`) |
| App en Firebase | "CrediSol" registrada para `pe.credisol.app` | `android/app/google-services.json` |
| Versión | 1.0.0 (compilación 1) | `pubspec.yaml` → `version: 1.0.0+1` |
| Ícono | los 3 círculos del logo | `assets/icono.png`, `assets/icono_foreground.png` |
| Pantalla de carga nativa | logo sobre fondo blanco | configuración `flutter_native_splash` en `pubspec.yaml` |
| Ícono de notificaciones | silueta blanca de los 3 círculos | `android/app/src/main/res/drawable-*/ic_notificacion.png` |
| Abrir Yape | `<queries>` con `com.bcp.innovacxion.yapeapp` | `AndroidManifest.xml` |

Si cambias el logo, regenera los íconos y la pantalla de carga:
```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Antes de publicar (pendiente)

### 1. Datos reales del negocio
- [ ] `lib/config_pagos.dart`: **cuenta y CCI reales**. Mientras tengan ceros, la opción "Transferencia" no
      aparece. Verifica el titular y los números de Yape y Plin.
- [ ] `lib/config_prestamos.dart`:
  - [ ] Nombre del responsable de los datos y **correo real** de contacto (`ConfigEmpresa`).
  - [ ] **WhatsApp de soporte** (`whatsappSoporte`).
  - [ ] **Tasa y límites** definitivos (si cambian, actualiza también `firestore.rules` y publícalas).
- [ ] Haz que un **abogado** revise el texto del consentimiento (`textoConsentimiento()` en
      `lib/datos_personales.dart`). Las fotos del rostro y del DNI son datos sensibles.
- [ ] Inscribe el banco de datos personales ante la Autoridad Nacional de Protección de Datos Personales, si
      corresponde.
- [ ] Verifica si tu actividad de préstamos requiere registro ante la SBS u otra autoridad.

### 2. Seguridad de la cuenta de administrador
- [ ] Cambia la contraseña de `admin@gmail.com` por una larga y única. Lo ideal es usar un correo real del
      negocio.
- [ ] Borra los usuarios de prueba y el documento huérfano de `usuarios` (`1iLJAxhkDb…`) desde la consola.

### 3. Firma (llave de Play Store)
Genera la llave **una sola vez** y guárdala en un lugar seguro, con copia de respaldo. Si la pierdes, no
podrás actualizar la app:
```
keytool -genkey -v -keystore C:\Users\User\credisol-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias credisol
```
Crea `android/key.properties`. Este archivo no se sube a git:
```
storePassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyPassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyAlias=credisol
storeFile=C:/Users/User/credisol-upload.jks
```
Con ese archivo presente, la versión de producción se firma automáticamente con tu llave. Sin él, se firma con
la llave de depuración, que Google Play no acepta.

Activa también **Play App Signing** al crear la app en Play Console (recomendado).

### 4. Compilar
```
flutter build appbundle --release
```
El archivo para subir queda en `build/app/outputs/bundle/release/app-release.aab`.

En cada actualización, sube el número después del `+` en `pubspec.yaml` (por ejemplo `1.0.1+2`).

### 5. Play Console
- [ ] **Política de privacidad**: Google la exige como URL pública. Puedes publicarla gratis en Google Sites con
      el mismo contenido del consentimiento.
- [ ] **Seguridad de los datos**: declara la ubicación precisa, el nombre, el correo, el teléfono, el
      documento de identidad, las fotos y la información financiera. Indica que se cifran en tránsito y para
      qué se usan.
- [ ] **Préstamos personales**: Google Play tiene requisitos especiales para apps de préstamos. Por ejemplo,
      mostrar el plazo mínimo y máximo, la TEA máxima y un ejemplo de costo total. En **India, Indonesia,
      Filipinas, Nigeria, Kenia, Pakistán y Tailandia** exige además documentación adicional. Revisa la
      política vigente "Servicios financieros" de Google Play antes de enviar la app a revisión.
- [ ] **Permisos**: la ubicación es solo "mientras se usa la app" (no en segundo plano). La cámara se usa
      mediante la app de cámara del sistema. No se piden contactos, SMS ni galería, y Google Play rechaza las
      apps de préstamos que los piden.
- [ ] Capturas de pantalla, descripción corta y larga, ícono de 512×512 (usa `assets/icono.png` reducido) y
      gráfico destacado de 1024×500.

### 6. Firebase
- [ ] Las reglas (`firestore.rules`) y los índices (`firestore.indexes.json`) ya están publicados. Si los
      modificas: `firebase deploy --only firestore`.
- [ ] Plantilla del correo de recuperación en español (ver `docs/recuperacion_contrasena.md`).
- [ ] Opcional: borra la app Android antigua `com.example.flutter_application_1` en Configuración del proyecto
      → Tus apps. Antes, desinstala la versión vieja de los celulares de prueba.
