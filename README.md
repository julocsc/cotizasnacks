# Cotizador Pro

Aplicación multiplataforma (**Android** y **Web**) para crear cotizaciones y
presupuestos, guardarlas en **Cloud Firestore** y generar **PDF** listos para
visualizar, imprimir, descargar o compartir.

- Flutter + Material Design 3 con diseño responsivo.
- Firebase Core + Cloud Firestore con escucha en tiempo real.
- **Acceso con correo y contraseña** (Firebase Authentication). Solo entra el
  personal autorizado por un administrador.
- **Gestión de personal**: el administrador crea cuentas, define permisos por
  sección, puede desactivar el acceso y eliminar los perfiles que agregó.
- **Reservas con datos del evento**: la cotización guarda lugar, tipo de evento,
  número de invitados y costo de movilidad. Al convertirla en reserva se
  definen la fecha, la hora de inicio y el abono inicial. Después se abre un
  asistente para agendar el evento en Google Calendar y enviar el resumen por
  WhatsApp al administrador y al creador de la cotización.
- **Celular con código de país** en cada perfil del personal, usado para las
  notificaciones de reservas.
- **Datos de la empresa configurables**: logotipo, nombre del negocio, número
  de móvil, dirección y sitio web o red social. Se guardan en Firestore y se
  usan en el encabezado y el pie del PDF.
- **Invitación por correo**: al agregar a alguien se genera una contraseña
  temporal, se abre el correo con la invitación y, en su primer inicio de
  sesión, la app le obliga a crear una contraseña propia.
- **Cambio de contraseña**: además del primer ingreso, cualquier usuario puede
  actualizarla desde el menú de su cuenta (avatar o menú lateral).
- **Pestaña Ingresos**: ventas netas, costos, utilidad y margen por fecha o por
  evento, usando el precio de compra del catálogo.
- **Costo de movilidad incluido en el total** de la cotización y de la reserva.
- **Pestaña Impresora**: genera la **boleta** de las reservas completadas y la
  **cotización de gastos** de cada reserva, agrupada en insumos, mano de obra y
  otros. Los costos por ítem se pueden ajustar y guardar antes de imprimir.
- `pdf` + `printing` para generar y compartir documentos A4.
- `intl` para moneda, fechas y cantidades en español (PEN por defecto).
- Selector de moneda: PEN, USD, EUR, JPY, GBP, AUD, CAD y CNY.
- Menú lateral de administración con productos, categorías, clientes, reservas,
  ingresos y personal.
- Imágenes de producto con `image_picker` guardadas como base64 en Firestore.

## Requisitos

- Flutter **3.47.9** o superior (Dart 3.13.7 o superior).
- Para Android: **JDK 17**, Android SDK con API 24 o superior y un emulador o
  dispositivo. Puedes usar Android Studio o las herramientas de línea de
  comandos (`sdkmanager`).
- Una cuenta de Firebase y un proyecto con **Cloud Firestore** y
  **Authentication > Correo electrónico** habilitados.
- FlutterFire CLI para generar las credenciales:

```bash
dart pub global activate flutterfire_cli
```

## Puesta en marcha

1. Instala las dependencias:

```bash
flutter pub get
```

2. Conecta tu proyecto de Firebase:

```bash
flutterfire configure --platforms=android,web
```

Este comando reemplaza `lib/firebase_options.dart` con los identificadores
reales de tu proyecto (los valores actuales son una plantilla con `REPLACE_`).
Si la app arranca sin configurar, muestra una pantalla con estas instrucciones
en lugar de fallar.

3. En la consola de Firebase:

   - Habilita **Authentication > Sign-in method > Correo electrónico/Email**
     (sin enlace mágico ni proveedores sociales).
   - Crea la base de datos de **Firestore**.
   - Publica las reglas incluidas en `firestore.rules`:

```bash
firebase deploy --only firestore:rules
```

   Las reglas toman `usuarios/{uid}` como fuente de verdad de roles y permisos.
   El rol `admin` tiene acceso completo; el personal solo accede a las
   secciones marcadas por el administrador.

