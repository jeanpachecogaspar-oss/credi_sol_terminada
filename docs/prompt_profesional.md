# Prompt para llevar CrediSol a nivel profesional

> Copia todo lo que está debajo de la línea y pégalo en Claude Code (VS Code), con la carpeta
> `credisol-app-main` abierta.

---

## Rol
Eres un desarrollador senior de Flutter y Firebase, especializado en fintech para Perú. Vas a terminar
**CrediSol**, una app Android de **préstamos para emprendedores** (soles, español de Perú) que se presenta a un
profesor con una rúbrica. Trabaja en esta carpeta, compila, prueba en el celular conectado y corrige hasta que
`flutter analyze` quede en 0 errores.

## Contexto (lee esto primero)
- Lee `README.md`, `docs/diagnostico.md`, `docs/cambios.md`, `docs/limitaciones.md` y `firestore.rules`.
- Stack: Flutter 3.47 (stable), Dart 3, Firebase **plan Spark** (Auth + Firestore, **sin** Storage ni Cloud
  Functions), Android con `minSdk` de Flutter y `applicationId` `pe.credisol.app`.
- Roles: `usuarios/{uid}.rol` = `cliente` | `admin`. Colecciones: `usuarios` (+`documentos`), `prestamos`
  (+`cuotas`), `promociones`.
- **Es una financiera.** Prohibido cualquier concepto de tienda, abarrotes o venta de equipos.

## Reglas de trabajo
1. **Primero diagnostica:** ejecuta `flutter pub get`, `flutter analyze` y `flutter test`. Haz una lista de
   errores y avísame antes de cambiar la arquitectura.
2. **Luego planifica:** dame un plan por puntos de la rúbrica (abajo) con los archivos a crear, modificar o
   borrar.
3. Implementa **un punto a la vez**. Después de cada punto, `flutter analyze` debe quedar en 0 errores y la
   app debe correr con `flutter run` en el celular.
4. No borres funciones que ya sirven (simulador, cronograma, solicitud, validación con IA, Yape nativo,
   cobranzas, recordatorios, historial).
5. Todo el texto de la interfaz va en español de Perú y los montos en `S/` con 2 decimales.
6. Toda colección o campo nuevo se agrega a `firestore.rules` con validación. Al final recuérdame publicarlas.
7. Las APIs y los sensores se usan **dentro de la app**. Las apps externas (Yape, bancos) se abren directo, sin
   pasar por la Play Store.
8. Al terminar, actualiza `docs/cambios.md` con una tabla de "criterio de la rúbrica → cómo se cumple → dónde
   está en el código".

## Rúbrica y criterios de aceptación

### 1. Catálogo de 40 productos financieros con imágenes + "carrito" de créditos
- **Elimina la tienda:** `tienda_screen.dart`, `carrito_screen.dart`, `admin_tienda_screen.dart`,
  `catalogo_ejemplo.dart`, `tienda_modelos.dart`, `config_tienda.dart`, la colección `pedidos` y sus reglas.
  Conserva `drive_imagen.dart` para las imágenes.
- Crea la colección `productosFinancieros/{id}` con estos campos: nombre, descripción, categoría, imagen,
  montoMin, montoMax, plazoMin, plazoMax, TEA, requisitos (lista), público objetivo y activo.
- **40 productos reales de microfinanzas peruanas**, en categorías como:
  - Capital de trabajo (bodega, mercado, ferretería, restaurante, salón de belleza…).
  - Activo fijo (mototaxi, moto para delivery, máquina de coser, horno de panadería…).
  - Agropecuario (siembra, ganado, riego).
  - Consumo (estudios, salud, vivienda y mejoramiento, campaña escolar, campaña navideña).
  - Mujer emprendedora, crédito grupal/solidario, crédito paralelo, compra de deuda, línea revolvente, crédito
    con garantía.
