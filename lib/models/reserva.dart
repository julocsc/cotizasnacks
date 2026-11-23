import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../utils/num_utils.dart';

/// Estados posibles de una reserva.
abstract final class EstadoReserva {
  static const String pendiente = 'pendiente';
  static const String confirmada = 'confirmada';
  static const String completada = 'completada';
  static const String cancelada = 'cancelada';

  static const List<String> todos = <String>[
    pendiente,
    confirmada,
    completada,
    cancelada,
  ];
}

/// Categorías de gasto que se pueden asignar a cada ítem de una reserva.
abstract final class TipoCostoReserva {
  static const String insumo = 'insumo';
  static const String manoObra = 'manoObra';
  static const String otros = 'otros';

  static const List<String> todos = <String>[insumo, manoObra, otros];

  static String etiqueta(String tipo) {
    switch (tipo) {
      case manoObra:
        return 'Mano de obra';
      case otros:
        return 'Otros';
      default:
        return 'Insumos';
    }
  }
}

/// Producto o servicio incluido dentro de una reserva.
class ReservaItem {
  const ReservaItem({
    required this.descripcion,
    this.productoId = '',
    this.cantidad = 1,
    this.precioUnitario = 0,
    this.costoUnitario = 0,
    this.tipoCosto = TipoCostoReserva.insumo,
  });

  final String descripcion;
  final String productoId;
  final double cantidad;

  /// Precio de venta unitario cobrado al cliente.
  final double precioUnitario;

  /// Costo unitario estimado (insumos, mano de obra u otros).
  final double costoUnitario;

  /// Categoría del gasto asociado a este ítem.
  final String tipoCosto;

  /// Importe vendido por esta línea.
  double get total => roundMoney(cantidad * precioUnitario);

  /// Costo estimado de esta línea.
  double get costoTotal => roundMoney(cantidad * costoUnitario);

  factory ReservaItem.fromMap(Map<String, dynamic> map) {
    final tipo = Reserva._texto(map['tipoCosto']);
    return ReservaItem(
      descripcion: Reserva._texto(
        map['descripcion'],
        fallback: 'Producto o servicio',
      ),
      productoId: Reserva._texto(map['productoId']),
      cantidad: asDouble(map['cantidad'], fallback: 1),
      precioUnitario: asDouble(
        map['precioUnitario'] ?? map['precio'] ?? map['valorUnitario'],
      ),
      costoUnitario: asDouble(
        map['costoUnitario'] ?? map['costo'] ?? map['costoEstimado'],
      ),
      tipoCosto: TipoCostoReserva.todos.contains(tipo)
          ? tipo
          : TipoCostoReserva.insumo,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'descripcion': descripcion,
      'productoId': productoId,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'costoUnitario': costoUnitario,
      'tipoCosto': tipoCosto,
      'total': total,
      'costoTotal': costoTotal,
    };
  }

  ReservaItem copyWith({
    String? descripcion,
    String? productoId,
    double? cantidad,
    double? precioUnitario,
    double? costoUnitario,
    String? tipoCosto,
  }) {
    return ReservaItem(
      descripcion: descripcion ?? this.descripcion,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      tipoCosto: tipoCosto ?? this.tipoCosto,
    );
  }
}

/// Reserva de uno o varios productos para un cliente en una fecha determinada.
class Reserva {
  const Reserva({
    this.id,
    required this.clienteId,
    required this.clienteNombre,
    this.productoId = '',
    this.productoNombre = '',
    required this.fecha,
    this.cantidad = 1,
    this.precioUnitario = 0,
    this.costoUnitario = 0,
    this.tipoCosto = TipoCostoReserva.insumo,
    this.estado = EstadoReserva.pendiente,
    this.notas = '',
    this.cotizacionId = '',
    this.cotizacionNumero = '',
    this.items = const <ReservaItem>[],
    this.lugar = '',
    this.tipoEvento = '',
    this.numeroInvitados = 0,
    this.costoMovilidad = 0,
    this.abonoInicial = 0,
    this.moneda = AppConfig.moneda,
    this.creadoPorUid = '',
    this.creadoPorNombre = '',
    this.creadoPorEmail = '',
    this.creadoPorTelefono = '',
    this.creadoEn,
  });

  final String? id;
  final String clienteId;
  final String clienteNombre;
  final String productoId;
  final String productoNombre;

  /// Fecha y hora de inicio del evento reservado.
  final DateTime fecha;
  final double cantidad;

  /// Precio unitario de la reserva manual (cuando no tiene ítems detallados).
  final double precioUnitario;