4. **Crea el primer administrador** (una sola vez):

   - Cuenta inicial: **juliocesica@gmail.com** con contraseña **jucesica**.
     Créala en **Authentication > Users** (o regístrala desde la app si el
     proveedor de correo está habilitado) y cámbiala después del primer
     ingreso por una contraseña más segura.
   - El correo ya está configurado en `AppConfig.correosAdministradores`
     (`lib/core/app_config.dart`) y en la regla `create` de `usuarios`
     (`firestore.rules`). Al iniciar sesión, la app crea el perfil con rol de
     administrador automáticamente.
   - Opción alternativa: crea la cuenta, copia su UID y crea manualmente el
     documento `usuarios/{UID}` con este contenido:

```json
{
  "email": "juliocesica@gmail.com",
  "nombre": "Administrador",
  "rol": "admin",
  "activo": true,
  "debeCambiarPassword": false,
  "permisos": {
    "crearCotizaciones": true,
    "verHistorial": true,
    "gestionarProductos": true,
    "gestionarClientes": true,
    "gestionarReservas": true,
    "verIngresos": true
  }
}
```

   Después de entrar como administrador, usa la pestaña **Personal** para crear
   las cuentas del equipo. La app genera una contraseña temporal y abre el
   cliente de correo con la invitación lista para enviar. Si el cliente de
   correo no está disponible, la contraseña se puede copiar desde el diálogo.
   La persona deberá cambiarla en su primer inicio de sesión.
   La invitación incluye el enlace configurado en `AppConfig.urlAcceso`; si
   está vacío, solo se indican las credenciales.

5. Ejecuta la app:

```bash
flutter run -d chrome
flutter run -d android
```

6. Verificaciones:

```bash
flutter analyze
flutter test
flutter build web --release
```

## Estructura

```text
android/                              # Runner Android generado por Flutter
web/                                  # Runner Web (index.html, manifest, iconos)
lib/
├── main.dart                         # Inicialización de Firebase, tema y app
├── firebase_options.dart             # Plantilla de credenciales Firebase
├── core/app_config.dart              # Datos de empresa, moneda e impuesto
├── core/moneda.dart                  # Catálogo de monedas soportadas
├── models/
│   ├── cotizacion.dart               # Modelo analítico + toMap/fromMap
│   ├── item_cotizacion.dart          # Línea de cotización
│   ├── categoria_producto.dart       # Categoría del catálogo
│   ├── producto.dart                 # Producto, precios e imagen
│   ├── cliente.dart                  # Cliente del panel de administración
│   ├── reserva.dart                  # Reserva de producto por cliente
│   ├── usuario.dart                  # Perfil, rol y permisos del personal
│   ├── empresa_config.dart           # Datos y logo de la empresa emisora
│   └── ingreso.dart                  # Cálculo de ventas, costos y utilidad
├── services/
│   ├── auth_service.dart             # Login y administración de personal
│   ├── cotizacion_service.dart       # Guardar, escuchar, obtener y eliminar
│   ├── catalogo_service.dart         # Categorías y productos
│   ├── clientes_reservas_service.dart # Clientes y reservas
│   ├── empresa_service.dart          # Configuración de la empresa
│   └── pdf_service.dart              # Documento PDF formal
├── screens/
│   ├── auth_gate.dart                # Decide login, bloqueo o app principal
│   ├── login_screen.dart             # Acceso por correo y contraseña
│   ├── cambiar_password_screen.dart  # Cambio obligatorio de contraseña
│   ├── home_shell.dart               # Navegación adaptativa + menú lateral
│   ├── crear_cotizacion_screen.dart  # Formulario e ítems dinámicos
│   ├── historial_screen.dart         # StreamBuilder en tiempo real
│   ├── detalle_cotizacion_screen.dart
│   ├── pdf_preview_screen.dart       # PdfPreview, imprimir, compartir
│   └── admin/
│       ├── admin_screen.dart         # Panel con pestañas por permisos
│       ├── productos_admin_tab.dart  # Catálogo, búsqueda y categorías
│       ├── clientes_admin_tab.dart   # Gestión de clientes
│       ├── reservas_admin_tab.dart   # Gestión de reservas
│       ├── ingresos_admin_tab.dart   # Utilidad por fecha y por evento
│       ├── personal_admin_tab.dart   # Cuentas, roles y permisos
│       └── empresa_admin_tab.dart    # Logo y datos de la empresa
├── theme/app_theme.dart              # Material 3 claro/oscuro
├── utils/
│   ├── formatters.dart               # Formatos de moneda y fecha
│   ├── invitacion.dart               # Enlace mailto de invitación
│   ├── notificaciones_reserva.dart   # Enlaces de Google Calendar y WhatsApp
│   └── num_utils.dart                # Parseo y redondeo monetario
└── widgets/
    ├── section_header.dart
    ├── producto_imagen.dart          # Imagen base64 del producto
    ├── notificacion_reserva_dialog.dart # Agendar y notificar una reserva
    └── empresa_logo.dart             # Logo base64 de la empresa
```

