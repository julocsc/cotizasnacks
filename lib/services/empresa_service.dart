import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/empresa_config.dart';

/// Acceso a la configuración de la empresa emisora.
///
/// El documento se guarda en `configuracion/empresa`. Solo el administrador
/// puede modificarlo; el resto del personal lo lee para generar el PDF.
class EmpresaService {
  EmpresaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _documento =>
      _firestore.collection('configuracion').doc('empresa');

  Stream<EmpresaConfig> escucharConfiguracion() {
    return _documento.snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return const EmpresaConfig();
      return EmpresaConfig.fromMap(data);
    });
  }

  Future<EmpresaConfig> obtenerConfiguracion() async {
    final doc = await _documento.get();
    final data = doc.data();
    if (!doc.exists || data == null) return const EmpresaConfig();
    return EmpresaConfig.fromMap(data);
  }

  Future<void> guardarConfiguracion(EmpresaConfig config) {
    return _documento.set(<String, dynamic>{
      ...config.toMap(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
