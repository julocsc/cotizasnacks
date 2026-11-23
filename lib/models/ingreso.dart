import '../utils/num_utils.dart';
import 'cotizacion.dart';
import 'producto.dart';
import 'reserva.dart';

/// Forma en que se agrupan las ventas de la pestaña Ingresos.
enum AgrupacionFecha { dia, mes, anio }

/// Resumen de ventas, costos y utilidad para un período o un evento.
class ResumenIngresos {
  const ResumenIngresos({
    required this.clave,
    required this.etiqueta,
    required this.ventas,
    required this.costos,
    this.fecha,
    this.cantidadVentas = 0,
    this.itemsSinCosto = 0,
  });

  final String clave;
  final String etiqueta;
  final DateTime? fecha;
  final double ventas;
  final double costos;
  final int cantidadVentas;

  /// Cantidad de líneas que no tienen un producto del catálogo asociado y,
  /// por lo tanto, no aportan costo calculado.
  final int itemsSinCosto;

  double get utilidad => roundMoney(ventas - costos);

  double get margen {
    if (ventas <= 0) return 0;
    return utilidad / ventas * 100;
  }
}

/// Evento (reserva) con la cotización que lo originó y su utilidad.
class IngresoEvento {
  const IngresoEvento({
    required this.reserva,
    required this.cotizacion,
    required this.ventas,
    required this.costos,
    required this.itemsSinCosto,
  });

  final Reserva reserva;
  final Cotizacion? cotizacion;
  final double ventas;
  final double costos;
  final int itemsSinCosto;

  double get utilidad => roundMoney(ventas - costos);

  double get margen {
    if (ventas <= 0) return 0;
    return utilidad / ventas * 100;
  }

  bool get tieneCotizacion => cotizacion != null;

  ResumenIngresos get resumen => ResumenIngresos(
    clave: reserva.id ?? reserva.clienteNombre,
    etiqueta: reserva.clienteNombre,
    fecha: reserva.fecha,
    ventas: ventas,
    costos: costos,
    cantidadVentas: tieneCotizacion ? 1 : 0,
    itemsSinCosto: itemsSinCosto,
  );
}

/// Cálculos compartidos por la pestaña de ingresos y sus pruebas unitarias.
abstract final class IngresoCalculadora {
  /// Ventas netas, costos y utilidad de una cotización.
  ///
  /// Se usa el subtotal más el costo de movilidad (sin impuestos) como venta,
  /// porque el impuesto no es ingreso del negocio. El costo se obtiene del
  /// precio de compra actual del producto asociado a cada línea del catálogo.
  static ResumenIngresos resumirCotizacion(
    Cotizacion cotizacion,
    Map<String, Producto> productos,
  ) {
    var costos = 0.0;
    var itemsSinCosto = 0;

    for (final item in cotizacion.items) {
      final productoId = item.productoId;
      final producto = productoId == null ? null : productos[productoId];
      if (producto == null) {
        itemsSinCosto++;
        continue;
      }
      costos += producto.precioCompra * item.cantidad;
    }

    return ResumenIngresos(
      clave: cotizacion.id ?? cotizacion.numeroCotizacion,
      etiqueta: cotizacion.numeroCotizacion,
      fecha: cotizacion.fecha.toLocal(),
      ventas: roundMoney(cotizacion.subtotal + cotizacion.costoMovilidad),
      costos: roundMoney(costos),
      cantidadVentas: 1,
      itemsSinCosto: itemsSinCosto,
    );
  }

  /// Agrupa las cotizaciones por día, mes o año.
  static List<ResumenIngresos> agruparPorFecha(
    Iterable<Cotizacion> cotizaciones,
    Map<String, Producto> productos, {
    required AgrupacionFecha agrupacion,
    DateTime? desde,
    DateTime? hasta,
  }) {
    final acumulados = <String, _Acumulado>{};

    for (final cotizacion in cotizaciones) {
      final fecha = cotizacion.fecha.toLocal();
      if (desde != null && fecha.isBefore(_inicioDelDia(desde))) continue;
      if (hasta != null &&
          !fecha.isBefore(_inicioDelDia(hasta).add(const Duration(days: 1)))) {
        continue;
      }

      final resumen = resumirCotizacion(cotizacion, productos);
      final clave = _claveFecha(fecha, agrupacion);
      final acumulado = acumulados.putIfAbsent(
        clave,
        () => _Acumulado(
          clave: clave,
          etiqueta: _etiquetaFecha(fecha, agrupacion),
          fecha: _fechaGrupo(fecha, agrupacion),
        ),
      );
      acumulado.ventas += resumen.ventas;
      acumulado.costos += resumen.costos;
      acumulado.cantidadVentas += 1;
      acumulado.itemsSinCosto += resumen.itemsSinCosto;
    }

    final resultado = acumulados.values
        .map(
          (acumulado) => ResumenIngresos(
            clave: acumulado.clave,
            etiqueta: acumulado.etiqueta,
            fecha: acumulado.fecha,
            ventas: roundMoney(acumulado.ventas),
            costos: roundMoney(acumulado.costos),
            cantidadVentas: acumulado.cantidadVentas,
            itemsSinCosto: acumulado.itemsSinCosto,
          ),
        )
        .toList();
    resultado.sort((a, b) => b.clave.compareTo(a.clave));
    return resultado;
  }

