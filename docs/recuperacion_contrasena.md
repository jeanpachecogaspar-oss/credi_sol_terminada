# Recuperación de contraseña

## Lo que funciona hoy (gratis, plan Spark)

La app usa el **enlace de recuperación de Firebase** (`sendPasswordResetEmail`):

1. El cliente escribe su correo en "¿Olvidaste tu contraseña?".
2. Firebase le envía un correo en español con un enlace.
3. El enlace abre una página de Firebase donde escribe su nueva contraseña.

No cuesta nada y no requiere servidor.

### Mejoras recomendadas en la consola (sin programar)

En **Firebase Console → Authentication → Plantillas → Restablecimiento de contraseña**:

- **Nombre del remitente:** pon el nombre de la app, por ejemplo "CrediSol".
- **Asunto y texto:** revisa que estén en español y explica que el enlace vence.
- **Dirección de respuesta:** usa el correo de soporte real.
- **Dominio propio (opcional):** si tienes un dominio, puedes enviar desde `noreply@tudominio.pe`.
  Así se reduce la probabilidad de que el correo llegue a spam.

Aviso para los clientes: el correo puede tardar unos minutos y a veces llega a **Spam** o **Promociones**.

---

## Alternativas con código numérico (NO implementadas)

Ninguna de las dos se puede hacer bien con el plan Spark tal como está. Decide una antes de implementarla.

### Opción A: código por correo con Cloud Functions

**Cómo funcionaría**
1. El cliente pide el código. Una Cloud Function genera un código de 6 dígitos, guarda su *hash* en Firestore
   con una caducidad de 10 minutos y lo envía por correo.
2. El cliente escribe el código y su nueva contraseña.
3. Otra Cloud Function valida el código (máximo 5 intentos) y cambia la contraseña con el Admin SDK.

**Requisitos**
- **Plan Blaze** (requiere tarjeta), obligatorio para desplegar Cloud Functions.
- Un **servicio de envío de correo**: Resend, SendGrid, Brevo, o Gmail SMTP para volúmenes muy bajos.
- Programar y mantener 2 funciones y sus reglas.

**Costos aproximados** (verifica los precios vigentes antes de decidir)
- Cloud Functions: el nivel gratuito de Blaze incluye 2 millones de invocaciones al mes. Para esta app el costo
  sería prácticamente S/ 0.
- Correo: Resend y Brevo tienen planes gratuitos de unos cientos de correos al día.
- Riesgo: con Blaze activado, un error o un abuso puede generar cobros. Configura una **alerta de presupuesto**
  en Google Cloud (por ejemplo, US$ 5).

### Opción B: código SMS con Firebase Phone Auth

**Cómo funcionaría**
1. El cliente escribe su celular y recibe un SMS con un código (Firebase lo envía).
2. Al validarlo, la app vincula el número a la cuenta y permite cambiar la contraseña.

**Requisitos**
- Habilitar el proveedor **Teléfono** en Authentication.
- Configurar las huellas **SHA-1 y SHA-256** de la app en Firebase, y Play Integrity para Android.
- Cambiar el flujo de la app: el cliente tendría que **verificar su celular al registrarse**. Si no, el número
  no estaría vinculado y no serviría para recuperar la cuenta.
- En la práctica requiere el **plan Blaze**: Firebase cobra cada SMS y en el plan Spark los SMS están muy limitados.

**Costos aproximados**
- Cada SMS a Perú tiene un costo (consulta la tabla de precios de Firebase Phone Auth por país). Además, los
  reintentos y los intentos fraudulentos (*SMS pumping*) también se cobran.
- Es la opción más cara y la que más configuración necesita.

### Recomendación

1. **Mantener el enlace por correo** mientras la app esté en el plan Spark. Funciona, es gratuito y es seguro.
2. Si después se activa Blaze por otros motivos (Storage, funciones del servidor), la **opción A** es la más
   barata y controlable.
3. Usar SMS (**opción B**) solo si muchos clientes no tienen acceso a su correo.
