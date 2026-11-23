/// Categoría usada para organizar el catálogo de productos.
class CategoriaProducto {
  const CategoriaProducto({this.id, required this.nombre});

  final String? id;
  final String nombre;

  factory CategoriaProducto.fromMap(String id, Map<String, dynamic> map) {
    final nombre = map['nombre'];
    return CategoriaProducto(
      id: id,
      nombre: nombre is String ? nombre.trim() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'nombre': nombre.trim()};
  }
}