- **Imágenes:** una por producto. Usa fotos de Google Drive vía `drive_imagen.dart`; si un producto no tiene
  imagen, muestra una ilustración generada (ícono grande sobre degradado del color de la categoría). Crea un
  botón de admin **"Cargar los 40 productos"** que haga un seed idempotente.
- **Cliente, pestaña "Créditos":** grilla con imagen, nombre, "desde S/ X al mes", filtros por categoría y
  buscador.
- **Detalle del producto:** requisitos, simulador embebido (slider de monto y plazo) con la cuota calculada por
  `cronograma.dart`, y el botón **"Agregar a mi selección"**.
- **"Mi selección" (el carrito):** una lista de créditos elegidos con su monto, plazo y cuota, la cuota total
  mensual, una alerta si la cuota supera el 40 % del ingreso declarado, y el botón **"Solicitar"**, que lleva
  cada crédito a la solicitud de 3 pasos existente. El carrito se guarda localmente para que no se pierda al
  cerrar la app.
- **Admin:** CRUD de productos financieros con imagen, más la opción de activar u ocultar.

### 2. Login con animación 3D, moderno y rápido
- Pantalla de login con **efecto 3D real**:
  - Una tarjeta con `Transform` y `Matrix4..setEntry(3, 2, 0.001)` que **se inclina siguiendo el giroscopio
    o acelerómetro** (`sensors_plus`), con parallax en dos capas.
  - El logo como **moneda 3D que gira** sobre el eje Y una vez al entrar y luego flota suavemente.
  - Fondo con formas en profundidad y degradado de marca.
  - Transición 3D al pasar del login al inicio.
- La animación debe ir a **60 fps**: usa `RepaintBoundary` y no reconstruyas el formulario en cada frame.
  Respeta "reducir animaciones" del sistema (`MediaQuery.disableAnimations`).
- Botones: Ingresar, "Ingresar con huella" (`local_auth`, si el usuario ya inició sesión antes) y "Crear
  cuenta".

### 3. Entrar rápido (medible)
- **Meta:** menos de 1.5 s desde que tocas el ícono hasta la pantalla de inicio con sesión guardada (en modo
  release).
- Quita el splash de Flutter: deja solo el splash nativo (`flutter_native_splash`) y ve directo a AuthGate.
- Guarda el rol en caché (`shared_preferences`) para abrir el inicio al instante y validarlo con Firestore en
  segundo plano.
- No bloquees el inicio esperando el GPS: pide el permiso, pero muestra el contenido.
- Inicializa en paralelo y sin `await` lo que no sea crítico (notificaciones, ML Kit).
- Mide con DevTools y `flutter run --release`, y escribe los tiempos antes y después en `docs/cambios.md`.

### 4. Autenticación con registro mínimo + API DNI/RUC (apisperu.com)
- **Registro en un solo paso:** DNI, celular, correo y contraseña. Al escribir 8 dígitos se consulta
  `https://dniruc.apisperu.com/api/v1/dni/{dni}?token=TOKEN` y el nombre se completa solo (ya está en
  `lib/apis_peru.dart`; pon el token en una constante, documentado).
- El **RUC** (`/api/v1/ruc/{ruc}`) va en la solicitud de **crédito para negocio**: autocompleta la razón social,
  la dirección y el estado/condición de SUNAT. Si no es ACTIVO/HABIDO, avisa.
- Recordarme, ingreso con huella (`local_auth`; `MainActivity` debe extender `FlutterFragmentActivity`),
  recuperar contraseña (ya existe) y cerrar sesión.
- Manejo de errores claro: sin internet, DNI no encontrado, token vencido.

### 5. Dos botones: sensor y cámara (con sentido financiero)
- **Botón de cámara, "Escanear DNI":** toma la foto, lee el número con ML Kit OCR, consulta apisperu y
  autocompleta el registro o la solicitud. También "Escanear recibo" en la solicitud (ya existe la validación).
