import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cliente.dart';
import '../models/reserva.dart';

/// Acceso a las colecciones `clientes` y `reservas`.
class ClientesReservasService {
  ClientesReservasService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clientes =>
      _firestore.collection('clientes');

  CollectionReference<Map<String, dynamic>> get _reservas =>
      _firestore.collection('reservas');

  Stream<List<Cliente>> escucharClientes() {
    return _clientes
        .orderBy('nombre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Cliente.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<DocumentReference<Map<String, dynamic>>> agregarCliente(
    Cliente cliente,
  ) {
    return _clientes.add(<String, dynamic>{
      ...cliente.toMap(),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarCliente(Cliente cliente) {
    final id = cliente.id;
    if (id == null) {
      throw ArgumentError('El cliente debe tener un id para actualizarse.');
    }
    return _clientes.doc(id).update(<String, dynamic>{
      ...cliente.toMap(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarCliente(String id) => _clientes.doc(id).delete();

  /// Devuelve el ID de un cliente existente que coincida con [cliente].
  ///
  /// Si no existe, lo registra en la colección `clientes` y devuelve el ID del
  /// documento nuevo. Se usa al convertir cotizaciones en reservas para que el
  /// cliente quede disponible en el panel de administración.
  Future<String> asegurarCliente(
    Cliente cliente, {
    List<Cliente>? existentes,
  }) async {
    final registrados = existentes ?? await escucharClientes().first;
    for (final registrado in registrados) {
      if (registrado.id != null && registrado.coincideCon(cliente)) {
        return registrado.id!;
      }
    }

    final referencia = await agregarCliente(cliente);
    return referencia.id;
  }

  /// Registra en `clientes` los clientes cotizados que aún no existen.
  ///
  /// Devuelve cuántos clientes se importaron.
  Future<int> importarClientes(Iterable<Cliente> candidatos) async {
    final registrados = (await escucharClientes().first).toList();
    var importados = 0;

    for (final candidato in candidatos) {
      final existe = registrados.any(
        (registrado) => registrado.coincideCon(candidato),
      );
      if (existe) continue;

      final referencia = await agregarCliente(candidato);
      registrados.add(
        Cliente(
          id: referencia.id,
          nombre: candidato.nombre,
          telefono: candidato.telefono,
          email: candidato.email,
        ),
      );
      importados++;
    }

    return importados;
  }

  Stream<List<Reserva>> escucharReservas() {
    return _reservas
        .orderBy('fechaTimestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Reserva.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<DocumentReference<Map<String, dynamic>>> agregarReserva(
    Reserva reserva,
  ) {
    return _reservas.add(<String, dynamic>{
      ...reserva.toMap(),
      'fechaTimestamp': Timestamp.fromDate(reserva.fecha.toUtc()),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarReserva(Reserva reserva) {
    final id = reserva.id;
    if (id == null) {
      throw ArgumentError('La reserva debe tener un id para actualizarse.');
    }
    return _reservas.doc(id).update(<String, dynamic>{
      ...reserva.toMap(),
      'fechaTimestamp': Timestamp.fromDate(reserva.fecha.toUtc()),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarEstadoReserva(String id, String estado) {
    return _reservas.doc(id).update(<String, dynamic>{
      'estado': estado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarReserva(String id) => _reservas.doc(id).delete();
}
