import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';

/// Datos de la empresa que emite las cotizaciones.
///
/// Se guardan en `configuracion/empresa` para que el administrador pueda
/// personalizar el encabezado y el pie del PDF sin recompilar la app. Los
/// valores iniciales provienen de [AppConfig].
class EmpresaConfig {
  const EmpresaConfig({
    this.nombre = AppConfig.nombreEmpresa,
    this.eslogan = AppConfig.eslogan,
    this.telefono = AppConfig.telefonoEmpresa,
    this.email = AppConfig.emailEmpresa,
    this.direccion = AppConfig.direccionEmpresa,
    this.sitioWeb = '',
    this.telefonoAdministrador = '',
    this.logoBase64 = '',
    this.actualizadoEn,
  });

  final String nombre;
  final String eslogan;

  /// Número de móvil o teléfono de contacto de la empresa.
  final String telefono;
  final String email;
  final String direccion;

  /// Celular del administrador con código de país, usado para las
  /// notificaciones de reservas por WhatsApp.
  ///
  /// Si está vacío se usa [telefono] como respaldo.
  final String telefonoAdministrador;

  /// Número que recibe las notificaciones del administrador.
  String get whatsappAdministrador {
    final numero = telefonoAdministrador.trim();
    return numero.isNotEmpty ? numero : telefono.trim();
  }

  /// Sitio web, fan page o red social de la empresa.
  final String sitioWeb;

  /// Logotipo optimizado y codificado en base64.
  ///
  /// Se guarda en Firestore para no depender de Firebase Storage. Si está
  /// vacío, el PDF usa las iniciales del nombre del negocio.
  final String logoBase64;

  final DateTime? actualizadoEn;

  factory EmpresaConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EmpresaConfig();

    return EmpresaConfig(
      nombre: _texto(map['nombre'], fallback: AppConfig.nombreEmpresa),
      eslogan: _texto(map['eslogan']),
      telefono: _texto(map['telefono']),
      email: _texto(map['email']),
      direccion: _texto(map['direccion']),
      sitioWeb: _texto(map['sitioWeb']),
      telefonoAdministrador: _texto(map['telefonoAdministrador']),
      logoBase64: _texto(map['logoBase64']),
      actualizadoEn: _fecha(map['actualizadoEn']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nombre': nombre.trim(),
      'eslogan': eslogan.trim(),
      'telefono': telefono.trim(),
      'email': email.trim().toLowerCase(),
      'direccion': direccion.trim(),
      'sitioWeb': sitioWeb.trim(),
      'telefonoAdministrador': telefonoAdministrador.trim(),
      'logoBase64': logoBase64,
    };
  }

  EmpresaConfig copyWith({
    String? nombre,
    String? eslogan,
    String? telefono,
    String? email,
    String? direccion,
    String? sitioWeb,
    String? telefonoAdministrador,
    String? logoBase64,
    DateTime? actualizadoEn,
  }) {
    return EmpresaConfig(
      nombre: nombre ?? this.nombre,
      eslogan: eslogan ?? this.eslogan,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      sitioWeb: sitioWeb ?? this.sitioWeb,
      telefonoAdministrador:
          telefonoAdministrador ?? this.telefonoAdministrador,
      logoBase64: logoBase64 ?? this.logoBase64,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  static String _texto(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final texto = value.trim();
      if (texto.isNotEmpty) return texto;
    }
    return fallback;
  }

  static DateTime? _fecha(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
