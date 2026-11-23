import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/num_utils.dart';

/// Producto del catálogo administrado desde el panel de administración.
class Producto {
  const Producto({
    this.id,
    required this.nombre,
    required this.categoriaId,
    required this.categoriaNombre,
    this.descripcion = '',
    required this.precioCompra,
    required this.precioVenta,
    this.imagenBase64 = '',
    this.activo = true,
    this.creadoEn,
  });

  final String? id;
  final String nombre;
  final String categoriaId;

  /// Nombre de la categoría denormalizado para mostrarlo sin otra consulta.
  final String categoriaNombre;

  final String descripcion;

  /// Costo de compra o insumo.
  final double precioCompra;

  /// Precio unitario de venta al cliente.
  final double precioVenta;

  /// Imagen codificada en base64 (sin prefijo `data:`).
  final String imagenBase64;

  final bool activo;
  final DateTime? creadoEn;

  double get margen => roundMoney(precioVenta - precioCompra);

  double get margenPorcentaje {
    if (precioCompra <= 0) return 0;
    return (precioVenta - precioCompra) / precioCompra * 100;
  }

  factory Producto.fromMap(String id, Map<String, dynamic> map) {
    return Producto(
      id: id,
      nombre: _texto(map['nombre']),
      categoriaId: _texto(map['categoriaId']),
      categoriaNombre: _texto(
        map['categoriaNombre'],
        fallback: 'Sin categoría',
      ),
      descripcion: _texto(map['descripcion']),
      precioCompra: asDouble(map['precioCompra']),
      precioVenta: asDouble(map['precioVenta']),
      imagenBase64: _texto(map['imagenBase64']),
      activo: map['activo'] is bool ? map['activo'] as bool : true,
      creadoEn: _fecha(map['creadoEn']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nombre': nombre.trim(),
      'categoriaId': categoriaId,
      'categoriaNombre': categoriaNombre,
      'descripcion': descripcion.trim(),
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'imagenBase64': imagenBase64,
      'activo': activo,
    };
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
