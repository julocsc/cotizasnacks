import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles disponibles dentro del cotizador.
abstract final class RolUsuario {
  static const String administrador = 'admin';
  static const String personal = 'personal';

  static const List<String> todos = <String>[administrador, personal];

  static String etiqueta(String rol) {
    switch (rol) {
      case administrador:
        return 'Administrador';
      case personal:
        return 'Personal';
      default:
        return rol;
    }
  }
}

/// Permisos que el administrador puede habilitar a cada miembro del personal.
///
/// El rol de administrador siempre tiene todos los permisos, sin importar los
/// valores guardados en este objeto.
class PermisosUsuario {
  const PermisosUsuario({
    this.crearCotizaciones = true,
    this.verHistorial = true,
    this.gestionarProductos = false,
    this.gestionarClientes = false,
    this.gestionarReservas = false,
    this.verIngresos = false,
  });

  /// Permisos completos para un administrador.
  static const PermisosUsuario administrador = PermisosUsuario(
    crearCotizaciones: true,
    verHistorial: true,
    gestionarProductos: true,
    gestionarClientes: true,
    gestionarReservas: true,
    verIngresos: true,
  );

  /// Permisos iniciales de un miembro del personal.
  static const PermisosUsuario personal = PermisosUsuario();

  final bool crearCotizaciones;
  final bool verHistorial;
  final bool gestionarProductos;
  final bool gestionarClientes;
  final bool gestionarReservas;
  final bool verIngresos;

  bool get tieneAccesoAdministracion =>
      gestionarProductos ||
      gestionarClientes ||
      gestionarReservas ||
      verIngresos;

  factory PermisosUsuario.fromMap(Map<String, dynamic>? map) {
    if (map == null) return personal;
    bool leer(String clave, bool fallback) {
      final valor = map[clave];
      return valor is bool ? valor : fallback;
    }

    return PermisosUsuario(
      crearCotizaciones: leer('crearCotizaciones', true),
      verHistorial: leer('verHistorial', true),
      gestionarProductos: leer('gestionarProductos', false),
      gestionarClientes: leer('gestionarClientes', false),
      gestionarReservas: leer('gestionarReservas', false),
      verIngresos: leer('verIngresos', false),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'crearCotizaciones': crearCotizaciones,
      'verHistorial': verHistorial,
      'gestionarProductos': gestionarProductos,
      'gestionarClientes': gestionarClientes,
      'gestionarReservas': gestionarReservas,
      'verIngresos': verIngresos,
    };
  }

  PermisosUsuario copyWith({
    bool? crearCotizaciones,
    bool? verHistorial,
    bool? gestionarProductos,
    bool? gestionarClientes,
    bool? gestionarReservas,
    bool? verIngresos,
  }) {
    return PermisosUsuario(
      crearCotizaciones: crearCotizaciones ?? this.crearCotizaciones,
      verHistorial: verHistorial ?? this.verHistorial,
      gestionarProductos: gestionarProductos ?? this.gestionarProductos,
      gestionarClientes: gestionarClientes ?? this.gestionarClientes,
      gestionarReservas: gestionarReservas ?? this.gestionarReservas,
      verIngresos: verIngresos ?? this.verIngresos,
    );
  }
}

/// Perfil de un usuario autorizado para usar el cotizador.
///
/// Se guarda en `usuarios/{uid}` y se vincula con la cuenta de Firebase Auth
/// mediante el UID. El administrador es el único que puede crear o modificar
/// estos documentos desde la aplicación.
class Usuario {
  const Usuario({
    required this.uid,
    required this.email,
    required this.nombre,
    this.telefono = '',
    this.rol = RolUsuario.personal,
    this.activo = true,
    this.debeCambiarPassword = false,
    this.permisos = PermisosUsuario.personal,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String uid;
  final String email;
  final String nombre;

  /// Número de celular con código de país (por ejemplo `+51 999 999 999`).
  ///
  /// Se usa para enviar las notificaciones de reservas por WhatsApp.
  final String telefono;
  final String rol;
  final bool activo;

  /// `true` mientras el usuario conserva la contraseña temporal y debe crear
  /// una nueva antes de entrar al cotizador.
  final bool debeCambiarPassword;
  final PermisosUsuario permisos;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get esAdministrador => rol == RolUsuario.administrador;

  bool get puedeCrearCotizaciones =>
      esAdministrador || permisos.crearCotizaciones;
  bool get puedeVerHistorial => esAdministrador || permisos.verHistorial;
  bool get puedeGestionarProductos =>
      esAdministrador || permisos.gestionarProductos;
  bool get puedeGestionarClientes =>
      esAdministrador || permisos.gestionarClientes;
  bool get puedeGestionarReservas =>
      esAdministrador || permisos.gestionarReservas;
  bool get puedeVerIngresos => esAdministrador || permisos.verIngresos;
  bool get puedeGestionarPersonal => esAdministrador;

  bool get tieneAccesoAdministracion =>
      puedeGestionarProductos ||
      puedeGestionarClientes ||
      puedeGestionarReservas ||
      puedeVerIngresos ||
      puedeGestionarPersonal;

  bool get tieneAlgunPermiso =>
      puedeCrearCotizaciones || puedeVerHistorial || tieneAccesoAdministracion;

  /// Inicial del nombre o del correo para los avatares de la interfaz.
  String get inicial {
    final base = nombre.trim().isNotEmpty ? nombre.trim() : email.trim();
    return base.isEmpty ? '?' : base[0].toUpperCase();
  }

  String get nombreVisible => nombre.trim().isEmpty ? email : nombre.trim();

  factory Usuario.fromMap(
    String uid,
    Map<String, dynamic> map, {
    String emailFallback = '',
  }) {
    final rol = _texto(map['rol'], fallback: RolUsuario.personal);
    final permisosRaw = map['permisos'];
    final permisos = permisosRaw is Map
        ? PermisosUsuario.fromMap(_mapa(permisosRaw))
        : (rol == RolUsuario.administrador
              ? PermisosUsuario.administrador
              : PermisosUsuario.personal);

    return Usuario(
      uid: uid,
      email: _texto(map['email'], fallback: emailFallback).toLowerCase(),
      nombre: _texto(map['nombre'], fallback: emailFallback),
      telefono: _texto(map['telefono']),
      rol: rol,
      activo: map['activo'] is bool ? map['activo'] as bool : true,
      debeCambiarPassword: map['debeCambiarPassword'] is bool
          ? map['debeCambiarPassword'] as bool
          : false,
      permisos: rol == RolUsuario.administrador
          ? PermisosUsuario.administrador
          : permisos,
      creadoEn: _fecha(map['creadoEn']),
      actualizadoEn: _fecha(map['actualizadoEn']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'nombre': nombre.trim(),
      'telefono': telefono.trim(),
      'rol': rol,
      'activo': activo,
      'debeCambiarPassword': debeCambiarPassword,
      'permisos':
          (rol == RolUsuario.administrador
                  ? PermisosUsuario.administrador
                  : permisos)
              .toMap(),
    };
  }

  Usuario copyWith({
    String? email,
    String? nombre,
    String? telefono,
    String? rol,
    bool? activo,
    bool? debeCambiarPassword,
    PermisosUsuario? permisos,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return Usuario(
      uid: uid,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      debeCambiarPassword: debeCambiarPassword ?? this.debeCambiarPassword,
      permisos: permisos ?? this.permisos,
      creadoEn: creadoEn ?? this.creadoEn,
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

  static Map<String, dynamic> _mapa(Map value) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static DateTime? _fecha(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
