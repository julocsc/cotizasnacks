/// Configuración general de la aplicación y de la empresa emisora.
///
/// Personaliza estos valores antes de publicar la app. Se usan en la interfaz
/// y en el encabezado del PDF.
abstract final class AppConfig {
  static const String nombreApp = 'Cotizador Pro';
  static const String nombreEmpresa = 'Mi Empresa';
  static const String eslogan = 'Soluciones profesionales';
  static const String telefonoEmpresa = '+51 999 999 999';
  static const String emailEmpresa = 'contacto@miempresa.com';
  static const String direccionEmpresa = 'Lima, Perú';

  /// URL pública de la app que se incluye en la invitación por correo.
  ///
  /// Déjala vacía si aún no publicas la app; en ese caso el correo solo
  /// indicará que la persona debe ingresar al cotizador.
  static const String urlAcceso = '';

  /// Prefijo telefónico del país usado por defecto en los formularios.
  static const String prefijoTelefono = '+51';

  /// Código ISO de la moneda predeterminada que se guarda en Firestore.
  ///
  /// Las monedas disponibles están definidas en `lib/core/moneda.dart`.
  static const String moneda = 'PEN';

  /// Locale usado por `intl` para fechas y cantidades.
  static const String locale = 'es_PE';

  /// Nombre del impuesto aplicado en las cotizaciones.
  static const String nombreImpuesto = 'IGV';

  /// Porcentaje del IGV peruano que se propone al crear una cotización.
  static const double impuestoPredeterminado = 18;

  /// Versión del esquema del documento. Ayuda a evolucionar la estructura sin
  /// romper tableros de BI o consumidores antiguos.
  static const int versionEsquema = 1;

  /// Correos que se reconocen como administradores al iniciar sesión.
  ///
  /// Si una cuenta de Firebase Auth con uno de estos correos aún no tiene
  /// perfil en `usuarios/{uid}`, la app crea automáticamente el perfil con
  /// todos los permisos. Cambia esta lista por el correo real del dueño del
  /// negocio antes de publicar la aplicación.
  static const List<String> correosAdministradores = <String>[
    'juliocesica@gmail.com',
  ];

  static bool esCorreoAdministrador(String email) {
    final normalizado = email.trim().toLowerCase();
    return correosAdministradores
        .map((correo) => correo.trim().toLowerCase())
        .contains(normalizado);
  }
}
