# Limitaciones conocidas

Estas limitaciones son conscientes. Vienen del plan gratuito de Firebase (Spark) y de servicios externos.
Conviene que las conozcan el dueño del negocio y quien atiende a los clientes.

## 1. El cronograma se calcula en el celular

- El simulador y la solicitud calculan las cuotas en el celular del cliente.
- Al **aprobar**, el cronograma definitivo se recalcula en el celular del **administrador**, a partir del monto,
  el plazo y la tasa de la solicitud.
- Las reglas de Firestore verifican que la solicitud use la tasa oficial (60 % TEA) y que el monto y el plazo
  estén dentro de los límites. **No** verifican cada cuota: confían en el cálculo del administrador.
- **Para producción a mayor escala:** calcular y validar el cronograma en un servidor de confianza (Cloud
  Functions). Esto requiere el plan Blaze.
- Si cambias la tasa o los límites, hay que cambiarlos en `lib/config_prestamos.dart` **y** en
  `firestore.rules` (`solicitudValida`) y volver a publicar las reglas.

## 2. Yape no permite precargar el monto

- La app abre Yape (o la Play Store si no está instalado), pero Yape **no ofrece un enlace público** para
  abrir un pago con el número y el monto ya escritos.
- El cliente copia el número y el monto desde la app (hay botones "Copiar") y paga en Yape.
- Después escribe el **número de operación** y el administrador lo verifica en su Yape antes de confirmar.
- Con Plin pasa lo mismo: el cliente paga desde la app de su banco.

## 3. Los mapas se abren en Google Maps

- El administrador ve la ubicación del cliente con los botones "Ver en mapa" y "Cómo llegar", que abren la
  app de **Google Maps**. No hay un mapa dentro de la app.
- Integrar Google Maps en la app requiere una clave de Google Maps Platform (con tarjeta) y la dependencia
  `google_maps_flutter`.
- La ubicación se registra **solo mientras la app está abierta** (cada 2 minutos como máximo y con 50 m de
  movimiento). No hay rastreo en segundo plano.

## 4. La identidad se verifica manualmente

- La selfie y las fotos del DNI las **revisa una persona**. La app no comprueba automáticamente que el
  rostro coincida con el DNI, que el DNI sea auténtico ni que los datos coincidan con RENIEC.
- Para automatizarlo hace falta un proveedor de verificación de identidad (servicio de pago).

## 5. Las fotos se guardan en Firestore (sin Storage)

- El plan Spark no incluye Firebase Storage. Las fotos se comprimen a unos 60–160 KB y se guardan en base64.
- Alcanzan para unos 2 000 clientes dentro del espacio gratuito.
- Ver `docs/migracion_storage.md` para migrar cuando haga falta.

## 6. Los recordatorios dependen de que el cliente abra la app

- Los avisos de vencimiento se programan **en el celular** cuando el cliente abre la app.
- Si el préstamo se aprueba y el cliente no vuelve a abrir la app, ese préstamo no tendrá recordatorios.
- Si el cliente desactiva las notificaciones, no recibe avisos.
- Los avisos son aproximados: Android puede retrasarlos unos minutos para ahorrar batería.
- Las notificaciones push enviadas desde un servidor requieren Cloud Functions (plan Blaze).

## 7. Funciones pendientes por reglas de negocio

No se implementaron hasta que se definan sus reglas:
- **Pago adelantado** de cuotas futuras.
- **Cancelación total** anticipada (con recálculo de intereses).
- **Mora** e intereses moratorios por atraso.

Hoy, una cuota vencida solo se marca como "Vencida" en rojo. No genera cargos extra.

## 8. Recuperación de contraseña

- Funciona con el **enlace por correo** de Firebase.
- No hay códigos numéricos ni SMS. Ver `docs/recuperacion_contrasena.md` para opciones y costos.
