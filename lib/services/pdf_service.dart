import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/app_config.dart';
import '../core/moneda.dart';
import '../models/cotizacion.dart';
import '../models/empresa_config.dart';
import '../models/producto.dart';
import '../models/reserva.dart';
import '../utils/formatters.dart';
import '../utils/num_utils.dart';

/// Genera el documento PDF formal de una cotización.
///
/// El PDF se construye completamente en memoria, por lo que funciona igual en
/// Android y en Web. La visualización, impresión y descarga se delegan al
/// paquete `printing`.
class PdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF123B5D);
  static const PdfColor _accent = PdfColor.fromInt(0xFF2E86AB);
  static const PdfColor _text = PdfColor.fromInt(0xFF1F2933);
  static const PdfColor _muted = PdfColor.fromInt(0xFF667085);
  static const PdfColor _border = PdfColor.fromInt(0xFFD9E2E8);
  static const PdfColor _surface = PdfColor.fromInt(0xFFF3F7FA);

  Future<Uint8List> generar(
    Cotizacion cotizacion, {
    EmpresaConfig? empresa,
  }) async {
    final datosEmpresa = empresa ?? const EmpresaConfig();

    final document = pw.Document(
      title: 'Cotización ${cotizacion.numeroCotizacion}',
      author: datosEmpresa.nombre,
      creator: AppConfig.nombreApp,
      subject: 'Cotización para ${cotizacion.clienteNombre}',
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 44),
        header: (context) => _encabezado(cotizacion, datosEmpresa),
        footer: (context) => _pieDePagina(context, datosEmpresa),
        build: (context) => <pw.Widget>[
          pw.SizedBox(height: 18),
          _bloqueCliente(cotizacion),
          pw.SizedBox(height: 20),
          _tituloSeccion('Detalle de productos y servicios'),
          pw.SizedBox(height: 8),
          _tablaItems(cotizacion),
          pw.SizedBox(height: 14),
          _bloqueTotales(cotizacion),
          if (cotizacion.notas.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 20),
            _tituloSeccion('Notas y condiciones'),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _surface,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                cotizacion.notas,
                style: const pw.TextStyle(fontSize: 9, color: _text),
              ),
            ),
          ],
          pw.SizedBox(height: 22),
          _avisoVigencia(cotizacion.moneda),
          pw.SizedBox(height: 34),
          _firmas(datosEmpresa),
        ],
      ),
    );

    return document.save();
  }

  /// Folio visible de la boleta de una reserva.
  static String numeroBoleta(Reserva reserva) {
    final base = reserva.id ?? reserva.cotizacionNumero;
    final limpio = base.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final corto = limpio.length > 10
        ? limpio.substring(limpio.length - 10)
        : limpio;
    return 'B-${corto.isEmpty ? '000001' : corto.toUpperCase()}';
  }

  /// Folio visible de la cotización de gastos de una reserva.
  static String numeroCotizacionGastos(Reserva reserva) {
    final base = reserva.id ?? reserva.cotizacionNumero;
    final limpio = base.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final corto = limpio.length > 10
        ? limpio.substring(limpio.length - 10)
        : limpio;
    return 'G-${corto.isEmpty ? '000001' : corto.toUpperCase()}';
  }

  /// Genera la boleta de venta de una reserva completada.
  Future<Uint8List> generarBoleta(
    Reserva reserva, {
    EmpresaConfig? empresa,
  }) async {
    final datosEmpresa = empresa ?? const EmpresaConfig();
    final numero = numeroBoleta(reserva);

    final document = pw.Document(
      title: 'Boleta $numero',
      author: datosEmpresa.nombre,
      creator: AppConfig.nombreApp,
      subject: 'Boleta de venta para ${reserva.clienteNombre}',
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 44),
        header: (context) => _encabezadoDocumento(
          datosEmpresa,
          tipoDocumento: 'BOLETA DE VENTA',
          numero: numero,
        ),
        footer: (context) => _pieDePagina(context, datosEmpresa),
        build: (context) => <pw.Widget>[
          pw.SizedBox(height: 18),
          _bloqueReserva(reserva),
          pw.SizedBox(height: 20),
          _tituloSeccion('Detalle de la venta'),
          pw.SizedBox(height: 8),
          _tablaItemsReserva(_itemsReserva(reserva), reserva.moneda),
          pw.SizedBox(height: 14),
          _bloqueTotalesReserva(reserva),
          pw.SizedBox(height: 20),
          _avisoBoleta(reserva),
          pw.SizedBox(height: 34),
          _firmas(datosEmpresa),
        ],
      ),
    );

    return document.save();
  }

  /// Genera la cotización de gastos de una reserva, agrupada por insumos,
  /// mano de obra y otros gastos de cada ítem.
  Future<Uint8List> generarCotizacionGastos(
    Reserva reserva, {
    Map<String, Producto> productos = const <String, Producto>{},
    EmpresaConfig? empresa,
  }) async {
    final datosEmpresa = empresa ?? const EmpresaConfig();
    final numero = numeroCotizacionGastos(reserva);
    final items = _itemsConCosto(reserva, productos);
    final totalInsumos = _sumarCosto(items, TipoCostoReserva.insumo);
    final totalManoObra = _sumarCosto(items, TipoCostoReserva.manoObra);
    final totalOtros = _sumarCosto(items, TipoCostoReserva.otros);
    final totalGastos = roundMoney(totalInsumos + totalManoObra + totalOtros);

    final document = pw.Document(
      title: 'Cotización de gastos $numero',
      author: datosEmpresa.nombre,
      creator: AppConfig.nombreApp,
      subject: 'Gastos de la reserva de ${reserva.clienteNombre}',
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 44),
        header: (context) => _encabezadoDocumento(
          datosEmpresa,
          tipoDocumento: 'COTIZACIÓN DE GASTOS',
          numero: numero,
        ),
        footer: (context) => _pieDePagina(context, datosEmpresa),
        build: (context) => <pw.Widget>[
          pw.SizedBox(height: 18),
          _bloqueReserva(reserva),
          pw.SizedBox(height: 20),
          _tituloSeccion('Gastos por ítem de la reserva'),
          pw.SizedBox(height: 8),
          _tablaGastos(items, reserva.moneda),
          pw.SizedBox(height: 14),
          _bloqueTotalesGastos(
            reserva,
            totalInsumos: totalInsumos,
            totalManoObra: totalManoObra,
            totalOtros: totalOtros,
            totalGastos: totalGastos,
          ),
          pw.SizedBox(height: 20),
          _avisoGastos(),
          pw.SizedBox(height: 34),
          _firmas(datosEmpresa),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _encabezadoDocumento(
    EmpresaConfig empresa, {
    required String tipoDocumento,
    required String numero,
  }) {
    final contacto = _lineaContacto(empresa);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Row(
                  children: <pw.Widget>[
                    _marcaEmpresa(empresa),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.Text(
                            empresa.nombre,
                            style: const pw.TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (empresa.eslogan.isNotEmpty) ...<pw.Widget>[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              empresa.eslogan,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: _muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text(
                    tipoDocumento,
                    style: const pw.TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    numero,
                    style: const pw.TextStyle(
                      color: _text,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (contacto.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 7),
            pw.Text(
              contacto,
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _bloqueReserva(Reserva reserva) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'CLIENTE',
                  style: const pw.TextStyle(
                    color: _accent,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(
                  reserva.clienteNombre.isEmpty
                      ? 'Cliente sin nombre'
                      : reserva.clienteNombre,
                  style: const pw.TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (reserva.cotizacionNumero.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 5),
                  _datoContacto('Cotización', reserva.cotizacionNumero),
                ],
                if (reserva.tipoEvento.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  _datoContacto('Evento', reserva.tipoEvento),
                ],
                if (reserva.lugar.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  _datoContacto('Lugar', reserva.lugar),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 26),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              children: <pw.Widget>[
                _filaInfo('Fecha', AppFormatters.date(reserva.fecha)),
                pw.SizedBox(height: 6),
                _filaInfo('Hora', reserva.horaInicio),
                pw.SizedBox(height: 6),
                _filaInfo(
                  'Moneda',
                  Moneda.desdeCodigo(reserva.moneda).etiqueta,
                ),
                pw.SizedBox(height: 6),
                _filaInfo('Estado', reserva.estado.toUpperCase()),
                if (reserva.numeroInvitados > 0) ...<pw.Widget>[
                  pw.SizedBox(height: 6),
                  _filaInfo('Invitados', '${reserva.numeroInvitados}'),
                ],
                pw.SizedBox(height: 6),
                _filaInfo('Ítems', '${reserva.cantidadItems}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ReservaItem> _itemsReserva(Reserva reserva) {
    if (reserva.items.isNotEmpty) return reserva.items;
    return <ReservaItem>[
      ReservaItem(
        descripcion: reserva.productoNombre.isEmpty
            ? 'Servicio de la reserva'
            : reserva.productoNombre,
        productoId: reserva.productoId,
        cantidad: reserva.cantidad <= 0 ? 1 : reserva.cantidad,
        precioUnitario: reserva.precioUnitario,
        costoUnitario: reserva.costoUnitario,
        tipoCosto: reserva.tipoCosto,
      ),
    ];
  }

  List<ReservaItem> _itemsConCosto(
    Reserva reserva,
    Map<String, Producto> productos,
  ) {
    return _itemsReserva(reserva)
        .map((item) {
          if (item.costoUnitario > 0 || item.productoId.isEmpty) return item;
          final producto = productos[item.productoId];
          if (producto == null) return item;
          return item.copyWith(costoUnitario: producto.precioCompra);
        })
        .toList(growable: false);
  }

  double _sumarCosto(List<ReservaItem> items, String tipo) {
    return roundMoney(
      items
          .where((item) => item.tipoCosto == tipo)
          .fold<double>(0, (total, item) => total + item.costoTotal),
    );
  }

  pw.Widget _tablaItemsReserva(List<ReservaItem> items, String moneda) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _primary),
        children: <pw.Widget>[
          _celdaTabla('Descripción', header: true),
          _celdaTabla('Cant.', header: true, align: pw.TextAlign.right),
          _celdaTabla('P. unitario', header: true, align: pw.TextAlign.right),
          _celdaTabla('Importe', header: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : _surface,
          ),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: <pw.Widget>[
            _celdaTabla(item.descripcion),
            _celdaTabla(
              AppFormatters.quantity(item.cantidad),
              align: pw.TextAlign.right,
            ),
            _celdaTabla(
              AppFormatters.money(item.precioUnitario, moneda: moneda),
              align: pw.TextAlign.right,
            ),
            _celdaTabla(
              AppFormatters.money(item.total, moneda: moneda),
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: _border, width: 0.7),
        horizontalInside: pw.BorderSide(color: _border, width: 0.4),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(4.4),
        1: const pw.FixedColumnWidth(42),
        2: const pw.FixedColumnWidth(78),
        3: const pw.FixedColumnWidth(78),
      },
      children: rows,
    );
  }

  pw.Widget _tablaGastos(List<ReservaItem> items, String moneda) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _primary),
        children: <pw.Widget>[
          _celdaTabla('Descripción', header: true),
          _celdaTabla('Categoría', header: true),
          _celdaTabla('Cant.', header: true, align: pw.TextAlign.right),
          _celdaTabla('Costo unit.', header: true, align: pw.TextAlign.right),
          _celdaTabla('Importe', header: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : _surface,
          ),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: <pw.Widget>[
            _celdaTabla(item.descripcion),
            _celdaTabla(TipoCostoReserva.etiqueta(item.tipoCosto)),
            _celdaTabla(
              AppFormatters.quantity(item.cantidad),
              align: pw.TextAlign.right,
            ),
            _celdaTabla(
              AppFormatters.money(item.costoUnitario, moneda: moneda),
              align: pw.TextAlign.right,
            ),
            _celdaTabla(
              AppFormatters.money(item.costoTotal, moneda: moneda),
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: _border, width: 0.7),
        horizontalInside: pw.BorderSide(color: _border, width: 0.4),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(3.2),
        1: const pw.FixedColumnWidth(72),
        2: const pw.FixedColumnWidth(38),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
      },
      children: rows,
    );
  }

  pw.Widget _bloqueTotalesReserva(Reserva reserva) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: <pw.Widget>[
        pw.Container(
          width: 260,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(7),
            border: pw.Border.all(color: _border, width: 0.7),
          ),
          child: pw.Column(
            children: <pw.Widget>[
              _filaTotal(
                'Subtotal',
                AppFormatters.money(reserva.subtotal, moneda: reserva.moneda),
              ),
              pw.SizedBox(height: 7),
              _filaTotal(
                'Costo de movilidad',
                AppFormatters.money(
                  reserva.costoMovilidad,
                  moneda: reserva.moneda,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: pw.BoxDecoration(
                  color: _primary,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text(
                      'TOTAL',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.Text(
                      AppFormatters.money(
                        reserva.total,
                        moneda: reserva.moneda,
                      ),
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 9),
              _filaTotal(
                'Abono inicial',
                AppFormatters.money(
                  reserva.abonoInicial,
                  moneda: reserva.moneda,
                ),
              ),
              pw.SizedBox(height: 6),
              _filaTotal(
                'Saldo pendiente',
                AppFormatters.money(
                  reserva.saldoPendiente,
                  moneda: reserva.moneda,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _bloqueTotalesGastos(
    Reserva reserva, {
    required double totalInsumos,
    required double totalManoObra,
    required double totalOtros,
    required double totalGastos,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: <pw.Widget>[
        pw.Container(
          width: 275,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(7),
            border: pw.Border.all(color: _border, width: 0.7),
          ),
          child: pw.Column(
            children: <pw.Widget>[
              _filaTotal(
                'Insumos',
                AppFormatters.money(totalInsumos, moneda: reserva.moneda),
              ),
              pw.SizedBox(height: 7),
              _filaTotal(
                'Mano de obra',
                AppFormatters.money(totalManoObra, moneda: reserva.moneda),
              ),
              pw.SizedBox(height: 7),
              _filaTotal(
                'Otros',
                AppFormatters.money(totalOtros, moneda: reserva.moneda),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: pw.BoxDecoration(
                  color: _primary,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text(
                      'TOTAL GASTOS',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.Text(
                      AppFormatters.money(totalGastos, moneda: reserva.moneda),
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 9),
              _filaTotal(
                'Venta de la reserva',
                AppFormatters.money(reserva.total, moneda: reserva.moneda),
              ),
              pw.SizedBox(height: 6),
              _filaTotal(
                'Utilidad estimada',
                AppFormatters.money(
                  roundMoney(reserva.total - totalGastos),
                  moneda: reserva.moneda,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _avisoBoleta(Reserva reserva) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        'Gracias por su preferencia. Esta boleta resume la reserva de '
        '${reserva.clienteNombre} y los importes acordados. '
        'El saldo pendiente puede cancelarse antes o durante el evento.',
        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
      ),
    );
  }

  pw.Widget _avisoGastos() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        'Los costos son estimados y se agrupan por insumos, mano de obra y '
        'otros gastos de cada ítem. Puedes actualizarlos desde la sección '
        'Impresora antes de generar el documento.',
        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
      ),
    );
  }

  pw.Widget _encabezado(Cotizacion cotizacion, EmpresaConfig empresa) {
    final contacto = _lineaContacto(empresa);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Row(
                  children: <pw.Widget>[
                    _marcaEmpresa(empresa),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.Text(
                            empresa.nombre,
                            style: const pw.TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (empresa.eslogan.isNotEmpty) ...<pw.Widget>[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              empresa.eslogan,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: _muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text(
                    'COTIZACIÓN',
                    style: const pw.TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    cotizacion.numeroCotizacion,
                    style: const pw.TextStyle(
                      color: _text,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (contacto.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 7),
            pw.Text(
              contacto,
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _marcaEmpresa(EmpresaConfig empresa) {
    final logo = _logo(empresa.logoBase64);

    return pw.Container(
      width: 42,
      height: 42,
      padding: logo == null ? null : const pw.EdgeInsets.all(3),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: logo == null ? _primary : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: logo == null ? null : pw.Border.all(color: _border, width: 0.7),
      ),
      child: logo == null
          ? pw.Text(
              _inicialesEmpresa(empresa.nombre),
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            )
          : pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  pw.MemoryImage? _logo(String logoBase64) {
    if (logoBase64.trim().isEmpty) return null;
    try {
      final bytes = base64Decode(logoBase64);
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  String _lineaContacto(EmpresaConfig empresa) {
    return <String>[
      empresa.direccion,
      empresa.telefono,
      empresa.email,
      empresa.sitioWeb,
    ].where((valor) => valor.trim().isNotEmpty).join('  ·  ');
  }

  pw.Widget _bloqueCliente(Cotizacion cotizacion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'COTIZACIÓN PARA',
                  style: const pw.TextStyle(
                    color: _accent,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(
                  cotizacion.clienteNombre.isEmpty
                      ? 'Cliente sin nombre'
                      : cotizacion.clienteNombre,
                  style: const pw.TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (cotizacion.clienteTelefono.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 5),
                  _datoContacto('Teléfono', cotizacion.clienteTelefono),
                ],
                if (cotizacion.clienteEmail.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 3),
                  _datoContacto('Email', cotizacion.clienteEmail),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 26),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              children: <pw.Widget>[
                _filaInfo('Fecha', AppFormatters.dateTime(cotizacion.fecha)),
                pw.SizedBox(height: 6),
                _filaInfo(
                  'Moneda',
                  Moneda.desdeCodigo(cotizacion.moneda).etiqueta,
                ),
                pw.SizedBox(height: 6),
                _filaInfo('Estado', cotizacion.estado.toUpperCase()),
                if (cotizacion.lugar.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 6),
                  _filaInfo('Lugar', cotizacion.lugar),
                ],
                if (cotizacion.tipoEvento.isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 6),
                  _filaInfo('Evento', cotizacion.tipoEvento),
                ],
                if (cotizacion.numeroInvitados > 0) ...<pw.Widget>[
                  pw.SizedBox(height: 6),
                  _filaInfo('Invitados', '${cotizacion.numeroInvitados}'),
                ],
                if (cotizacion.costoMovilidad > 0) ...<pw.Widget>[
                  pw.SizedBox(height: 6),
                  _filaInfo(
                    'Movilidad',
                    AppFormatters.money(
                      cotizacion.costoMovilidad,
                      moneda: cotizacion.moneda,
                    ),
                  ),
                ],
                pw.SizedBox(height: 6),
                _filaInfo('Ítems', '${cotizacion.cantidadItems}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _datoContacto(String etiqueta, String valor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(
          width: 42,
          child: pw.Text(
            etiqueta,
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            valor,
            style: const pw.TextStyle(fontSize: 9, color: _text),
          ),
        ),
      ],
    );
  }

  pw.Widget _filaInfo(String etiqueta, String valor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          etiqueta,
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
        pw.SizedBox(width: 8),
        pw.Flexible(
          child: pw.Text(
            valor,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: _text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _tituloSeccion(String titulo) {
    return pw.Text(
      titulo.toUpperCase(),
      style: const pw.TextStyle(
        color: _primary,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  pw.Widget _tablaItems(Cotizacion cotizacion) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _primary),
        children: <pw.Widget>[
          _celdaTabla('Descripción', header: true),
          _celdaTabla('Cant.', header: true, align: pw.TextAlign.right),
          _celdaTabla('P. unitario', header: true, align: pw.TextAlign.right),
          _celdaTabla('Importe', header: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var index = 0; index < cotizacion.items.length; index++) {
      final item = cotizacion.items[index];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : _surface,
          ),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: <pw.Widget>[
            _celdaTabla(item.descripcion),
            _celdaTabla(
              AppFormatters.quantity(item.cantidad),
              align: pw.TextAlign.right,
            ),
            _celdaTabla(
              AppFormatters.money(
                item.precioUnitario,
                moneda: cotizacion.moneda,
              ),
              align: pw.TextAlign.right,
            ),
            _celdaTabla(
              AppFormatters.money(item.total, moneda: cotizacion.moneda),
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: _border, width: 0.7),
        horizontalInside: pw.BorderSide(color: _border, width: 0.4),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(4.4),
        1: const pw.FixedColumnWidth(42),
        2: const pw.FixedColumnWidth(78),
        3: const pw.FixedColumnWidth(78),
      },
      children: rows,
    );
  }

  pw.Widget _celdaTabla(
    String texto, {
    bool header = false,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        texto,
        textAlign: align,
        style: pw.TextStyle(
          color: header ? PdfColors.white : _text,
          fontSize: header ? 8 : 8.5,
          fontWeight: header || bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _bloqueTotales(Cotizacion cotizacion) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: <pw.Widget>[
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(7),
            border: pw.Border.all(color: _border, width: 0.7),
          ),
          child: pw.Column(
            children: <pw.Widget>[
              _filaTotal(
                'Subtotal',
                AppFormatters.money(
                  cotizacion.subtotal,
                  moneda: cotizacion.moneda,
                ),
              ),
              if (cotizacion.aplicarImpuesto) ...<pw.Widget>[
                pw.SizedBox(height: 7),
                _filaTotal(
                  '${AppConfig.nombreImpuesto} '
                  '(${AppFormatters.percentage(cotizacion.porcentajeImpuesto)})',
                  AppFormatters.money(
                    cotizacion.impuesto,
                    moneda: cotizacion.moneda,
                  ),
                ),
              ] else ...<pw.Widget>[
                pw.SizedBox(height: 7),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '${AppConfig.nombreImpuesto} no aplicado',
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ),
              ],
              if (cotizacion.costoMovilidad > 0) ...<pw.Widget>[
                pw.SizedBox(height: 7),
                _filaTotal(
                  'Costo de movilidad',
                  AppFormatters.money(
                    cotizacion.costoMovilidad,
                    moneda: cotizacion.moneda,
                  ),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: pw.BoxDecoration(
                  color: _primary,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text(
                      'TOTAL',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.Text(
                      AppFormatters.money(
                        cotizacion.total,
                        moneda: cotizacion.moneda,
                      ),
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _filaTotal(String etiqueta, String valor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Flexible(
          child: pw.Text(
            etiqueta,
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          valor,
          style: const pw.TextStyle(
            fontSize: 9,
            color: _text,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _avisoVigencia(String moneda) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        'Esta cotización tiene una vigencia de 15 días naturales a partir de la '
        'fecha de emisión. Los precios están expresados en $moneda. '
        'Cualquier cambio en las condiciones originales puede modificar el total.',
        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
      ),
    );
  }

  pw.Widget _firmas(EmpresaConfig empresa) {
    return pw.Row(
      children: <pw.Widget>[
        pw.Expanded(child: _lineaFirma('Elaboró', empresa.nombre)),
        pw.SizedBox(width: 46),
        pw.Expanded(child: _lineaFirma('Aceptó por el cliente', '')),
      ],
    );
  }

  pw.Widget _lineaFirma(String titulo, String subtitulo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(height: 26),
        pw.Container(width: double.infinity, height: 0.8, color: _muted),
        pw.SizedBox(height: 5),
        pw.Text(titulo, style: const pw.TextStyle(fontSize: 8, color: _text)),
        if (subtitulo.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 2),
          pw.Text(
            subtitulo,
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ],
      ],
    );
  }

  pw.Widget _pieDePagina(pw.Context context, EmpresaConfig empresa) {
    final contacto = <String>[
      empresa.nombre,
      empresa.telefono,
      empresa.email,
      empresa.sitioWeb,
    ].where((valor) => valor.trim().isNotEmpty).join('  |  ');

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              contacto,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ],
      ),
    );
  }

  String _inicialesEmpresa(String nombre) {
    final words = nombre
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .take(2);
    final initials = words.map((word) => word.trim()[0]).join().toUpperCase();
    return initials.isEmpty ? 'EM' : initials;
  }
}
