import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../utils/num_utils.dart';
import 'item_cotizacion.dart';

/// Documento analítico de una cotización.
///
/// El modelo mantiene la fecha en UTC. En Firestore se guarda como texto ISO
/// 8601 (campo `fecha`) y, además, como `Timestamp` (campo `fechaTimestamp`)
/// para consultas y exportaciones a BigQuery.
class Cotizacion {
  static const String estadoEmitida = 'emitida';
  static const String estadoReservada = 'reservada';

  const Cotizacion({
    this.id,
    required this.numeroCotizacion,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteEmail,
    required this.fecha,
    required this.items,
    required this.subtotal,
    required this.aplicarImpuesto,
    required this.porcentajeImpuesto,
    required this.impuesto,
    required this.total,
    required this.moneda,
    required this.notas,
    required this.estado,
    required this.versionEsquema,
    required this.origen,
    this.lugar = '',
    this.tipoEvento = '',
    this.numeroInvitados = 0,
    this.costoMovilidad = 0,
    this.creadoPorUid = '',
    this.creadoPorNombre = '',
    this.creadoPorEmail = '',
    this.creadoPorTelefono = '',
  });

  /// ID del documento en Firestore. Es `null` hasta que se persiste.
  final String? id;

  final String numeroCotizacion;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteEmail;

  /// Fecha de emisión en UTC.
  final DateTime fecha;

  final List<ItemCotizacion> items;
  final double subtotal;
  final bool aplicarImpuesto;
  final double porcentajeImpuesto;
  final double impuesto;
  final double total;
  final String moneda;
  final String notas;
  final String estado;
  final int versionEsquema;
  final String origen;

  /// Lugar donde se realizará el evento cotizado.
  final String lugar;

  /// Tipo de evento (boda, cumpleaños, corporativo, etc.).
  final String tipoEvento;

  /// Número estimado de invitados.
  final int numeroInvitados;

  /// Costo de movilidad o traslado incluido en la cotización.
  final double costoMovilidad;

  /// Datos del usuario que creó la cotización. Permiten notificarle cuando la
  /// cotización se convierte en reserva.
  final String creadoPorUid;
  final String creadoPorNombre;
  final String creadoPorEmail;
  final String creadoPorTelefono;

  int get cantidadItems => items.length;

  /// Crea una cotización nueva y calcula sus importes de forma consistente.
  factory Cotizacion.crear({
    required String numeroCotizacion,
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteEmail,
    required List<ItemCotizacion> items,
    required bool aplicarImpuesto,
    required double porcentajeImpuesto,
    DateTime? fecha,
    String moneda = AppConfig.moneda,
    String notas = '',
    String lugar = '',
    String tipoEvento = '',
    int numeroInvitados = 0,
    double costoMovilidad = 0,
    String creadoPorUid = '',
    String creadoPorNombre = '',
    String creadoPorEmail = '',
    String creadoPorTelefono = '',
  }) {
    final subtotal = roundMoney(
      items.fold<double>(0, (acumulado, item) => acumulado + item.total),
    );
    final tasa = aplicarImpuesto
        ? porcentajeImpuesto.clamp(0, 100).toDouble()
        : 0.0;
    final impuesto = roundMoney(subtotal * tasa / 100);
    final movilidad = roundMoney(costoMovilidad);

    return Cotizacion(
      numeroCotizacion: numeroCotizacion,
      clienteNombre: clienteNombre.trim(),
      clienteTelefono: clienteTelefono.trim(),
      clienteEmail: clienteEmail.trim(),
      fecha: (fecha ?? DateTime.now()).toUtc(),
      items: List<ItemCotizacion>.unmodifiable(items),
      subtotal: subtotal,
      aplicarImpuesto: aplicarImpuesto,
      porcentajeImpuesto: tasa,
      impuesto: impuesto,
      total: roundMoney(subtotal + impuesto + movilidad),
      moneda: moneda,
      notas: notas.trim(),
      estado: estadoEmitida,
      versionEsquema: AppConfig.versionEsquema,
      origen: 'flutter_app',
      lugar: lugar.trim(),
      tipoEvento: tipoEvento.trim(),
      numeroInvitados: numeroInvitados,
      costoMovilidad: movilidad,
      creadoPorUid: creadoPorUid,
      creadoPorNombre: creadoPorNombre.trim(),
      creadoPorEmail: creadoPorEmail.trim().toLowerCase(),
      creadoPorTelefono: creadoPorTelefono.trim(),
    );
  }

