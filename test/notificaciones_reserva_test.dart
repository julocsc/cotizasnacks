import 'package:cotizador_app/core/app_config.dart';
import 'package:cotizador_app/models/reserva.dart';
import 'package:cotizador_app/utils/notificaciones_reserva.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting(AppConfig.locale);
  });

  Reserva reserva() {
    return Reserva(
      clienteId: 'c1',
      clienteNombre: 'María López',
      fecha: DateTime.utc(2026, 11, 20, 15),
      cotizacionNumero: 'COT-20261120-001',
      lugar: 'Salón Real',
      tipoEvento: 'Boda',
      numeroInvitados: 120,
      costoMovilidad: 150,
      abonoInicial: 500,
      notas: 'Ingreso por la puerta principal.',
    );
  }

  group('Notificaciones de reserva', () {
    test('normaliza y valida teléfonos con código de país', () {
      expect(normalizarTelefonoWhatsApp('+51 999 111 222'), '51999111222');
      expect(telefonoWhatsAppValido('+51 999 111 222'), isTrue);
      expect(telefonoWhatsAppValido('123'), isFalse);
    });

    test('construye el enlace de WhatsApp con el mensaje', () {
      final uri = crearUriWhatsApp(
        telefono: '+51 999 111 222',
        mensaje: 'Hola, revisa la reserva.',
      );

      expect(uri.host, 'wa.me');
      expect(uri.path, '/51999111222');
      expect(uri.queryParameters['text'], 'Hola, revisa la reserva.');
    });

    test('construye el evento de Google Calendar con los datos', () {
      final uri = crearUriGoogleCalendar(reserva());

      expect(uri.host, 'calendar.google.com');
      expect(uri.queryParameters['action'], 'TEMPLATE');
      expect(uri.queryParameters['dates'], '20261120T150000Z/20261120T170000Z');
      expect(uri.queryParameters['location'], 'Salón Real');
      expect(uri.queryParameters['text'], contains('Boda'));
      expect(uri.queryParameters['details'], contains('Abono inicial'));
      expect(uri.queryParameters['details'], contains('120'));
    });

    test('el mensaje de WhatsApp incluye el enlace del calendario', () {
      final mensaje = mensajeReservaWhatsApp(
        reserva: reserva(),
        destinatario: 'Administrador',
      );

      expect(mensaje, contains('Hola Administrador,'));
      expect(mensaje, contains('María López'));
      expect(mensaje, contains('calendar.google.com'));
      expect(mensaje, contains('Abono inicial'));
    });
  });
}