  /// Costo unitario estimado de la reserva manual.
  final double costoUnitario;

  /// Categoría del gasto de la reserva manual.
  final String tipoCosto;

  final String estado;
  final String notas;

  /// Cotización del historial que originó la reserva, si aplica.
  final String cotizacionId;
  final String cotizacionNumero;

  /// Ítems reservados. Las reservas manuales pueden dejarlo vacío y usar los
  /// campos [productoId], [productoNombre] y [cantidad].
  final List<ReservaItem> items;

  /// Lugar donde se realizará el evento.
  final String lugar;

  /// Tipo de evento (boda, cumpleaños, corporativo, etc.).
  final String tipoEvento;

  /// Número estimado de invitados.
  final int numeroInvitados;

  /// Costo de movilidad o traslado cobrado al cliente.
  final double costoMovilidad;

  /// Abono inicial recibido al confirmar la reserva.
  final double abonoInicial;

  /// Código ISO de la moneda de los importes de la reserva.
  final String moneda;

  /// Datos del usuario que creó la cotización de origen. Se usan para
  /// notificar por WhatsApp y agendar el evento en su calendario.
  final String creadoPorUid;
  final String creadoPorNombre;
  final String creadoPorEmail;
  final String creadoPorTelefono;

  final DateTime? creadoEn;

