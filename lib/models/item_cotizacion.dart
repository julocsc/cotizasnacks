import '../utils/num_utils.dart';

/// Una línea (producto o servicio) de una cotización.
class ItemCotizacion {
  const ItemCotizacion({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    this.productoId,
  });

  final String descripcion;
  final double cantidad;
  final double precioUnitario;

  /// ID del producto del catálogo del admin, cuando el ítem se tomó de ahí.
  ///
  /// Es `null` para los productos o servicios capturados manualmente.
  final String? productoId;

  /// El total de la línea se calcula siempre a partir de cantidad y precio.
  /// Así se evita guardar importes inconsistentes.
  double get total => roundMoney(cantidad * precioUnitario);

  /// Construye un ítem desde un documento de Firestore.
  ///
  /// Se aceptan algunas variantes de nombres de campo para facilitar la
  /// migración de datos creados con versiones anteriores.
  factory ItemCotizacion.fromMap(Map<String, dynamic> map) {
    final descripcion = map['descripcion'];
    final productoId = map['productoId'];
    return ItemCotizacion(
      descripcion: descripcion is String ? descripcion.trim() : '',
      cantidad: asDouble(map['cantidad']),
      precioUnitario: asDouble(
        map['precioUnitario'] ?? map['precio'] ?? map['valorUnitario'],
      ),
      productoId: productoId is String && productoId.trim().isNotEmpty
          ? productoId.trim()
          : null,
    );
  }

  /// Estructura plana y estable pensada para Firestore/BigQuery.
  ///
  /// `total` se incluye de forma redundante para que las herramientas de BI no
  /// tengan que recalcular la multiplicación en cada consulta.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'total': total,
      'productoId': productoId,
    };
  }
}
