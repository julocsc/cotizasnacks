import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reserva.dart';
import '../utils/formatters.dart';
import '../utils/notificaciones_reserva.dart';

/// Persona que debe recibir el aviso de una reserva.
class DestinatarioReserva {
  const DestinatarioReserva({
    required this.rol,
    required this.nombre,
    required this.telefono,
  });

  /// Etiqueta visible: `Administrador`, `Creador de la cotización`, etc.
  final String rol;
  final String nombre;
  final String telefono;

  bool get tieneTelefono => telefonoWhatsAppValido(telefono);
}

/// Diálogo que permite agendar una reserva en Google Calendar y avisar por
/// WhatsApp al administrador y al creador de la cotización.
///
/// No se insertan eventos de forma automática en calendarios ajenos porque
/// Google Calendar exige autorización OAuth del dueño de cada agenda. En su
/// lugar se abren los enlaces oficiales de Calendar y WhatsApp; el mensaje de
/// WhatsApp incluye el enlace para que cada destinatario agregue el evento a
/// su propia agenda.
class NotificacionReservaDialog extends StatelessWidget {
  const NotificacionReservaDialog({
    super.key,
    required this.reserva,
    required this.destinatarios,
  });

  final Reserva reserva;
  final List<DestinatarioReserva> destinatarios;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final calendario = crearUriGoogleCalendar(reserva);

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.event_note_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Agendar y notificar')),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tituloEventoReserva(reserva),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _dato(
                      theme,
                      Icons.calendar_today_outlined,
                      'Fecha del evento',
                      AppFormatters.date(reserva.fecha),
                    ),
                    _dato(
                      theme,
                      Icons.schedule_outlined,
                      'Hora de inicio',
                      reserva.horaInicio,
                    ),
                    if (reserva.lugar.trim().isNotEmpty)
                      _dato(
                        theme,
                        Icons.location_on_outlined,
                        'Lugar',
                        reserva.lugar,
                      ),
                    if (reserva.tipoEvento.trim().isNotEmpty)
                      _dato(
                        theme,
                        Icons.celebration_outlined,
                        'Tipo de evento',
                        reserva.tipoEvento,
                      ),
                    if (reserva.numeroInvitados > 0)
                      _dato(
                        theme,
                        Icons.groups_outlined,
                        'Invitados',
                        '${reserva.numeroInvitados}',
                      ),
                    _dato(
                      theme,
                      Icons.payments_outlined,
                      'Abono inicial',
                      AppFormatters.money(
                        reserva.abonoInicial,
                        moneda: reserva.moneda,
                      ),
                    ),
                    _dato(
                      theme,
                      Icons.local_shipping_outlined,
                      'Costo de movilidad',
                      AppFormatters.money(
                        reserva.costoMovilidad,
                        moneda: reserva.moneda,
                      ),
                    ),
                    _dato(
                      theme,
                      Icons.account_balance_wallet_outlined,
                      'Total de la reserva',
                      AppFormatters.money(
                        reserva.total,
                        moneda: reserva.moneda,
                      ),
                    ),
                    _dato(
                      theme,
                      Icons.price_check_outlined,
                      'Saldo pendiente',
                      AppFormatters.money(
                        reserva.saldoPendiente,
                        moneda: reserva.moneda,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Destinatarios',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final destinatario in destinatarios) ...<Widget>[
                _TarjetaDestinatario(
                  reserva: reserva,
                  destinatario: destinatario,
                  calendario: calendario,
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Calendar se abre con la cuenta de Google del '
                        'dispositivo. El mensaje de WhatsApp incluye el enlace '
                        'del evento para que cada persona lo agregue a su '
                        'propia agenda.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => _copiarResumen(context),
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar resumen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _dato(ThemeData theme, IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$etiqueta: ',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  TextSpan(text: valor),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarResumen(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(
        text: <String>[
          tituloEventoReserva(reserva),
          '',
          detalleEventoReserva(reserva),
          '',
          'Google Calendar: ${crearUriGoogleCalendar(reserva)}',
        ].join('\n'),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen de la reserva copiado.')),
    );
  }
}

class _TarjetaDestinatario extends StatelessWidget {
  const _TarjetaDestinatario({
    required this.reserva,
    required this.destinatario,
    required this.calendario,
  });

  final Reserva reserva;
  final DestinatarioReserva destinatario;
  final Uri calendario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final telefono = destinatario.telefono.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 17,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  destinatario.rol.toLowerCase().contains('admin')
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                  size: 19,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      destinatario.rol,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      destinatario.nombre.trim().isEmpty
                          ? 'Sin nombre registrado'
                          : destinatario.nombre.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Icons.phone_outlined,
                size: 15,
                color: destinatario.tieneTelefono
                    ? scheme.onSurfaceVariant
                    : scheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destinatario.tieneTelefono
                      ? telefono
                      : 'Sin celular con código de país registrado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: destinatario.tieneTelefono
                        ? scheme.onSurfaceVariant
                        : scheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              FilledButton.icon(
                onPressed: destinatario.tieneTelefono
                    ? () => _abrirWhatsApp(context)
                    : null,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Enviar WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: () => _abrirCalendario(context),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Abrir Google Calendar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirWhatsApp(BuildContext context) async {
    final uri = crearUriWhatsApp(
      telefono: destinatario.telefono,
      mensaje: mensajeReservaWhatsApp(
        reserva: reserva,
        destinatario: destinatario.nombre,
      ),
    );
    await _abrir(context, uri, 'No se pudo abrir WhatsApp.');
  }

  Future<void> _abrirCalendario(BuildContext context) async {
    await _abrir(context, calendario, 'No se pudo abrir Google Calendar.');
  }

  Future<void> _abrir(
    BuildContext context,
    Uri uri,
    String mensajeError,
  ) async {
    var abierto = false;
    try {
      abierto = await launchUrl(uri);
    } catch (_) {
      abierto = false;
    }
    if (!context.mounted) return;
    if (!abierto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$mensajeError Copia el enlace manualmente.')),
      );
    }
  }
}
