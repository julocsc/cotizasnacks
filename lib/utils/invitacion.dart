import '../core/app_config.dart';

/// Construye el enlace `mailto:` con la invitación para una cuenta nueva.
///
/// La contraseña temporal solo se comparte en este correo y la app obliga a
/// cambiarla en el primer inicio de sesión.
Uri crearUriInvitacion({
  required String email,
  required String nombre,
  required String passwordTemporal,
  bool cuentaRestaurada = false,
}) {
  final saludo = nombre.trim().isEmpty ? 'Hola,' : 'Hola ${nombre.trim()},';
  final urlAcceso = AppConfig.urlAcceso.trim();

  final lineas = <String>[
    saludo,
    '',
    cuentaRestaurada
        ? 'Tu acceso a ${AppConfig.nombreApp} fue reactivado.'
        : 'Se creó tu acceso a ${AppConfig.nombreApp}.',
    '',
    'Correo: $email',
    if (!cuentaRestaurada) 'Contraseña temporal: $passwordTemporal',
    if (cuentaRestaurada)
      'Te enviamos un correo para restablecer tu contraseña. Si recuerdas tu '
          'contraseña anterior, también puedes usarla.',
    '',
    if (urlAcceso.isNotEmpty) 'Ingresa en: $urlAcceso',
    'Por seguridad, en tu primer inicio de sesión la app te pedirá crear '
        'una nueva contraseña.',
    '',
    'Administración de ${AppConfig.nombreEmpresa}.',
  ];

  return Uri(
    scheme: 'mailto',
    path: email.trim(),
    queryParameters: <String, String>{
      'subject': 'Invitación a ${AppConfig.nombreApp}',
      'body': lineas.join('\n'),
    },
  );
}