  /// Calcula la utilidad de cada reserva/evento cruzando `cotizacionId` o
  /// `cotizacionNumero` con la colección de cotizaciones.
  static List<IngresoEvento> eventos(
    Iterable<Reserva> reservas,
    Iterable<Cotizacion> cotizaciones,
    Map<String, Producto> productos, {
    DateTime? desde,
    DateTime? hasta,
  }) {
    final porId = <String, Cotizacion>{};
    final porNumero = <String, Cotizacion>{};
    for (final cotizacion in cotizaciones) {
      final id = cotizacion.id;
      if (id != null && id.isNotEmpty) porId[id] = cotizacion;
      if (cotizacion.numeroCotizacion.isNotEmpty) {
        porNumero[cotizacion.numeroCotizacion] = cotizacion;
      }
    }

    final resultado = <IngresoEvento>[];
    for (final reserva in reservas) {
      final fecha = reserva.fecha.toLocal();
      if (desde != null && fecha.isBefore(_inicioDelDia(desde))) continue;
      if (hasta != null &&
          !fecha.isBefore(_inicioDelDia(hasta).add(const Duration(days: 1)))) {
        continue;
      }

      final cotizacion =
          porId[reserva.cotizacionId] ?? porNumero[reserva.cotizacionNumero];
      final resumen = cotizacion == null
          ? null
          : resumirCotizacion(cotizacion, productos);

      resultado.add(
        IngresoEvento(
          reserva: reserva,
          cotizacion: cotizacion,
          ventas: resumen?.ventas ?? 0,
          costos: resumen?.costos ?? 0,
          itemsSinCosto: resumen?.itemsSinCosto ?? 0,
        ),
      );
    }

    resultado.sort((a, b) => b.reserva.fecha.compareTo(a.reserva.fecha));
    return resultado;
  }

  /// Suma varios resúmenes en uno solo para las tarjetas de totales.
  static ResumenIngresos totalizar(
    Iterable<ResumenIngresos> resumenes, {
    String etiqueta = 'Total',
  }) {
    var ventas = 0.0;
    var costos = 0.0;
    var cantidad = 0;
    var sinCosto = 0;
    for (final resumen in resumenes) {
      ventas += resumen.ventas;
      costos += resumen.costos;
      cantidad += resumen.cantidadVentas;
      sinCosto += resumen.itemsSinCosto;
    }
    return ResumenIngresos(
      clave: 'total',
      etiqueta: etiqueta,
      ventas: roundMoney(ventas),
      costos: roundMoney(costos),
      cantidadVentas: cantidad,
      itemsSinCosto: sinCosto,
    );
  }

  static String _claveFecha(DateTime fecha, AgrupacionFecha agrupacion) {
    switch (agrupacion) {
      case AgrupacionFecha.dia:
        return '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';
      case AgrupacionFecha.mes:
        return '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}';
      case AgrupacionFecha.anio:
        return fecha.year.toString().padLeft(4, '0');
    }
  }

  static String _etiquetaFecha(DateTime fecha, AgrupacionFecha agrupacion) {
    switch (agrupacion) {
      case AgrupacionFecha.dia:
        return '${fecha.day.toString().padLeft(2, '0')}/'
            '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      case AgrupacionFecha.mes:
        return '${_meses[fecha.month - 1]} ${fecha.year}';
      case AgrupacionFecha.anio:
        return '${fecha.year}';
    }
  }

  static DateTime _fechaGrupo(DateTime fecha, AgrupacionFecha agrupacion) {
    switch (agrupacion) {
      case AgrupacionFecha.dia:
        return DateTime(fecha.year, fecha.month, fecha.day);
      case AgrupacionFecha.mes:
        return DateTime(fecha.year, fecha.month);
      case AgrupacionFecha.anio:
        return DateTime(fecha.year);
    }
  }

  static DateTime _inicioDelDia(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  static const List<String> _meses = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
}

class _Acumulado {
  _Acumulado({
    required this.clave,
    required this.etiqueta,
    required this.fecha,
  });

  final String clave;
  final String etiqueta;
  final DateTime fecha;
  double ventas = 0;
  double costos = 0;
  int cantidadVentas = 0;
  int itemsSinCosto = 0;
}