Los runners de Android y Web se generaron con Flutter 3.47.9. El manifest de
Android ya incluye el permiso `INTERNET` necesario para Firestore en release.

## Esquema de Firestore

Colección: `cotizaciones` (el ID del documento lo genera Firestore).

```json
{
  "numeroCotizacion": "COT-20261030-183000123",
  "cliente": {
    "nombre": "María López",
    "telefono": "5555555555",
    "email": "maria@example.com"
  },
  "fecha": "2026-10-30T18:30:00.000Z",
  "fechaTimestamp": "<Firestore Timestamp>",
  "items": [
    {
      "descripcion": "Consultoría",
      "cantidad": 4,
      "precioUnitario": 250,
      "total": 1000
    }
  ],
  "subtotal": 1000,
  "aplicarImpuesto": true,
  "porcentajeImpuesto": 16,
  "impuesto": 160,
  "total": 1160,
  "moneda": "PEN",
  "notas": "Pago a 15 días.",
  "lugar": "Salón Real",
  "tipoEvento": "Boda",
  "numeroInvitados": 120,
  "costoMovilidad": 150,
  "estado": "emitida",
  "versionEsquema": 1,
  "origen": "flutter_app",
  "creadoEn": "<serverTimestamp>"
}
```

Decisiones pensadas para analítica y BI:

- `fecha` está en **ISO 8601 UTC** para exportación directa.
- `fechaTimestamp` es un `Timestamp` tipado para consultas y BigQuery.
- `subtotal`, `impuesto` y `total` son números, no texto.
- `items` es un arreglo de mapas con `total` por línea, listo para exportarse
  como `REPEATED RECORD` en BigQuery.
- `creadoEn` usa `FieldValue.serverTimestamp()` para auditoría.
- `lugar`, `tipoEvento`, `numeroInvitados` y `costoMovilidad` describen el
  evento cotizado. La fecha, la hora y el abono inicial se capturan al convertir
  la cotización en reserva.
- `versionEsquema` y `origen` permiten evolucionar el documento.

### Colecciones del panel de administración

El menú lateral abre el panel con las pestañas permitidas: **Productos**,
**Clientes**, **Reservas**, **Ingresos**, **Personal** y **Mi empresa**. Un
miembro del personal solo ve las pestañas que el administrador marcó en sus
permisos; **Personal** y **Mi empresa** son exclusivas del administrador.

- `categorias_productos`: `{ nombre, creadoEn }`.
- `productos`: `{ nombre, categoriaId, categoriaNombre, descripcion,
  precioCompra, precioVenta, imagenBase64, activo, creadoEn, actualizadoEn }`.
  La imagen se guarda optimizada como base64 (máximo 600 KB antes de codificar)
  para no requerir Firebase Storage. Si necesitas imágenes grandes, cambia este
  campo por una URL de Firebase Storage.
- `clientes`: `{ nombre, telefono, email, documento, notas, creadoEn }`.
- `reservas`: `{ clienteId, clienteNombre, productoId, productoNombre, fecha,
  fechaTimestamp, cantidad, estado, notas, lugar, tipoEvento, numeroInvitados,
  costoMovilidad, abonoInicial, moneda, creadoPorUid, creadoPorNombre,
  creadoPorEmail, creadoPorTelefono, creadoEn }`. `fecha` guarda la fecha y
  hora de inicio del evento. Los campos `creadoPor*` identifican al usuario que
  creó la cotización de origen para enviarle el aviso de WhatsApp.
