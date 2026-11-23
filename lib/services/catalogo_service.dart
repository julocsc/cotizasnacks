import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/categoria_producto.dart';
import '../models/producto.dart';

/// Acceso a las colecciones `categorias_productos` y `productos`.
class CatalogoService {
  CatalogoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _categorias =>
      _firestore.collection('categorias_productos');

  CollectionReference<Map<String, dynamic>> get _productos =>
      _firestore.collection('productos');

  Stream<List<CategoriaProducto>> escucharCategorias() {
    return _categorias
        .orderBy('nombre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CategoriaProducto.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<DocumentReference<Map<String, dynamic>>> agregarCategoria(
    String nombre,
  ) {
    return _categorias.add(<String, dynamic>{
      'nombre': nombre.trim(),
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarCategoria(String id) => _categorias.doc(id).delete();

  Stream<List<Producto>> escucharProductos() {
    return _productos
        .orderBy('nombre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Producto.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<DocumentReference<Map<String, dynamic>>> agregarProducto(
    Producto producto,
  ) {
    return _productos.add(<String, dynamic>{
      ...producto.toMap(),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarProducto(Producto producto) {
    final id = producto.id;
    if (id == null) {
      throw ArgumentError('El producto debe tener un id para actualizarse.');
    }
    return _productos.doc(id).update(<String, dynamic>{
      ...producto.toMap(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarProducto(String id) => _productos.doc(id).delete();
}
