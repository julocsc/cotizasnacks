import 'package:cotizador_app/models/categoria_producto.dart';
import 'package:cotizador_app/models/cliente.dart';
import 'package:cotizador_app/models/producto.dart';
import 'package:cotizador_app/models/reserva.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Producto', () {
    test('calcula el margen y conserva la imagen', () {
      const producto = Producto(
        id: 'p1',
        nombre: 'Laptop',
        categoriaId: 'c1',
        categoriaNombre: 'Tecnología',
        precioCompra: 1000,
        precioVenta: 1500,
        imagenBase64: 'abc123',
      );

      expect(producto.margen, 500);
      expect(producto.margenPorcentaje, 50);

      final map = producto.toMap();
      expect(map['precioCompra'], 1000);
      expect(map['precioVenta'], 1500);
      expect(map['imagenBase64'], 'abc123');

      final reconstruido = Producto.fromMap('p1', map);
      expect(reconstruido.nombre, 'Laptop');
      expect(reconstruido.categoriaNombre, 'Tecnología');
      expect(reconstruido.precioVenta, 1500);
    });

    test('tolera documentos sin imagen ni categoría', () {
      final producto = Producto.fromMap('p2', <String, dynamic>{
        'nombre': 'Servicio',
        'precioVenta': 120,
      });

      expect(producto.imagenBase64, '');
      expect(producto.categoriaNombre, 'Sin categoría');
      expect(producto.activo, isTrue);
    });
  });

  test('Cliente reconstruye sus datos de contacto', () {
    final cliente = Cliente.fromMap('c1', <String, dynamic>{
      'nombre': 'María López',
      'telefono': '999999999',
      'email': 'maria@example.com',
      'documento': '12345678',
    });

    expect(cliente.nombre, 'María López');
    expect(cliente.telefono, '999999999');
    expect(cliente.email, 'maria@example.com');
    expect(cliente.documento, '12345678');
  });

  test('Cliente detecta duplicados por teléfono o email', () {
    const registrado = Cliente(
      id: 'c1',
      nombre: 'María López',
      telefono: '+51 999 999 999',
      email: 'maria@example.com',
    );

    const mismoTelefono = Cliente(nombre: 'María L.', telefono: '999999999');
    const mismoEmail = Cliente(
      nombre: 'Otra razón social',
      email: 'MARIA@example.com',
    );
    const distinto = Cliente(
      nombre: 'María López',
      telefono: '+51 988 888 888',
    );

    expect(registrado.coincideCon(mismoTelefono), isTrue);
    expect(registrado.coincideCon(mismoEmail), isTrue);
    expect(registrado.coincideCon(distinto), isFalse);
  });

  test('CategoriaProducto normaliza el nombre', () {
    final categoria = CategoriaProducto.fromMap('cat1', <String, dynamic>{
      'nombre': '  Bebidas  ',
    });

    expect(categoria.id, 'cat1');
    expect(categoria.nombre, 'Bebidas');
    expect(categoria.toMap()['nombre'], 'Bebidas');
  });

  test('Reserva reconstruye fecha, estado y producto', () {
    final reserva = Reserva.fromMap('r1', <String, dynamic>{
      'clienteId': 'c1',
      'clienteNombre': 'María López',
      'productoId': 'p1',
      'productoNombre': 'Laptop',
      'fecha': '2026-11-05T15:30:00.000Z',
      'cantidad': 2,
      'estado': EstadoReserva.confirmada,
      'notas': 'Entregar en tienda',
    });

    expect(reserva.clienteNombre, 'María López');
    expect(reserva.productoNombre, 'Laptop');
    expect(reserva.cantidad, 2);
    expect(reserva.estado, EstadoReserva.confirmada);
    expect(reserva.fecha.toUtc().year, 2026);
  });

  test('Reserva conserva varios ítems en un solo documento', () {
    final reserva = Reserva.fromMap('r2', <String, dynamic>{
      'clienteId': 'c1',
      'clienteNombre': 'María López',
      'fecha': '2026-11-05T15:30:00.000Z',
      'cantidad': 5,
      'estado': EstadoReserva.pendiente,
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Laptop',
          'productoId': 'p1',
          'cantidad': 2,
        },
        <String, dynamic>{'descripcion': 'Mouse', 'cantidad': 3},
      ],
    });

    expect(reserva.items.length, 2);
    expect(reserva.cantidadItems, 2);
    expect(reserva.cantidadTotal, 5);
    expect(reserva.resumenProductos, '2 ítems reservados');

    final map = reserva.toMap();
    expect((map['items'] as List<dynamic>).length, 2);
  });

  test('Reserva conserva la cotización de origen', () {
    final reserva = Reserva(
      clienteId: 'c1',
      clienteNombre: 'María López',
      productoNombre: 'Laptop',
      fecha: DateTime.utc(2026, 11, 5, 15, 30),
      cotizacionId: 'cot-1',
      cotizacionNumero: 'COT-20261105-001',
    );

    final reconstruida = Reserva.fromMap('r1', reserva.toMap());

    expect(reconstruida.cotizacionId, 'cot-1');
    expect(reconstruida.cotizacionNumero, 'COT-20261105-001');
  });

  test('Reserva conserva los datos del evento y del creador', () {
    final reserva = Reserva(
      clienteId: 'c1',
      clienteNombre: 'María López',
      fecha: DateTime(2026, 12, 24, 20, 30),
      lugar: 'Salón Real',
      tipoEvento: 'Boda',
      numeroInvitados: 120,
      costoMovilidad: 150,
      abonoInicial: 500,
      moneda: 'USD',
      creadoPorUid: 'u1',
      creadoPorNombre: 'Ana Pérez',
      creadoPorEmail: 'ANA@EXAMPLE.COM',
      creadoPorTelefono: '+51 999 111 222',
    );

    expect(reserva.horaInicio, '20:30');
    expect(reserva.nombreCreador, 'Ana Pérez');

    final map = reserva.toMap();
    expect(map['lugar'], 'Salón Real');
    expect(map['tipoEvento'], 'Boda');
    expect(map['numeroInvitados'], 120);
    expect(map['costoMovilidad'], 150);
    expect(map['abonoInicial'], 500);
    expect(map['moneda'], 'USD');
    expect(map['creadoPorEmail'], 'ana@example.com');

    final reconstruida = Reserva.fromMap('r1', map);
    expect(reconstruida.lugar, 'Salón Real');
    expect(reconstruida.tipoEvento, 'Boda');
    expect(reconstruida.numeroInvitados, 120);
    expect(reconstruida.costoMovilidad, 150);
    expect(reconstruida.abonoInicial, 500);
    expect(reconstruida.moneda, 'USD');
    expect(reconstruida.creadoPorUid, 'u1');
    expect(reconstruida.creadoPorNombre, 'Ana Pérez');
    expect(reconstruida.creadoPorTelefono, '+51 999 111 222');
  });
}