- `usuarios`: `{ email, nombre, telefono, rol, activo, debeCambiarPassword,
  permisos, creadoEn, actualizadoEn, creadoPor, actualizadoPor }`. El documento
  usa el UID de Firebase Auth. `telefono` debe incluir el código de país, por
  ejemplo `+51 999 999 999`, y se usa para las notificaciones por WhatsApp.
  `rol` puede ser `admin` o `personal`. `permisos` contiene los booleanos
  `crearCotizaciones`, `verHistorial`, `gestionarProductos`,
  `gestionarClientes`, `gestionarReservas` y `verIngresos`.
  `debeCambiarPassword` se activa al crear una cuenta y el propio usuario lo
  desactiva al guardar su contraseña definitiva.
- `usuarios_eliminados`: copia del perfil cuando el administrador elimina a
  una persona, con `eliminadoEn` y `eliminadoPor`. Se usa para restaurar el
  acceso si se vuelve a invitar el mismo correo. Solo el administrador puede
  leerlo o modificarlo.
- `configuracion/empresa`: `{ nombre, eslogan, telefono, telefonoAdministrador,
  email, direccion, sitioWeb, logoBase64, actualizadoEn }`. Contiene los datos
  que aparecen en el PDF y el WhatsApp del administrador que recibe los avisos
  de reservas. Todo el personal activo puede leerlos; solo el administrador los
  modifica.

Los estados de una reserva son `pendiente`, `confirmada`, `completada` y
`cancelada`. Las colecciones se escuchan en tiempo real con `StreamBuilder`.

### Agenda y avisos de reservas

Al convertir una cotización en reserva, el asistente pide la **fecha**, la
**hora de inicio** y el **abono inicial**; el lugar, el tipo de evento, los
invitados y el costo de movilidad se toman de la cotización. Después se muestra
el aviso **Agendar y notificar** con dos destinatarios: el administrador y el
creador de la cotización. Para cada uno se puede:

- **Abrir Google Calendar** con el evento ya preparado (cliente, lugar, tipo de
  evento, invitados, fecha, hora, costo de movilidad y abono inicial).
- **Enviar WhatsApp** con el resumen y el enlace del calendario, para que el
  destinatario agregue el evento a su propia agenda.

La app no inserta eventos directamente en calendarios ajenos porque Google
Calendar exige autorización OAuth del dueño de cada agenda y no hay backend ni
almacenamiento de tokens. Los enlaces oficiales de Calendar y `wa.me` funcionan
sin credenciales adicionales y no requieren WhatsApp Business API.

Para que los avisos funcionen:

1. Registra el celular de cada persona con código de país en **Personal**
   (por ejemplo `+51 999 999 999`).
2. Configura el **WhatsApp del administrador** en **Mi empresa**. Si se deja
   vacío, se usa el móvil de la empresa.
3. La persona que abre el enlace de Google Calendar debe tener sesión iniciada
   en la cuenta de Google donde quiere guardar el evento.

Si más adelante necesitas inserción automática en ambos calendarios y envío de
WhatsApp sin intervención, agrega un backend con OAuth de Google Calendar y la
API de WhatsApp Business; el cliente Flutter no puede hacerlo por sí solo.

### Cálculo de ingresos

La pestaña **Ingresos** trabaja con las cotizaciones y reservas existentes:

- **Ventas netas**: `subtotal` de cada cotización (sin impuestos).
- **Costos**: `precioCompra` actual del producto asociado a cada línea,
  multiplicado por la cantidad. Las líneas manuales sin `productoId` no suman
  costo y la interfaz lo advierte.
- **Utilidad**: ventas netas menos costos.
- **Margen**: utilidad dividida entre ventas netas.
- **Por fecha**: agrupa por día, mes o año y permite filtrar por período.
- **Por evento**: cruza cada reserva con su `cotizacionId` o
  `cotizacionNumero` para mostrar la utilidad del evento. Las reservas sin
  cotización vinculada se muestran, pero sin utilidad calculable.

Para que la utilidad sea exacta, registra el `precioCompra` de todos los
productos del catálogo antes de cotizar.

### Ejemplo de consulta para BigQuery

```sql
SELECT
  c.numeroCotizacion,
  TIMESTAMP(c.fecha) AS fecha_emision,
  c.cliente.nombre AS cliente,
  c.total,
  item.descripcion,
  item.cantidad,
  item.total AS total_linea
FROM `TU_PROYECTO.firestore_export.cotizaciones_raw_latest` AS c,
UNNEST(c.items) AS item
ORDER BY fecha_emision DESC;
```

