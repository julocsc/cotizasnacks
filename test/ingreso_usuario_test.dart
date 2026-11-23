import 'package:cotizador_app/models/cotizacion.dart';
import 'package:cotizador_app/models/ingreso.dart';
import 'package:cotizador_app/models/producto.dart';
import 'package:cotizador_app/models/reserva.dart';
import 'package:cotizador_app/models/usuario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const laptop = Producto(
    id: 'p1',
    nombre: 'Laptop',
    categoriaId: 'c1',
    categoriaNombre: 'Tecnología',
    precioCompra: 1000,
    precioVenta: 1500,
  );

  Cotizacion cotizacion({
    required String id,
    required String numero,
    required String fecha,
  }) {
    return Cotizacion.fromMap(id, <String, dynamic>{
      'numeroCotizacion': numero,
      'cliente': <String, dynamic>{'nombre': 'María López'},
      'fecha': fecha,
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Laptop',
          'cantidad': 2,
          'precioUnitario': 1500,
          'productoId': 'p1',
        },
        <String, dynamic>{
          'descripcion': 'Servicio manual',
          'cantidad': 1,
          'precioUnitario': 500,
        },
      ],
      'subtotal': 3500,
      'aplicarImpuesto': false,
      'porcentajeImpuesto': 0,
      'impuesto': 0,
      'total': 3500,
      'estado': 'emitida',
    });
  }

  group('IngresoCalculadora', () {
    test('calcula ventas, costos y utilidad de una cotización', () {
      final resumen = IngresoCalculadora.resumirCotizacion(
        cotizacion(
          id: 'cot-1',
          numero: 'COT-1',
          fecha: '2026-11-15T12:00:00.000Z',
        ),
        <String, Producto>{'p1': laptop},
      );

      expect(resumen.ventas, 3500);
      expect(resumen.costos, 2000);
      expect(resumen.utilidad, 1500);
      expect(resumen.itemsSinCosto, 1);
      expect(resumen.cantidadVentas, 1);
    });

    test('agrupa por mes y respeta el rango de fechas', () {
      final cotizaciones = <Cotizacion>[
        cotizacion(
          id: 'cot-1',
          numero: 'COT-1',
          fecha: '2026-10-15T12:00:00.000Z',
        ),
        cotizacion(
          id: 'cot-2',
          numero: 'COT-2',
          fecha: '2026-11-15T12:00:00.000Z',
        ),
      ];
      final productos = <String, Producto>{'p1': laptop};

      final todos = IngresoCalculadora.agruparPorFecha(
        cotizaciones,
        productos,
        agrupacion: AgrupacionFecha.mes,
      );
      expect(todos.length, 2);
      expect(todos.first.clave, '2026-11');
      expect(todos.first.ventas, 3500);

      final noviembre = IngresoCalculadora.agruparPorFecha(
        cotizaciones,
        productos,
        agrupacion: AgrupacionFecha.mes,
        desde: DateTime(2026, 11),
        hasta: DateTime(2026, 11, 30),
      );
      expect(noviembre.length, 1);
      expect(noviembre.single.clave, '2026-11');
    });

    test('cruza eventos con la cotización de origen', () {
      final cotizaciones = <Cotizacion>[
        cotizacion(
          id: 'cot-1',
          numero: 'COT-1',
          fecha: '2026-11-15T12:00:00.000Z',
        ),
      ];
      final reservas = <Reserva>[
        Reserva(
          id: 'r1',
          clienteId: 'c1',
          clienteNombre: 'María López',
          fecha: DateTime.utc(2026, 11, 20, 15),
          cotizacionId: 'cot-1',
          cotizacionNumero: 'COT-1',
        ),
        Reserva(
          id: 'r2',
          clienteId: 'c2',
          clienteNombre: 'Evento manual',
          fecha: DateTime.utc(2026, 11, 21, 15),
        ),
      ];

      final eventos = IngresoCalculadora.eventos(
        reservas,
        cotizaciones,
        <String, Producto>{'p1': laptop},
      );

      expect(eventos.length, 2);
      final vinculado = eventos.firstWhere((e) => e.reserva.id == 'r1');
      expect(vinculado.cotizacion?.id, 'cot-1');
      expect(vinculado.ventas, 3500);
      expect(vinculado.utilidad, 1500);

      final manual = eventos.firstWhere((e) => e.reserva.id == 'r2');
      expect(manual.cotizacion, isNull);
      expect(manual.ventas, 0);
      expect(manual.utilidad, 0);

      final total = IngresoCalculadora.totalizar(
        eventos.map((evento) => evento.resumen),
      );
      expect(total.ventas, 3500);
      expect(total.costos, 2000);
      expect(total.utilidad, 1500);
      expect(total.cantidadVentas, 1);
    });
  });

  group('Usuario y permisos', () {
    test('el administrador siempre tiene todos los permisos', () {
      final usuario = Usuario.fromMap('u1', <String, dynamic>{
        'email': 'JEFA@EMPRESA.COM',
        'nombre': 'Jefa',
        'rol': RolUsuario.administrador,
        'permisos': <String, dynamic>{
          'crearCotizaciones': false,
          'verHistorial': false,
          'verIngresos': false,
        },
      });

      expect(usuario.email, 'jefa@empresa.com');
      expect(usuario.esAdministrador, isTrue);
      expect(usuario.puedeCrearCotizaciones, isTrue);
      expect(usuario.puedeVerIngresos, isTrue);
      expect(usuario.puedeGestionarPersonal, isTrue);
    });

    test('el personal respeta los permisos guardados', () {
      final usuario = Usuario.fromMap('u2', <String, dynamic>{
        'email': 'ventas@empresa.com',
        'nombre': 'Vendedor',
        'telefono': '+51 988 777 666',
        'rol': RolUsuario.personal,
        'activo': true,
        'permisos': <String, dynamic>{
          'crearCotizaciones': true,
          'verHistorial': false,
          'gestionarProductos': false,
          'gestionarClientes': true,
          'gestionarReservas': false,
          'verIngresos': true,
        },
      });

      expect(usuario.puedeCrearCotizaciones, isTrue);
      expect(usuario.puedeVerHistorial, isFalse);
      expect(usuario.puedeGestionarClientes, isTrue);
      expect(usuario.puedeVerIngresos, isTrue);
      expect(usuario.puedeGestionarPersonal, isFalse);
      expect(usuario.tieneAccesoAdministracion, isTrue);
      expect(usuario.telefono, '+51 988 777 666');

      final map = usuario.toMap();
      expect(map['email'], 'ventas@empresa.com');
      expect(map['telefono'], '+51 988 777 666');
      expect((map['permisos'] as Map<String, dynamic>)['verIngresos'], isTrue);
    });

    test('los permisos por defecto permiten cotizar y ver historial', () {
      final usuario = Usuario.fromMap('u3', <String, dynamic>{
        'email': 'nuevo@empresa.com',
        'nombre': 'Nuevo',
      });

      expect(usuario.puedeCrearCotizaciones, isTrue);
      expect(usuario.puedeVerHistorial, isTrue);
      expect(usuario.puedeGestionarProductos, isFalse);
      expect(usuario.puedeVerIngresos, isFalse);
      expect(usuario.esAdministrador, isFalse);
    });
  });
}
