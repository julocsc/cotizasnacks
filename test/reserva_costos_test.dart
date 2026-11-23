import 'package:cotizador_app/models/reserva.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reserva', () {
    Reserva reserva() {
      return Reserva(
        id: 'res-1',
        clienteId: 'cli-1',
        clienteNombre: 'Ana Torres',
        fecha: DateTime.utc(2026, 11, 20, 18),
        estado: EstadoReserva.completada,
        costoMovilidad: 50,
        abonoInicial: 25,
        items: const <ReservaItem>[
          ReservaItem(
            descripcion: 'Montaje',
            cantidad: 2,
            precioUnitario: 100,
            costoUnitario: 40,
            tipoCosto: TipoCostoReserva.insumo,
          ),
          ReservaItem(
            descripcion: 'Personal',
            cantidad: 3,
            precioUnitario: 50,
            costoUnitario: 20,
            tipoCosto: TipoCostoReserva.manoObra,
          ),
          ReservaItem(
            descripcion: 'Transporte adicional',
            cantidad: 1,
            precioUnitario: 10,
            costoUnitario: 5,
            tipoCosto: TipoCostoReserva.otros,
          ),
        ],
      );
    }

    test('suma la movilidad al total y calcula el saldo', () {
      final reservaActual = reserva();

      expect(reservaActual.subtotal, 360);
      expect(reservaActual.total, 410);
      expect(reservaActual.saldoPendiente, 385);
      expect(reservaActual.estaCompletada, isTrue);
    });

    test('agrupa los costos de los ítems por categoría', () {
      final reservaActual = reserva();

      expect(reservaActual.costoInsumos, 80);
      expect(reservaActual.costoManoObra, 60);
      expect(reservaActual.costoOtros, 5);
      expect(reservaActual.costoTotal, 145);
      expect(reservaActual.utilidad, 265);
    });

    test('conserva precios y costos al guardar y reconstruir', () {
      final original = reserva();
      final restaurada = Reserva.fromMap('res-1', original.toMap());

      expect(restaurada.items.length, 3);
      expect(restaurada.items.first.precioUnitario, 100);
      expect(restaurada.items.first.costoUnitario, 40);
      expect(restaurada.items[1].tipoCosto, TipoCostoReserva.manoObra);
      expect(restaurada.total, 410);
      expect(restaurada.costoTotal, 145);
    });

    test('calcula el total de una reserva manual con precio y costo', () {
      final manual = Reserva(
        id: 'res-2',
        clienteId: 'cli-1',
        clienteNombre: 'Evento manual',
        fecha: DateTime.utc(2026, 12, 1, 18),
        cantidad: 4,
        precioUnitario: 75,
        costoUnitario: 20,
        tipoCosto: TipoCostoReserva.manoObra,
        costoMovilidad: 30,
        abonoInicial: 100,
      );

      expect(manual.subtotal, 300);
      expect(manual.total, 330);
      expect(manual.saldoPendiente, 230);
      expect(manual.costoManoObra, 80);
      expect(manual.costoTotal, 80);
      expect(manual.utilidad, 250);
    });
  });
}
