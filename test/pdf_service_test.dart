import 'dart:convert';

import 'package:cotizador_app/models/cotizacion.dart';
import 'package:cotizador_app/models/empresa_config.dart';
import 'package:cotizador_app/models/item_cotizacion.dart';
import 'package:cotizador_app/models/reserva.dart';
import 'package:cotizador_app/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  test('genera un documento PDF con los datos de la cotización', () async {
    final cotizacion = Cotizacion.crear(
      numeroCotizacion: 'COT-PDF-001',
      clienteNombre: 'Cliente de prueba',
      clienteTelefono: '+52 55 0000 0000',
      clienteEmail: 'cliente@example.com',
      fecha: DateTime.utc(2026, 10, 30, 18, 30),
      items: const <ItemCotizacion>[
        ItemCotizacion(
          descripcion: 'Servicio de consultoría',
          cantidad: 2,
          precioUnitario: 1500,
        ),
        ItemCotizacion(
          descripcion: 'Licencia anual',
          cantidad: 1,
          precioUnitario: 2500,
        ),
      ],
      aplicarImpuesto: true,
      porcentajeImpuesto: 16,
      notas: 'Pago a 15 días naturales.',
    );

    final bytes = await PdfService().generar(cotizacion);

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('incluye los datos configurables de la empresa y su logotipo', () async {
    final cotizacion = Cotizacion.crear(
      numeroCotizacion: 'COT-PDF-002',
      clienteNombre: 'Cliente de prueba',
      clienteTelefono: '+52 55 0000 0000',
      clienteEmail: 'cliente@example.com',
      fecha: DateTime.utc(2026, 10, 30, 18, 30),
      items: const <ItemCotizacion>[
        ItemCotizacion(
          descripcion: 'Servicio',
          cantidad: 1,
          precioUnitario: 500,
        ),
      ],
      aplicarImpuesto: false,
      porcentajeImpuesto: 0,
    );

    // PNG de 1x1 píxel para comprobar que el logotipo se incrusta sin errores.
    const logo =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
        'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    const empresa = EmpresaConfig(
      nombre: 'Dulce Tentación',
      eslogan: 'Postres artesanales',
      telefono: '+51 987 654 321',
      email: 'ventas@dulcetentacion.pe',
      direccion: 'Av. Principal 123, Lima',
      sitioWeb: '@dulcetentacion',
      logoBase64: logo,
    );

    final bytes = await PdfService().generar(cotizacion, empresa: empresa);

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('genera la boleta de una reserva completada con movilidad', () async {
    final reserva = Reserva(
      id: 'res-pdf-1',
      clienteId: 'cli-1',
      clienteNombre: 'Cliente de prueba',
      fecha: DateTime.utc(2026, 11, 20, 18),
      estado: EstadoReserva.completada,
      costoMovilidad: 120,
      abonoInicial: 200,
      items: const <ReservaItem>[
        ReservaItem(descripcion: 'Servicio', cantidad: 2, precioUnitario: 300),
      ],
    );

    final bytes = await PdfService().generarBoleta(reserva);

    expect(PdfService.numeroBoleta(reserva), 'B-RESPDF1');
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('genera la cotización de gastos por categorías', () async {
    final reserva = Reserva(
      id: 'res-pdf-2',
      clienteId: 'cli-1',
      clienteNombre: 'Cliente de prueba',
      fecha: DateTime.utc(2026, 11, 20, 18),
      items: const <ReservaItem>[
        ReservaItem(
          descripcion: 'Insumo',
          cantidad: 2,
          precioUnitario: 300,
          costoUnitario: 100,
        ),
        ReservaItem(
          descripcion: 'Personal',
          cantidad: 1,
          precioUnitario: 200,
          costoUnitario: 80,
          tipoCosto: TipoCostoReserva.manoObra,
        ),
      ],
    );

    final bytes = await PdfService().generarCotizacionGastos(reserva);

    expect(PdfService.numeroCotizacionGastos(reserva), 'G-RESPDF2');
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
