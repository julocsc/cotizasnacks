import 'package:cotizador_app/models/cotizacion.dart';
import 'package:cotizador_app/models/item_cotizacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cotizacion', () {
    test('calcula subtotal, impuesto y total', () {
      final cotizacion = Cotizacion.crear(
        numeroCotizacion: 'COT-TEST-001',
        clienteNombre: 'Ana Torres',
        clienteTelefono: '+52 55 1234 5678',
        clienteEmail: 'ana@example.com',
        fecha: DateTime.utc(2026, 10, 30, 12),
        items: const <ItemCotizacion>[
          ItemCotizacion(
            descripcion: 'Diseño',
            cantidad: 2,
            precioUnitario: 500,
          ),
          ItemCotizacion(
            descripcion: 'Dominio',
            cantidad: 0.5,
            precioUnitario: 100,
          ),
        ],
        aplicarImpuesto: true,
        porcentajeImpuesto: 16,
      );

      expect(cotizacion.subtotal, 1050);
      expect(cotizacion.impuesto, 168);
      expect(cotizacion.total, 1218);
      expect(cotizacion.items.first.total, 1000);
    });

    test('no cobra impuestos cuando la opción está desactivada', () {
      final cotizacion = Cotizacion.crear(
        numeroCotizacion: 'COT-TEST-002',
        clienteNombre: 'Cliente',
        clienteTelefono: '',
        clienteEmail: '',
        items: const <ItemCotizacion>[
          ItemCotizacion(
            descripcion: 'Servicio',
            cantidad: 1,
            precioUnitario: 999.99,
          ),
        ],
        aplicarImpuesto: false,
        porcentajeImpuesto: 16,
      );

      expect(cotizacion.porcentajeImpuesto, 0);
      expect(cotizacion.impuesto, 0);
      expect(cotizacion.total, 999.99);
    });

    test('redondea los importes a dos decimales', () {
      final cotizacion = Cotizacion.crear(
        numeroCotizacion: 'COT-TEST-003',
        clienteNombre: 'Cliente',
        clienteTelefono: '',
        clienteEmail: '',
        items: const <ItemCotizacion>[
          ItemCotizacion(
            descripcion: 'Hora',
            cantidad: 3,
            precioUnitario: 33.333,
          ),
        ],
        aplicarImpuesto: true,
        porcentajeImpuesto: 16,
      );

      expect(cotizacion.subtotal, 100);
      expect(cotizacion.impuesto, 16);
      expect(cotizacion.total, 116);
    });

    test('toMap y fromMap conservan los datos analíticos', () {
      final original = Cotizacion.crear(
        numeroCotizacion: 'COT-TEST-004',
        clienteNombre: 'María López',
        clienteTelefono: '5555555555',
        clienteEmail: 'maria@example.com',
        fecha: DateTime.utc(2026, 10, 30, 18, 30),
        items: const <ItemCotizacion>[
          ItemCotizacion(
            descripcion: 'Consultoría',
            cantidad: 4,
            precioUnitario: 250,
          ),
        ],
        aplicarImpuesto: true,
        porcentajeImpuesto: 16,
        notas: 'Pago a 15 días.',
        lugar: 'Salón Real',
        tipoEvento: 'Boda',
        numeroInvitados: 120,
        costoMovilidad: 150,
        creadoPorUid: 'u-1',
        creadoPorNombre: 'Vendedor Uno',
        creadoPorEmail: 'VENDEDOR@EXAMPLE.COM',
        creadoPorTelefono: '+51 999 111 222',
      );

      final map = original.toMap();
      final restaurada = Cotizacion.fromMap('doc-123', map);

      expect(map['fecha'], '2026-10-30T18:30:00.000Z');
      expect(map['subtotal'], 1000);
      expect(map['impuesto'], 160);
      expect(map['total'], 1310);
      expect(map['lugar'], 'Salón Real');
      expect(map['tipoEvento'], 'Boda');
      expect(map['numeroInvitados'], 120);
      expect(map['costoMovilidad'], 150);
      expect(map['creadoPorEmail'], 'vendedor@example.com');
      expect(restaurada.id, 'doc-123');
      expect(restaurada.numeroCotizacion, original.numeroCotizacion);
      expect(restaurada.clienteNombre, original.clienteNombre);
      expect(restaurada.items.length, 1);
      expect(restaurada.items.first.total, 1000);
      expect(restaurada.total, 1310);
      expect(restaurada.notas, 'Pago a 15 días.');
      expect(restaurada.lugar, 'Salón Real');
      expect(restaurada.tipoEvento, 'Boda');
      expect(restaurada.numeroInvitados, 120);
      expect(restaurada.costoMovilidad, 150);
      expect(restaurada.creadoPorUid, 'u-1');
      expect(restaurada.creadoPorNombre, 'Vendedor Uno');
      expect(restaurada.creadoPorTelefono, '+51 999 111 222');
    });

    test('fromMap tolera documentos antiguos sin totales', () {
      final restaurada = Cotizacion.fromMap('doc-456', <String, dynamic>{
        'numeroCotizacion': 'COT-LEGACY',
        'cliente': <String, dynamic>{
          'nombre': 'Cliente antiguo',
          'telefono': '',
          'email': '',
        },
        'fecha': '2026-01-01T00:00:00.000Z',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'descripcion': 'Producto',
            'cantidad': 2,
            'precioUnitario': 50,
          },
        ],
        'porcentajeImpuesto': 16,
      });

      expect(restaurada.subtotal, 100);
      expect(restaurada.impuesto, 16);
      expect(restaurada.total, 116);
    });
  });
}
