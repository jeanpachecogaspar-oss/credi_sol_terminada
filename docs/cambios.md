# Cambios de esta versión (observaciones del profesor)

## 1. Errores encontrados y corregidos

| # | Problema | Dónde | Corrección |
|---|---|---|---|
| 1 | El splash esperaba **3.2 s fijos** aunque la app ya estuviera lista. Es la causa principal de que entrar "demore mucho" | `splash_screen.dart` | Dura lo necesario: mínimo 0.9 s y máximo 4 s sin internet. Mientras tanto adelanta la lectura del perfil |
| 2 | `main()` esperaba a que se prepararan las notificaciones antes de mostrar la app, cargando toda la base de zonas horarias | `main.dart`, `recordatorios.dart` | Se preparan en segundo plano; `sincronizar()` las espera solo si hace falta |
| 3 | La contraseña se recortaba con `trim()`. Una contraseña con espacio al inicio o al final nunca funcionaba | `login_screen.dart` | Ya no se recorta |
| 4 | Cambios bruscos entre el login, la carga y la app (la pantalla "saltaba") | `auth_gate.dart` | Transición con fundido (`AnimatedSwitcher`) y pantalla de carga con el logo, igual al splash |
| 5 | Animaciones recargadas: logo con giro 3D y rebote elástico, monedas orbitando y círculos pulsando | `splash_screen.dart`, `login_screen.dart` | Animación sobria: el logo se asienta, el texto y el formulario aparecen escalonados (0.65 s) |

## 2. Funciones nuevas

- **Carrito de compras**, con catálogo, carrito, pedidos y gestión de pedidos del administrador.
- **Imágenes desde Google Drive** en productos y promociones, con el botón "Elegir de Drive".
- **Promociones por cliente**: para todos o solo para clientes elegidos.

(Reemplazado en la sección 2d: CrediSol ya no tiene tienda.)

## 2b. Segunda revisión (nota: Autenticación 3, UX/UI 3, Ideas 2)

### Yape abría la Play Store aunque estuviera instalado
- **Causa:** se usaba un Intent `MAIN/LAUNCHER` implícito con `canResolveActivity()`, que busca con
  `MATCH_DEFAULT_ONLY`. Las pantallas de inicio de las apps no declaran `CATEGORY_DEFAULT`, así que siempre
  respondía "no instalado".
- **Solución:** un canal nativo propio (`MainActivity.kt` + `lib/apps_externas.dart`) usa
  `getLaunchIntentForPackage()`, que es la forma correcta en Android. Abre Yape directamente. La Play Store
  solo se ofrece, con confirmación, si Yape no está instalado.
- **Plin:** aparecen botones para abrir las apps de banco instaladas (BCP, Interbank, BBVA, Scotiabank).
- Se quitó la dependencia `android_intent_plus`.

### Validación de identidad: antes aceptaba cualquier foto
Ahora cada foto se analiza **en el celular**, sin internet ni costo, con Google ML Kit y el geocodificador de
Android (`lib/validacion_identidad.dart`):

| Foto | Validación | Si falla |
|---|---|---|
| Selfie | Exactamente 1 rostro, de frente y con los ojos abiertos (detección facial) | Se rechaza y se pide otra |
| DNI (frente) | Se lee el texto (OCR): debe ser un DNI peruano y contener **el número que escribió el cliente**. También se busca el rostro del documento | Se rechaza |
| DNI (reverso) | Se lee la zona `I<PER…<<` o el número de DNI | Se rechaza |
| **Recibo de luz o agua (nuevo)** | 1) Se reconoce la empresa (Luz del Sur, Enel, Sedapal, Hidrandina, etc.) o las palabras propias de un recibo. 2) Se compara su dirección con la que escribió el cliente. 3) La dirección del recibo se convierte en coordenadas y se mide la **distancia a la ubicación GPS** del cliente. También se obtiene el distrito del GPS | Si no es un recibo o la dirección no coincide, se rechaza. Si el GPS queda a más de 1.5 km, se acepta pero se marca **"Revisar"** (el cliente puede estar solicitando desde su trabajo) |

El administrador ve debajo de cada foto: **"Verificado por la app"** o **"Revisar"**, la empresa del recibo,
la dirección leída, el % de coincidencia, el distrito según el GPS y la distancia entre el recibo y el GPS.

Las reglas exigen ahora el recibo (`recibo_servicio`) para enviar una solicitud. Hay que **volver a publicar
`firestore.rules`**.

Limitación: la validación corre en el celular del cliente. Es un filtro fuerte contra fotos que no
corresponden, pero la aprobación final sigue siendo del administrador.

## 2c. Tercera revisión (rúbrica del profesor)

