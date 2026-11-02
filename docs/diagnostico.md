# Diagnóstico de CrediSol frente a la rúbrica (02/11/2026)

> **Actualización:** los puntos 1, 2, 3, 5, 9 y el RUC del punto 4 ya se implementaron (ver `docs/cambios.md`,
> sección 2d). Siguen pendientes: compilar y probar en el celular, el mapa dentro de la app, la huella, el modo
> oscuro y el gráfico/PDF del historial.

CrediSol es una **app de préstamos (financiera)**. Todo lo que se agregue debe tener sentido para un negocio
de créditos: nada de "tienda", abarrotes ni equipos.

Leyenda: ✅ cumple · ⚠️ cumple a medias · ❌ no cumple

| # | Criterio de la rúbrica | Estado | Diagnóstico |
|---|---|---|---|
| 1 | **Catálogo / 40 productos con imágenes en el carrito** | ❌ | Se implementó como **tienda** (abarrotes y luego equipos a crédito). Eso **no corresponde** a una financiera. Para CrediSol, los "productos" deben ser **productos financieros**: tipos de crédito, cada uno con su imagen, monto, plazo y tasa. El "carrito" debe ser **"Mis créditos seleccionados"**: el cliente agrega uno o varios créditos, compara cuotas y envía la solicitud |
| 2 | **Login con animación 3D** | ❌ | El login actual solo tiene un fundido. **Se quitó la animación 3D que pidió el profe.** Falta un login moderno con efecto 3D real (perspectiva, profundidad e inclinación con el giroscopio) |
| 3 | **Entrar rápido** | ⚠️ | El splash bajó de 3.2 s a unos 0.9 s, pero aún hay **pantallas en cadena**: splash nativo → splash de Flutter → AuthGate (lee el perfil en Firestore) → UbicacionGate (GPS) → Inicio. Falta: un solo splash, guardar el rol en caché local, no esperar al GPS para mostrar el inicio y medir los tiempos con DevTools |
| 4 | **Autenticación (registro mínimo + API DNI/RUC apisperu)** | ⚠️ | El registro pide DNI, celular, correo y contraseña, y consulta RENIEC con apisperu. **Falta el token** en `lib/apis_peru.dart`: sin él, el nombre se escribe a mano. No hay ingreso con huella ni "recordarme". El RUC está en la tienda, que se va a eliminar: debe pasar a la **solicitud de crédito para negocio** |
| 5 | **Dos botones: sensores y cámara** | ⚠️ | Existen ("Escanear" y "Agita y descubre"), pero dentro de la tienda y con productos de tienda. Deben tener **uso financiero**: la cámara para escanear el DNI o el recibo y autocompletar datos, y el sensor para el modo privado o la verificación de presencia |
| 6 | **Historial de préstamos** | ✅ | "Mis préstamos" tiene un resumen y filtros Todos / En curso / Historial. Se puede mejorar con un gráfico y un PDF del cronograma |
| 7 | **Geolocalización + comparación con recibo de luz o agua** | ✅ | La OCR del recibo se compara con la dirección escrita y con el GPS (distancia en metros), y el admin lo ve. **Falta un mapa dentro de la app**: hoy abre Google Maps afuera |
| 8 | **UX/UI: agradable, fácil de usar, colores y diseño** | ⚠️ | Los colores son coherentes (azul y dorado), pero cada pantalla define sus propios estilos. No hay modo oscuro, tipografía de marca, transiciones uniformes ni estados de carga con skeleton |
| 9 | **2 funcionalidades llamativas y complejas** | ⚠️ | 1) La validación de identidad con IA en el celular (rostro, OCR del DNI y del recibo, distancia al GPS) **sí cuenta**. 2) "Agita y descubre" es de tienda y **no suma** en una financiera. Falta una segunda función llamativa propia de una financiera |
| 10 | **APIs dentro de la app (no mandar afuera)** | ✅ | Yape abre directo con un canal nativo, sin pasar por la Play Store. Las validaciones de ML Kit y la geocodificación corren en el celular |
| 11 | **Compila y corre** | ❌ | **Nada de lo nuevo se ha compilado todavía.** La laptop no tiene el Android SDK (`flutter doctor`: Android toolchain ✗). Hay que instalar Android Studio o compilar en la nube antes de presentar |

## Lo que hay que quitar

- La pestaña **Equipos/Tienda**: `tienda_screen.dart`, `carrito_screen.dart`, `admin_tienda_screen.dart`,
  `catalogo_ejemplo.dart`, `tienda_modelos.dart`, `config_tienda.dart` y `drive_imagen.dart` (las imágenes de
  Drive se pueden reutilizar), la colección `pedidos` y sus reglas.
- "Agita y descubre" como producto sorpresa.

## Lo que hay que conservar

Simulador y cronograma (sistema francés y TCEA), solicitud en 3 pasos, validación con IA (selfie, DNI y
recibo con GPS), Yape y Plin nativos, cobranzas, recordatorios, historial, promociones por cliente
(convertidas en **tasas preferenciales por cliente**), consulta DNI y RUC con apisperu, y reglas de Firestore.

## Riesgos

1. **Sin compilar:** pueden aparecer errores de `flutter analyze` en los archivos nuevos (paquetes ML Kit 0.17,
   geocoding 5, sensors_plus 7).
2. **Reglas sin publicar:** si no se publica `firestore.rules`, saldrá "No tienes permiso".
3. **Token de apisperu vacío:** el DNI no se autocompleta.
4. **Plan Spark:** no hay Cloud Functions; la validación ocurre en el celular y el admin aprueba.