El nombre exacto de la tabla depende de la extensión de exportación de
Firestore a BigQuery. En Looker Studio puedes usar `fechaTimestamp` como
dimensión de fecha y `total` como métrica.

## Personalización

- **Datos de la empresa que aparecen en el PDF:** pestaña **Mi empresa** del
  panel de administración (nombre, eslogan, móvil, dirección, sitio web y
  logotipo). Se guardan en `configuracion/empresa`.
- **WhatsApp del administrador:** pestaña **Mi empresa**. Recibe los avisos de
  reservas; si está vacío se usa el móvil de la empresa.
- **Celular del personal:** pestaña **Personal**. Debe incluir el código de
  país para que el enlace `wa.me` funcione.
- **Valores iniciales de la empresa:** `lib/core/app_config.dart`. Se usan
  mientras el administrador no guarde la configuración desde la app.
- **Correos administradores iniciales:** `AppConfig.correosAdministradores`.
- **URL de acceso en las invitaciones:** `AppConfig.urlAcceso`.
- **Moneda y locale:** `AppConfig.moneda` y `AppConfig.locale`. El catálogo de
  monedas disponibles se define en `lib/core/moneda.dart`.
- **Impuesto inicial:** `AppConfig.impuestoPredeterminado` (18 % por defecto).
- **Colores del tema:** `lib/theme/app_theme.dart`.

## Seguridad y producción

- Habilita solo el proveedor **Correo electrónico** en Firebase Authentication.
- Publica `firestore.rules`; las reglas validan el rol y los permisos del
  documento `usuarios/{uid}`. No uses reglas abiertas en producción.
- Cambia `AppConfig.correosAdministradores` por el correo real del dueño del
  negocio y sincroniza la lista con la regla `create` de `usuarios`. La
  configuración actual reconoce a **juliocesica@gmail.com**.
- El administrador puede desactivar el acceso de una persona sin borrar su
  cuenta de Firebase Auth. La app bloquea el ingreso si `activo` es `false`.
- **Eliminar personal**: la pestaña **Personal** permite borrar el perfil de
  una persona agregada por el administrador. El perfil se mueve a
  `usuarios_eliminados` y la persona pierde el acceso de inmediato. La cuenta
  de Firebase Authentication no se puede borrar desde el cliente; si más
  adelante se vuelve a invitar el mismo correo, la app restaura el perfil y
  envía un enlace para restablecer la contraseña. Para borrar la cuenta de
  Authentication definitivamente, usa la consola de Firebase o el Admin SDK.
- Las invitaciones se envían con el cliente de correo del administrador
  (`mailto:`), por lo que la contraseña temporal no viaja a un servidor
  intermedio. Para envíos automáticos sin intervención, sustituye esta lógica
  por una Cloud Function con un proveedor transaccional (SendGrid, Resend,
  Amazon SES, etc.) y no incrustes claves privadas en la app.
- La regla de `usuarios` permite al usuario cambiar únicamente su campo
  `debeCambiarPassword`; rol, estado y permisos siguen reservados al admin.
- Si necesitas borrar cuentas de Authentication, hazlo desde la consola de
  Firebase o con Firebase Admin SDK/Cloud Functions; el cliente no puede
  eliminarlas.
- Habilita Firebase App Check para Android/Web.
- Valida los totales también en el servidor (Cloud Functions) si la cotización
  se usará para facturación.
- Configura copias de seguridad/exportaciones de Firestore.
- Revisa la política de privacidad: los documentos contienen datos personales
  del cliente (nombre, teléfono y email).
- La vista previa de PDF en Web utiliza `pdf.js`; `printing` lo carga
  automáticamente desde CDN. Para un despliegue totalmente offline, aloja
  `pdf.js` localmente y configura `dartPdfJsBaseUrl` en `web/index.html`.

## Notas sobre versiones

Las versiones de `pubspec.yaml` están fijadas para la combinación actual de
Flutter 3.47.x / Dart 3.13.x. Si usas una versión anterior de Flutter, actualiza
el SDK o ajusta `pdf`, `printing` e `intl` a versiones compatibles; no mezcles
versiones mayores de los plugins de FlutterFire entre sí.