  /// Reconstruye una cotización guardada en Firestore.
  ///
  /// Es deliberadamente tolerante a documentos incompletos o creados con
  /// versiones anteriores del esquema.
  factory Cotizacion.fromMap(String id, Map<String, dynamic> map) {
    final cliente = _asMap(map['cliente']);
    final items = <ItemCotizacion>[];

    final itemsRaw = map['items'];
    if (itemsRaw is Iterable) {
      for (final rawItem in itemsRaw) {
        if (rawItem is Map) {
          items.add(ItemCotizacion.fromMap(_asMap(rawItem)));
        }
      }
    }

    final fecha = _parseFecha(
      map['fecha'] ?? map['fechaTimestamp'] ?? map['creadoEn'],
    );
    final subtotalGuardado = map['subtotal'];
    final subtotal = subtotalGuardado == null
        ? roundMoney(
            items.fold<double>(0, (acumulado, item) => acumulado + item.total),
          )
        : roundMoney(asDouble(subtotalGuardado));

    final aplicarImpuesto = _asBool(
      map['aplicarImpuesto'],
      fallback:
          asDouble(map['impuesto']) > 0 ||
          asDouble(map['porcentajeImpuesto']) > 0,
    );

    final porcentajeImpuesto = aplicarImpuesto
        ? asDouble(map['porcentajeImpuesto'])
        : 0.0;
    final impuestoGuardado = map['impuesto'];
    final impuesto = impuestoGuardado == null
        ? roundMoney(subtotal * porcentajeImpuesto / 100)
        : roundMoney(asDouble(impuestoGuardado));

    final costoMovilidad = roundMoney(asDouble(map['costoMovilidad']));

    // El total siempre se recalcula para garantizar que la movilidad quede
    // incluida, incluso en documentos guardados con versiones anteriores.
    final total = roundMoney(subtotal + impuesto + costoMovilidad);

    return Cotizacion(
      id: id,
      numeroCotizacion: _asText(map['numeroCotizacion'], fallback: id),
      clienteNombre: _asText(
        cliente['nombre'],
        fallback: _asText(map['clienteNombre']),
      ),
      clienteTelefono: _asText(
        cliente['telefono'],
        fallback: _asText(map['clienteTelefono']),
      ),
      clienteEmail: _asText(
        cliente['email'],
        fallback: _asText(map['clienteEmail']),
      ),
      fecha: fecha,
      items: List<ItemCotizacion>.unmodifiable(items),
      subtotal: subtotal,
      aplicarImpuesto: aplicarImpuesto,
      porcentajeImpuesto: porcentajeImpuesto,
      impuesto: impuesto,
      total: total,
      moneda: _asText(map['moneda'], fallback: AppConfig.moneda),
      notas: _asText(map['notas']),
      estado: _asText(map['estado'], fallback: estadoEmitida),
      versionEsquema: asInt(
        map['versionEsquema'],
        fallback: AppConfig.versionEsquema,
      ),
      origen: _asText(map['origen'], fallback: 'flutter_app'),
      lugar: _asText(map['lugar']),
      tipoEvento: _asText(map['tipoEvento']),
      numeroInvitados: asInt(map['numeroInvitados']),
      costoMovilidad: costoMovilidad,
      creadoPorUid: _asText(map['creadoPorUid']),
      creadoPorNombre: _asText(map['creadoPorNombre']),
      creadoPorEmail: _asText(map['creadoPorEmail']),
      creadoPorTelefono: _asText(map['creadoPorTelefono']),
    );
  }

  /// Convierte el modelo a un mapa plano apto para Firestore.
  ///
  /// Los importes son números (no texto) y los ítems son una lista de mapas,
  /// lo que permite consultas, agregaciones y exportación directa a BI.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'numeroCotizacion': numeroCotizacion,
      'cliente': <String, dynamic>{
        'nombre': clienteNombre,
        'telefono': clienteTelefono,
        'email': clienteEmail,
      },
      'fecha': fecha.toUtc().toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'subtotal': subtotal,
      'aplicarImpuesto': aplicarImpuesto,
      'porcentajeImpuesto': porcentajeImpuesto,
      'impuesto': impuesto,
      'total': total,
      'moneda': moneda,
      'notas': notas,
      'estado': estado,
      'versionEsquema': versionEsquema,
      'origen': origen,
      'lugar': lugar,
      'tipoEvento': tipoEvento,
      'numeroInvitados': numeroInvitados,
      'costoMovilidad': costoMovilidad,
      'creadoPorUid': creadoPorUid,
      'creadoPorNombre': creadoPorNombre,
      'creadoPorEmail': creadoPorEmail,
      'creadoPorTelefono': creadoPorTelefono,
    };
  }

  static DateTime _parseFecha(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return <String, dynamic>{};
  }

  static String _asText(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    return value is bool ? value : fallback;
  }
}
