import 'package:cloud_firestore/cloud_firestore.dart';

/// Cliente registrado desde el panel de administración.
class Cliente {
  const Cliente({
    this.id,
    required this.nombre,
    this.telefono = '',
    this.email = '',
    this.documento = '',
    this.notas = '',
    this.creadoEn,
  });

  final String? id;
  final String nombre;
  final String telefono;
  final String email;

  /// DNI, RUC, pasaporte u otro documento de identidad.
  final String documento;

  final String notas;
  final DateTime? creadoEn;

  /// Clave de contacto usada para deduplicar clientes cotizados.
  ///
  /// Se prioriza el teléfono, luego el email y por último el nombre.
  String get claveContacto {
    final telefonoNormalizado = _telefonoComparable(telefono);
    if (telefonoNormalizado.isNotEmpty) return 'tel:$telefonoNormalizado';

    final emailNormalizado = email.trim().toLowerCase();
    if (emailNormalizado.isNotEmpty) return 'mail:$emailNormalizado';

    return 'nombre:${nombre.trim().toLowerCase()}';
  }

  /// Indica si dos clientes parecen ser la misma persona o empresa.
  ///
  /// El teléfono y el email son datos fuertes; el nombre solo se usa cuando
  /// ambos registros carecen de datos de contacto.
  bool coincideCon(Cliente otro) {
    final telefonoA = _telefonoComparable(telefono);
    final telefonoB = _telefonoComparable(otro.telefono);
    if (telefonoA.isNotEmpty && telefonoB.isNotEmpty) {
      if (telefonoA == telefonoB) return true;
      return false;
    }

    final emailA = email.trim().toLowerCase();
    final emailB = otro.email.trim().toLowerCase();
    if (emailA.isNotEmpty && emailB.isNotEmpty) {
      if (emailA == emailB) return true;
      return false;
    }

    final nombreA = nombre.trim().toLowerCase();
    final nombreB = otro.nombre.trim().toLowerCase();
    return nombreA.isNotEmpty && nombreA == nombreB;
  }

  factory Cliente.fromMap(String id, Map<String, dynamic> map) {
    return Cliente(
      id: id,
      nombre: _texto(map['nombre'], fallback: 'Cliente sin nombre'),
      telefono: _texto(map['telefono']),
      email: _texto(map['email']),
      documento: _texto(map['documento']),
      notas: _texto(map['notas']),
      creadoEn: _fecha(map['creadoEn']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nombre': nombre.trim(),
      'telefono': telefono.trim(),
      'email': email.trim(),
      'documento': documento.trim(),
      'notas': notas.trim(),
    };
  }

  /// Normaliza un teléfono peruano para compararlo sin prefijo ni separadores.
  static String _telefonoComparable(String value) {
    final digitos = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length > 9 && digitos.startsWith('51')) {
      return digitos.substring(2);
    }
    return digitos;
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