| Criterio | Qué se hizo |
|---|---|
| **API DNI/RUC (apisperu.com)** | `lib/apis_peru.dart`. **Registro:** se escribe el DNI y el nombre se completa con RENIEC. **Carrito:** con "Necesito factura" se escribe el RUC y la razón social y la dirección se completan con SUNAT; el pedido guarda el RUC |
| **Registro mínimo** | Solo DNI (validado), celular, correo y contraseña. Se quitó "confirmar contraseña". Si la API no responde, se permite escribir el nombre |
| **Botón de cámara** | En la Tienda, **Escanear**: lee el código de barras o QR con ML Kit y abre el producto. El admin asigna el código a cada producto escaneándolo |
| **Botón de sensor** | En la Tienda, **Agita y descubre**: con el acelerómetro (`sensors_plus`) muestra la fuerza en m/s² en vivo y, al agitar, elige un producto sorpresa con efecto de ruleta y vibración |
| **40 productos con imágenes** | Como es una financiera, son **equipos a crédito**: celulares, laptops, tablets, motos, electrodomésticos, audio y equipos para negocio. Se cargan en Admin › Equipos › Productos › **Cargar 40 productos de ejemplo**. Cada uno muestra **"S/ X/mes"** (12 cuotas con la TEA del negocio) |
| **Carrito a crédito** | Medio de pago **"Crédito CrediSol"**: el cliente elige 3, 6, 12, 18 o 24 cuotas y ve la cuota mensual (sistema francés, la misma fórmula del simulador). Las reglas validan el plazo y el monto (S/ 300 a S/ 10 000). El asesor la evalúa en Pedidos |
| **Historial de préstamos** | Resumen (préstamos, pagados, monto recibido, saldo) y filtros Todos / En curso / Historial |
| **Geolocalización + recibo** | Ver 2b: la dirección del recibo se compara con el GPS |
| **Funciones llamativas** | 1) Validación de identidad con IA en el celular (rostro, OCR del DNI y del recibo, distancia al GPS). 2) Escáner de códigos y "Agita y descubre" con sensor |

**Token de APIsPERU:** regístrate gratis en https://apisperu.com/admin/register (1 000 consultas al mes) y pega
el token en `lib/apis_peru.dart` (`token = '...'`).

## 2d. Cuarta revisión: CrediSol como financiera (sin tienda)

| Criterio | Qué se hizo | Dónde |
|---|---|---|
| **40 productos con imágenes + carrito** | Se **eliminó la tienda**. Ahora hay **40 productos financieros** en 5 categorías (capital de trabajo, activo fijo, agropecuario, personal, especiales), cada uno con **imagen 3D** incluida en la app (carga al instante, sin internet). Cada producto tiene detalle, requisitos y simulador (monto y plazo con sliders). El carrito es **"Mi selección"**: compara cuotas, suma la cuota mensual, avisa si supera el 40 % del ingreso y envía cada crédito a la solicitud de 3 pasos. Se guarda en el celular | `productos_financieros.dart`, `creditos_screen.dart`, `seleccion_creditos.dart`, `admin_creditos_screen.dart`, `assets/creditos/` |
| **Login 3D** | La tarjeta del formulario se despliega en 3D y **se inclina siguiendo el acelerómetro**. El logo es una **moneda 3D con canto dorado** que entra girando y luego flota. El fondo tiene monedas en 3 profundidades con parallax. Va a 60 fps con `RepaintBoundary` (el formulario no se redibuja) y respeta "reducir animaciones" | `login_screen.dart` |
| **Entrar rápido** | Se quitó el splash de Flutter (queda solo el nativo). Firebase y el rol guardado cargan en paralelo. La sesión se conoce al instante (`initialData`). El inicio se abre con el **rol guardado en el celular** mientras Firestore lo confirma en segundo plano | `main.dart`, `auth_gate.dart`, `rol_cache.dart` |
| **Botón de cámara** | **Escanear DNI** en el Inicio: foto, OCR con ML Kit, número de DNI, consulta a RENIEC (APIsPERU) y verificación de que coincida con la cuenta. También en el registro (ícono en el campo DNI) | `sensores_camara.dart`, `cliente_inicio_screen.dart`, `registro_screen.dart` |
| **Botón de sensor** | **Modo privado** en el Inicio: con el acelerómetro, al poner el celular **boca abajo** o **agitarlo**, todos los montos se ven como `S/ ••••`. Muestra la lectura del sensor en vivo. Manteniéndolo presionado se ocultan o muestran a mano | `sensores_camara.dart`, `formato.dart`, `cliente_shell.dart` |
| **RUC (apisperu)** | En la solicitud, campo opcional "RUC de tu negocio": la razón social y la dirección se completan con SUNAT y avisa si no está ACTIVO/HABIDO. Se guarda en el préstamo | `solicitud_screen.dart` |
| **Funcionalidad llamativa 2** | **Score CrediSol (0–1000)** con velocímetro animado. Se calcula con el historial real: puntualidad, atrasos, cuotas vencidas, préstamos pagados, ingreso, carga de deuda, antigüedad, DNI validado y domicilio verificado (recibo vs GPS). Explica qué lo sube o lo baja y da un **monto preaprobado** | `score_screen.dart` |
| **Promociones por cliente** | Se convirtieron en **campañas** (para todos o para clientes elegidos), visibles en Inicio y Créditos | `promociones.dart` |

