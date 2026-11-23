/// Utilidades para compartir una reserva por WhatsApp y agregarla a Google
/// Calendar sin necesidad de un backend ni de tokens OAuth.
///
/// La app no puede insertar eventos directamente en la agenda de otra persona:
/// Google Calendar requiere autorización OAuth del dueño de cada calendario.
/// Por eso se generan enlaces oficiales:
///
/// - `calendar.google.com/calendar/render` abre el formulario de evento en la
///   cuenta de Google que esté activa en el dispositivo.
/// - `wa.me` abre WhatsApp con el mensaje preparado.
///
/// El mensaje de WhatsApp incluye el enlace del calendario para que el
/// destinatario agregue el evento a su propia agenda con un toque.
library;

import '../core/app_config.dart';
import '../models/reserva.dart';
import 'formatters.dart';

/// Deja solo los dígitos del número, como los espera `wa.me`.
String normalizarTelefonoWhatsApp(String telefono) {
  return telefono.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Indica si el número tiene una longitud internacional razonable.
///
/// Se recomienda guardarlo con código de país, por ejemplo `+51 999 999 999`.
bool telefonoWhatsAppValido(String telefono) {
  final digitos = normalizarTelefonoWhatsApp(telefono);
  return digitos.length >= 8 && digitos.length <= 15;
}

/// Construye el enlace de WhatsApp con el mensaje ya escrito.
Uri crearUriWhatsApp({required String telefono, required String mensaje}) {
  final numero = normalizarTelefonoWhatsApp(telefono);
  return Uri.https('wa.me', '/$numero', <String, String>{'text': mensaje});
}

/// Construye el enlace que abre Google Calendar con el evento preparado.
///
/// Las fechas se envían en UTC para que la hora sea correcta sin depender de
/// la zona horaria configurada en el calendario. El evento dura dos horas por
/// defecto.
Uri crearUriGoogleCalendar(Reserva reserva) {
  final inicio = reserva.fecha.toUtc();
  final fin = inicio.add(const Duration(hours: 2));

  return Uri.https('calendar.google.com', '/calendar/render', <String, String>{
    'action': 'TEMPLATE',
    'text': tituloEventoReserva(reserva),
    'dates': '${_fechaCompacta(inicio)}/${_fechaCompacta(fin)}',
    'details': detalleEventoReserva(reserva),
    if (reserva.lugar.trim().isNotEmpty) 'location': reserva.lugar.trim(),
  });
}

/// Título corto del evento para el calendario.
String tituloEventoReserva(Reserva reserva) {
  final partes = <String>[
    'Reserva',
    if (reserva.clienteNombre.trim().isNotEmpty) reserva.clienteNombre.trim(),
    if (reserva.tipoEvento.trim().isNotEmpty) reserva.tipoEvento.trim(),
  ];
  return partes.join(' · ');
}

/// Detalle completo del evento para Google Calendar y WhatsApp.
String detalleEventoReserva(Reserva reserva) {
  final lineas = <String>[
    'Cliente: ${reserva.clienteNombre}',
    if (reserva.cotizacionNumero.trim().isNotEmpty)
      'Cotización: ${reserva.cotizacionNumero.trim()}',
    if (reserva.tipoEvento.trim().isNotEmpty)
      'Tipo de evento: ${reserva.tipoEvento.trim()}',
    if (reserva.lugar.trim().isNotEmpty) 'Lugar: ${reserva.lugar.trim()}',
    if (reserva.numeroInvitados > 0) 'Invitados: ${reserva.numeroInvitados}',
    'Fecha del evento: ${AppFormatters.date(reserva.fecha)}',
    'Hora de inicio: ${reserva.horaInicio}',
    'Costo de movilidad: '
        '${AppFormatters.money(reserva.costoMovilidad, moneda: reserva.moneda)}',
    'Total de la reserva: '
        '${AppFormatters.money(reserva.total, moneda: reserva.moneda)}',
    'Abono inicial: '
        '${AppFormatters.money(reserva.abonoInicial, moneda: reserva.moneda)}',
    'Saldo pendiente: '
        '${AppFormatters.money(reserva.saldoPendiente, moneda: reserva.moneda)}',
    if (reserva.notas.trim().isNotEmpty) 'Notas: ${reserva.notas.trim()}',
  ];
  return lineas.join('\n');
}

/// Mensaje de WhatsApp con el resumen y el enlace para agendar el evento.
String mensajeReservaWhatsApp({
  required Reserva reserva,
  required String destinatario,
  String nombreEmpresa = AppConfig.nombreEmpresa,
}) {
  final saludo = destinatario.trim().isEmpty
      ? 'Hola,'
      : 'Hola ${destinatario.trim()},';
  final calendario = crearUriGoogleCalendar(reserva).toString();

  return <String>[
    saludo,
    '',
    'Se confirmó una nueva reserva en $nombreEmpresa.',
    '',
    detalleEventoReserva(reserva),
    '',
    'Agrega el evento a tu Google Calendar con este enlace:',
    calendario,
  ].join('\n');
}

String _fechaCompacta(DateTime fecha) {
  String dos(int valor) => valor.toString().padLeft(2, '0');
  return '${fecha.year}${dos(fecha.month)}${dos(fecha.day)}'
      'T${dos(fecha.hour)}${dos(fecha.minute)}${dos(fecha.second)}Z';
}