  /// Hora de inicio del evento en formato `HH:mm` (hora local).
  String get horaInicio {
    final local = fecha.toLocal();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  /// Nombre visible del creador de la cotización.
  String get nombreCreador {
    if (creadoPorNombre.trim().isNotEmpty) return creadoPorNombre.trim();
    if (creadoPorEmail.trim().isNotEmpty) return creadoPorEmail.trim();
    return '';
  }

  /// Cantidad de líneas distintas que contiene la reserva.
  int get cantidadItems {
    if (items.isNotEmpty) return items.length;
    return productoNombre.trim().isEmpty ? 0 : 1;
  }

  /// Suma de unidades reservadas.
  double get cantidadTotal {
    if (items.isEmpty) return cantidad;
    return items.fold<double>(0, (total, item) => total + item.cantidad);
  }

  /// Subtotal vendido por los ítems de la reserva (sin movilidad).
  double get subtotal {
    if (items.isEmpty) return roundMoney(cantidad * precioUnitario);
    return roundMoney(
      items.fold<double>(0, (total, item) => total + item.total),
    );
  }

  /// Total a cobrar: ítems + costo de movilidad.
  double get total => roundMoney(subtotal + costoMovilidad);

  /// Saldo que queda por cobrar después del abono inicial.
  double get saldoPendiente {
    final saldo = roundMoney(total - abonoInicial);
    return saldo < 0 ? 0 : saldo;
  }

  /// Indica si la reserva ya puede generar una boleta.
  bool get estaCompletada => estado == EstadoReserva.completada;

  /// Gastos de insumos estimados para los ítems de la reserva.
  double get costoInsumos => _costoPorTipo(TipoCostoReserva.insumo);

  /// Gastos de mano de obra estimados para los ítems de la reserva.
  double get costoManoObra => _costoPorTipo(TipoCostoReserva.manoObra);

  /// Otros gastos estimados para los ítems de la reserva.
  double get costoOtros => _costoPorTipo(TipoCostoReserva.otros);

  /// Costo total estimado de la reserva (insumos + mano de obra + otros).
  double get costoTotal {
    return roundMoney(costoInsumos + costoManoObra + costoOtros);
  }

  /// Utilidad estimada de la reserva.
  double get utilidad => roundMoney(total - costoTotal);

  double _costoPorTipo(String tipo) {
    if (items.isEmpty) {
      if (tipoCosto != tipo) return 0;
      return roundMoney(cantidad * costoUnitario);
    }
    return roundMoney(
      items
          .where((item) => item.tipoCosto == tipo)
          .fold<double>(0, (total, item) => total + item.costoTotal),
    );
  }

  /// Texto breve de los productos reservados.
  String get resumenProductos {
    if (items.isEmpty) return productoNombre;
    if (items.length == 1) return items.first.descripcion;
    return '${items.length} ítems reservados';
  }

  factory Reserva.fromMap(String id, Map<String, dynamic> map) {
    final items = <ReservaItem>[];
    final itemsRaw = map['items'];
    if (itemsRaw is Iterable) {
      for (final rawItem in itemsRaw) {
        if (rawItem is Map) {
          items.add(ReservaItem.fromMap(_mapa(rawItem)));
        }
      }
    }

    return Reserva(
      id: id,
      clienteId: _texto(map['clienteId']),
      clienteNombre: _texto(map['clienteNombre'], fallback: 'Cliente'),
      productoId: _texto(map['productoId']),
      productoNombre: _texto(map['productoNombre']),
      fecha: _fecha(map['fecha'] ?? map['fechaTimestamp']),
      cantidad: asDouble(map['cantidad'], fallback: 1),
      precioUnitario: asDouble(
        map['precioUnitario'] ?? map['precio'] ?? map['valorUnitario'],
      ),
      costoUnitario: asDouble(
        map['costoUnitario'] ?? map['costo'] ?? map['costoEstimado'],
      ),
      tipoCosto: TipoCostoReserva.todos.contains(_texto(map['tipoCosto']))
          ? _texto(map['tipoCosto'])
          : TipoCostoReserva.insumo,
      estado: _texto(map['estado'], fallback: EstadoReserva.pendiente),
      notas: _texto(map['notas']),
      cotizacionId: _texto(map['cotizacionId']),
      cotizacionNumero: _texto(map['cotizacionNumero']),
      items: List<ReservaItem>.unmodifiable(items),
      lugar: _texto(map['lugar']),
      tipoEvento: _texto(map['tipoEvento']),
      numeroInvitados: asInt(map['numeroInvitados']),
      costoMovilidad: asDouble(map['costoMovilidad']),
      abonoInicial: asDouble(map['abonoInicial']),
      moneda: _texto(map['moneda'], fallback: AppConfig.moneda),
      creadoPorUid: _texto(map['creadoPorUid']),
      creadoPorNombre: _texto(map['creadoPorNombre']),
      creadoPorEmail: _texto(map['creadoPorEmail']),
      creadoPorTelefono: _texto(map['creadoPorTelefono']),
      creadoEn: _fecha(map['creadoEn']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'productoId': productoId,
      'productoNombre': productoNombre,
      'fecha': fecha.toUtc().toIso8601String(),
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'costoUnitario': costoUnitario,
      'tipoCosto': tipoCosto,
      'estado': estado,
      'notas': notas.trim(),
      'cotizacionId': cotizacionId,
      'cotizacionNumero': cotizacionNumero,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'lugar': lugar.trim(),
      'tipoEvento': tipoEvento.trim(),
      'numeroInvitados': numeroInvitados,
      'costoMovilidad': costoMovilidad,
      'abonoInicial': abonoInicial,
      'moneda': moneda,
      'creadoPorUid': creadoPorUid,
      'creadoPorNombre': creadoPorNombre.trim(),
      'creadoPorEmail': creadoPorEmail.trim().toLowerCase(),
      'creadoPorTelefono': creadoPorTelefono.trim(),
    };
  }

  Reserva copyWith({
    String? id,
    String? clienteId,
    String? clienteNombre,
    String? productoId,
    String? productoNombre,
    DateTime? fecha,
    double? cantidad,
    double? precioUnitario,
    double? costoUnitario,
    String? tipoCosto,
    String? estado,
    String? notas,
    String? cotizacionId,
    String? cotizacionNumero,
    List<ReservaItem>? items,
    String? lugar,
    String? tipoEvento,
    int? numeroInvitados,
    double? costoMovilidad,
    double? abonoInicial,
    String? moneda,
    String? creadoPorUid,
    String? creadoPorNombre,
    String? creadoPorEmail,
    String? creadoPorTelefono,
    DateTime? creadoEn,
  }) {
    return Reserva(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      fecha: fecha ?? this.fecha,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      tipoCosto: tipoCosto ?? this.tipoCosto,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      cotizacionId: cotizacionId ?? this.cotizacionId,
      cotizacionNumero: cotizacionNumero ?? this.cotizacionNumero,
      items: items ?? this.items,
      lugar: lugar ?? this.lugar,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      numeroInvitados: numeroInvitados ?? this.numeroInvitados,
      costoMovilidad: costoMovilidad ?? this.costoMovilidad,
      abonoInicial: abonoInicial ?? this.abonoInicial,
      moneda: moneda ?? this.moneda,
      creadoPorUid: creadoPorUid ?? this.creadoPorUid,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
      creadoPorEmail: creadoPorEmail ?? this.creadoPorEmail,
      creadoPorTelefono: creadoPorTelefono ?? this.creadoPorTelefono,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  static Map<String, dynamic> _mapa(Map value) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  static String _texto(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final texto = value.trim();
      if (texto.isNotEmpty) return texto;
    }
    return fallback;
  }

  static DateTime _fecha(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