Se eliminaron: `tienda_screen.dart`, `carrito_screen.dart`, `admin_tienda_screen.dart`, `catalogo_ejemplo.dart`,
`tienda_modelos.dart`, `config_tienda.dart`, `splash_screen.dart`, la colección `pedidos`/`productos` y sus
reglas, y el paquete del lector de códigos de barras.

Imágenes 3D: [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) de Microsoft (licencia MIT, en
`assets/creditos/LICENSE-fluent-emoji.txt`).

**Pendiente** (ver `docs/prompt_profesional.md`): mapa dentro de la app, huella digital, modo oscuro, gráfico y PDF en el
historial, prueba de vida en la selfie.

## 2e. Geolocalización útil y sin rastreo

**Antes:** la app bloqueaba al cliente si no tenía el GPS activo y guardaba su posición cada 2 minutos
(rastreo). El registro también exigía el GPS.

**Ahora:** **no hay rastreo.** El GPS se pide solo en el momento en que el cliente lo necesita, y él sabe para qué.
Se usan APIs **gratuitas y sin clave**: OpenStreetMap (mapa), Overpass (bancos, cajeros y agentes reales) y OSRM
(rutas).

| Uso | Qué hace | Dónde |
|---|---|---|
| **Verificar el domicilio** | Al fotografiar el recibo de luz o agua, se compara su dirección con la ubicación del momento (una sola vez) | `validacion_identidad.dart` |
| **Ubica tu negocio** | En la solicitud, el cliente mueve un mapa hasta poner el pin sobre su negocio; se muestra la dirección. El asesor lo usa para la **visita de evaluación** | `ubicar_negocio_screen.dart`, `solicitud_screen.dart` |
| **Pagar cerca de ti** | Mapa dentro de la app con las agencias CrediSol y los **bancos, cajeros y agentes reales** cercanos (Overpass), con la distancia y la **ruta por calles** (OSRM) | `cercanos_screen.dart`, `mapas.dart` |
| **Mapa de visitas** (admin) | Los negocios con solicitudes por evaluar y préstamos activos, **ordenados por cercanía al asesor**, con la ruta. Usa la ubicación que declaró el cliente | `mapa_visitas_screen.dart` (Solicitudes › ícono de mapa) |

Se eliminó `ubicacion_gate.dart` (bloqueo y rastreo) y el GPS obligatorio del registro. Las agencias se
configuran en `config_pagos.dart` (`ConfigAgencias`).

## 3. Archivos (versión actual)

Nuevos: `mapas.dart`, `cercanos_screen.dart`, `ubicar_negocio_screen.dart`, `mapa_visitas_screen.dart`,
`productos_financieros.dart`, `creditos_screen.dart`, `seleccion_creditos.dart`, `admin_creditos_screen.dart`,
`promociones.dart`, `score_screen.dart`, `sensores_camara.dart`, `rol_cache.dart`, `config_drive.dart`, `apis_peru.dart`,
`validacion_identidad.dart`, `apps_externas.dart`, `drive_imagen.dart`, `assets/creditos/` (40 imágenes 3D),
`test/creditos_test.dart`, `test/validacion_test.dart`.

Modificados: `main.dart`, `login_screen.dart`, `registro_screen.dart`, `auth_gate.dart`, `recordatorios.dart`,
`cliente_shell.dart`, `home_screen.dart`, `navegacion_cliente.dart`, `cliente_inicio_screen.dart`, `formato.dart`,
`ui_comun.dart`, `solicitud_screen.dart`, `datos_personales.dart`, `mis_prestamos_screen.dart`, `config_prestamos.dart`,
`MainActivity.kt`, `AndroidManifest.xml`, `pubspec.yaml`, `firestore.rules`.

## 4. Cómo probar

```
flutter pub get
flutter analyze
flutter test
firebase deploy --only firestore
flutter build apk --release
```

La APK queda en `build/app/outputs/flutter-apk/app-release.apk`.
