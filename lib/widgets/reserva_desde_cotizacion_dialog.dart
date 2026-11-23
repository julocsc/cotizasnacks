import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cotizacion.dart';
import '../models/reserva.dart';
import '../utils/formatters.dart';
import '../utils/num_utils.dart';

/// Datos elegidos por el usuario para convertir una cotización en reservas.
///
/// Los datos del evento (lugar, tipo, invitados y movilidad) ya vienen en la
/// cotización. Aquí solo se definen la fecha, la hora, el abono y el estado.
class ReservaDesdeCotizacionResultado {
  const ReservaDesdeCotizacionResultado({
    required this.fecha,
    required this.estado,
    required this.notas,
    this.abonoInicial = 0,
  });

  final DateTime fecha;
  final String estado;
  final String notas;
  final double abonoInicial;
}

/// Diálogo que prepara las reservas a partir de los ítems de una cotización.
class ReservaDesdeCotizacionDialog extends StatefulWidget {
  const ReservaDesdeCotizacionDialog({super.key, required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  State<ReservaDesdeCotizacionDialog> createState() =>
      _ReservaDesdeCotizacionDialogState();
}

class _ReservaDesdeCotizacionDialogState
    extends State<ReservaDesdeCotizacionDialog> {
  final TextEditingController _notasController = TextEditingController();
  final TextEditingController _abonoInicialController = TextEditingController();

  late DateTime _fecha;
  late TimeOfDay _hora;
  String _estado = EstadoReserva.pendiente;

  @override
  void initState() {
    super.initState();
    _fecha = DateTime.now().add(const Duration(days: 1));
    _hora = TimeOfDay.fromDateTime(_fecha);
  }

  @override
  void dispose() {
    _notasController.dispose();
    _abonoInicialController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Fecha del evento',
    );
    if (seleccionada == null) return;
    setState(() {
      _fecha = DateTime(
        seleccionada.year,
        seleccionada.month,
        seleccionada.day,
        _hora.hour,
        _hora.minute,
      );
    });
  }

  Future<void> _seleccionarHora() async {
    final seleccionada = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: 'Hora de inicio',
    );
    if (seleccionada == null) return;
    setState(() {
      _hora = seleccionada;
      _fecha = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        seleccionada.hour,
        seleccionada.minute,
      );
    });
  }

  void _confirmar() {
    Navigator.of(context).pop(
      ReservaDesdeCotizacionResultado(
        fecha: _fecha,
        estado: _estado,
        notas: _notasController.text.trim(),
        abonoInicial: roundMoney(parseDecimal(_abonoInicialController.text)),
      ),
    );
  }

  Widget _datoEvento(
    ThemeData theme,
    IconData icono,
    String etiqueta,
    String valor,
  ) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cotizacion = widget.cotizacion;
    final cantidad = cotizacion.items.length;

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.event_available_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Convertir en reserva')),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cotizacion.numeroCotizacion,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cotizacion.clienteNombre.isEmpty
                          ? 'Cliente sin nombre'
                          : cotizacion.clienteNombre,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cantidad == 1
                          ? 'Se creará una sola reserva con el ítem cotizado.'
                          : 'Se creará una sola reserva con los $cantidad '
                                'ítems cotizados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ítems de la cotización',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: cotizacion.items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = cotizacion.items[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: scheme.secondaryContainer,
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        item.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${AppFormatters.quantity(item.cantidad)} uds.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarFecha,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(AppFormatters.shortDate(_fecha)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarHora,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_hora.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Datos del evento tomados de la cotización',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _datoEvento(
                      theme,
                      Icons.location_on_outlined,
                      'Lugar',
                      cotizacion.lugar.isEmpty
                          ? 'No registrado'
                          : cotizacion.lugar,
                    ),
                    _datoEvento(
                      theme,
                      Icons.celebration_outlined,
                      'Tipo de evento',
                      cotizacion.tipoEvento.isEmpty
                          ? 'No registrado'
                          : cotizacion.tipoEvento,
                    ),
                    _datoEvento(
                      theme,
                      Icons.groups_outlined,
                      'Invitados',
                      cotizacion.numeroInvitados > 0
                          ? '${cotizacion.numeroInvitados}'
                          : 'No registrado',
                    ),
                    _datoEvento(
                      theme,
                      Icons.local_shipping_outlined,
                      'Costo de movilidad',
                      cotizacion.costoMovilidad > 0
                          ? AppFormatters.money(
                              cotizacion.costoMovilidad,
                              moneda: cotizacion.moneda,
                            )
                          : 'No registrado',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _abonoInicialController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Abono inicial',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  helperText:
                      'Se registrará en la reserva y se incluirá en el aviso '
                      'de WhatsApp.',
                  suffixText: widget.cotizacion.moneda,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _estado,
                decoration: const InputDecoration(
                  labelText: 'Estado inicial',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: EstadoReserva.todos
                    .map(
                      (estado) => DropdownMenuItem<String>(
                        value: estado,
                        child: Text(_capitalizar(estado)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _estado = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notasController,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas para la reserva (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _confirmar,
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Crear reserva'),
        ),
      ],
    );
  }
}

String _capitalizar(String texto) {
  if (texto.isEmpty) return texto;
  return '${texto[0].toUpperCase()}${texto.substring(1)}';
}