- **Botón de sensor, "Modo privado":** al voltear el celular boca abajo o agitarlo (acelerómetro), se ocultan
  los saldos y montos (se ven como S/ ••••). Se muestra un indicador del sensor en vivo.
- Los dos botones deben verse en la pantalla de **Inicio** del cliente, con un ícono grande y una etiqueta
  ("Cámara", "Sensor").

### 6. Historial de préstamos
- Conserva el resumen y los filtros. Agrega:
  - Un **gráfico** de pagos por mes (con `fl_chart`).
  - Una **línea de tiempo** de cada préstamo.
  - La opción de **descargar o compartir el cronograma en PDF** (`pdf` + `printing` o `share_plus`).

### 7. Geolocalización + comparación con el recibo de luz o agua
- Conserva la validación actual (OCR del recibo → dirección → geocodificación → distancia al GPS).
- Agrega un **mapa dentro de la app** con `flutter_map` + OpenStreetMap (sin clave de pago):
  - **Admin:** mapa de clientes con marcadores de colores según el estado del préstamo, más la ubicación del
    recibo y la del GPS de cada solicitud, unidas por una línea y con la distancia.
  - **Cliente:** "Agencias y agentes cercanos" con la distancia.
- Configura `userAgentPackageName: 'pe.credisol.app'` para cumplir la política de OSM.

### 8. UX/UI profesional (agradable, fácil de usar, colores y diseño)
- **Design system** en `app_theme.dart`: paleta de marca (azul `#1E88E5`, azul oscuro `#1565C0`, dorado
  `#F2B705`, verde `#2E9E6B`, rojo `#E53935`), tipografía (`google_fonts`, por ejemplo Poppins para títulos e
  Inter para textos), espaciados de 4, 8, 12, 16, 24 y 32, radios y sombras únicos.
- **Modo claro y oscuro** completo (cero `Colors.white` fijos), con un selector en Perfil.
- Estados de carga con **skeleton/shimmer**, estados vacíos con ilustración y errores con un botón de
  reintentar.
- Transiciones consistentes entre pantallas y micro-animaciones en botones y tarjetas.
- Accesibilidad: contraste AA, textos escalables y botones de al menos 48 dp.
- **Onboarding** de 3 pantallas al primer uso.

### 9. Dos funcionalidades llamativas y complejas (para puntaje extra)
1. **Verificación de identidad con IA en el celular** (ya existe; pulirla):
   - Guía visual con un marco para el DNI y el rostro.
   - **Prueba de vida**: pedir que parpadee o gire la cabeza con ML Kit Face Detection.
   - **Comparación selfie ↔ foto del DNI**: similitud por puntos del rostro (landmarks), mostrada al admin
     como un porcentaje.
2. **Score crediticio CrediSol en tiempo real:** un puntaje de 0 a 1000 calculado con el historial de pagos
   (puntualidad), el ingreso declarado, la relación cuota/ingreso, la antigüedad y la validación del domicilio
   (recibo vs GPS).
   - Se muestra con un **velocímetro animado**, explica qué lo sube y qué lo baja, y define el **monto
     preaprobado**.
   - El admin lo ve en cada solicitud.

### 10. Pagos dentro del ecosistema
- Yape y las apps de banco se abren directo con el canal nativo (`apps_externas.dart`). El QR de Yape del
  negocio se muestra dentro de la app.
- El cliente sube la **foto del comprobante** desde la cámara y el admin la ve al confirmar el pago.

## Entregables
1. La app compilando sin errores (`flutter analyze` = 0 errores) y corriendo en el celular.
2. `flutter test` en verde, con pruebas para el score, el cálculo de cuotas, el carrito de créditos y la
   validación.
3. `firestore.rules` actualizado y la lista de colecciones.
4. `docs/cambios.md` con la tabla de la rúbrica y los tiempos de arranque.
5. La APK release: `flutter build apk --release`.
6. Un guion de demo de 5 minutos para el profesor: qué mostrar y en qué orden, siguiendo la rúbrica.
