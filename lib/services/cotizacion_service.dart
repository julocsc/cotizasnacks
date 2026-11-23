import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cotizacion.dart';

/// Acceso a la colección `cotizaciones` de Cloud Firestore.
class CotizacionService {
  CotizacionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _firestore.collection('cotizaciones');

  /// Guarda una cotización y devuelve la referencia del documento creado.
  ///
  /// Además del mapa analítico del modelo se agregan dos campos técnicos:
  /// - `fechaTimestamp`: fecha tipada para consultas y BI.
  /// - `creadoEn`: hora del servidor, inmutable y confiable para auditoría.
  Future<DocumentReference<Map<String, dynamic>>> guardar(
    Cotizacion cotizacion,
  ) {
    final data = <String, dynamic>{
      ...cotizacion.toMap(),
      'fechaTimestamp': Timestamp.fromDate(cotizacion.fecha.toUtc()),
      'creadoEn': FieldValue.serverTimestamp(),
    };

    return _coleccion.add(data);
  }

  /// Escucha el historial en tiempo real, de la cotización más reciente a la
  /// más antigua.
  ///
  /// El `StreamBuilder` de la pantalla de historial consume este stream y se
  /// actualiza automáticamente cuando otro dispositivo agrega o elimina
  /// documentos.
  Stream<List<Cotizacion>> escucharCotizaciones({int limite = 200}) {
    return _coleccion
        .orderBy('fechaTimestamp', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Cotizacion.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Recupera una cotización puntual (útil para enlaces directos o detalles).
  Future<Cotizacion?> obtener(String id) async {
    final doc = await _coleccion.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Cotizacion.fromMap(doc.id, data);
  }

  /// Cambia el estado de una cotización, por ejemplo a `reservada`.
  Future<void> actualizarEstado(String id, String estado) {
    return _coleccion.doc(id).update(<String, dynamic>{
      'estado': estado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una cotización. El historial se actualiza por el stream.
  Future<void> eliminar(String id) => _coleccion.doc(id).delete();
}
