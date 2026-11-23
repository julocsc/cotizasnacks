import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/moneda.dart';
import '../models/cliente.dart';
import '../models/cotizacion.dart';
import '../models/empresa_config.dart';
import '../models/item_cotizacion.dart';
import '../models/reserva.dart';
import '../models/usuario.dart';
import '../services/clientes_reservas_service.dart';
import '../services/cotizacion_service.dart';
import '../services/empresa_service.dart';
import '../utils/formatters.dart';
import '../utils/notificaciones_reserva.dart';
import '../widgets/notificacion_reserva_dialog.dart';
import '../widgets/reserva_desde_cotizacion_dialog.dart';
import '../widgets/section_header.dart';
import 'pdf_preview_screen.dart';

/// Detalle completo de una cotización guardada, con acceso al PDF.
class DetalleCotizacionScreen extends StatefulWidget {
  const DetalleCotizacionScreen({
    super.key,
    required this.cotizacion,
    required this.service,
    required this.clientesService,
    this.usuarioActual,
    this.puedeConvertirEnReserva = true,
    this.puedeEliminar = true,
  });

  final Cotizacion cotizacion;
  final CotizacionService service;
  final ClientesReservasService clientesService;

  /// Usuario que está usando la app. Se usa como respaldo cuando la cotización
  /// no guardó los datos de su creador.
  final Usuario? usuarioActual;
  final bool puedeConvertirEnReserva;
  final bool puedeEliminar;

  @override
  State<DetalleCotizacionScreen> createState() =>
      _DetalleCotizacionScreenState();
}

class _DetalleCotizacionScreenState extends State<DetalleCotizacionScreen> {
  final EmpresaService _empresaService = EmpresaService();
  late final Future<EmpresaConfig> _empresaConfig;
  bool _eliminando = false;
  bool _convirtiendo = false;

  bool get _tieneDatosEvento {
    final cotizacion = widget.cotizacion;
    return cotizacion.lugar.isNotEmpty ||
        cotizacion.tipoEvento.isNotEmpty ||
        cotizacion.numeroInvitados > 0 ||
        cotizacion.costoMovilidad > 0;
  }

  @override
  void initState() {
    super.initState();
    _empresaConfig = _empresaService.obtenerConfiguracion();
  }

  void _abrirPdf() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PdfPreviewScreen(cotizacion: widget.cotizacion),
      ),
    );
  }

  Future<void> _convertirEnReserva() async {
    if (_convirtiendo) return;
    final cotizacion = widget.cotizacion;

    if (cotizacion.items.isEmpty) {
      _mensaje(
        'La cotización no tiene ítems para convertirlos en reserva.',
        error: true,
      );
      return;
    }

    if (cotizacion.estado == Cotizacion.estadoReservada) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cotización ya reservada'),
          content: const Text(
            'Esta cotización ya fue convertida en una reserva anteriormente. '
            '¿Deseas crear una reserva nueva con los mismos ítems?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Crear de nuevo'),
            ),
          ],
        ),
      );
      if (continuar != true || !mounted) return;
    }

    final resultado = await showDialog<ReservaDesdeCotizacionResultado>(
      context: context,
      builder: (dialogContext) =>
          ReservaDesdeCotizacionDialog(cotizacion: cotizacion),
    );
    if (resultado == null || !mounted) return;

    setState(() => _convirtiendo = true);

    try {
      final clienteId = await widget.clientesService.asegurarCliente(
        Cliente(
          nombre: cotizacion.clienteNombre,
          telefono: cotizacion.clienteTelefono,
          email: cotizacion.clienteEmail,
          notas:
              'Cliente registrado desde la cotización '
              '${cotizacion.numeroCotizacion}.',
        ),
      );

      final items = cotizacion.items
          .map(
            (item) => ReservaItem(
              descripcion: item.descripcion,
              productoId: item.productoId ?? '',
              cantidad: item.cantidad,
              precioUnitario: item.precioUnitario,
            ),
          )
          .toList(growable: false);
      final cantidadTotal = items.fold<double>(
        0,
        (total, item) => total + item.cantidad,
      );

      final usuario = widget.usuarioActual;
      final reserva = Reserva(
        clienteId: clienteId,
        clienteNombre: cotizacion.clienteNombre,
        productoId: items.length == 1 ? items.first.productoId : '',
        productoNombre: items.length == 1
            ? items.first.descripcion
            : '${items.length} ítems reservados',
        fecha: resultado.fecha,
        cantidad: cantidadTotal,
        estado: resultado.estado,
        notas: resultado.notas,
        cotizacionId: cotizacion.id ?? '',
        cotizacionNumero: cotizacion.numeroCotizacion,
        items: items,
        lugar: cotizacion.lugar,
        tipoEvento: cotizacion.tipoEvento,
        numeroInvitados: cotizacion.numeroInvitados,
        costoMovilidad: cotizacion.costoMovilidad,
        abonoInicial: resultado.abonoInicial,
        moneda: cotizacion.moneda,
        creadoPorUid: cotizacion.creadoPorUid.isNotEmpty
            ? cotizacion.creadoPorUid
            : (usuario?.uid ?? ''),
        creadoPorNombre: cotizacion.creadoPorNombre.isNotEmpty
            ? cotizacion.creadoPorNombre
            : (usuario?.nombreVisible ?? ''),
        creadoPorEmail: cotizacion.creadoPorEmail.isNotEmpty
            ? cotizacion.creadoPorEmail
            : (usuario?.email ?? ''),
        creadoPorTelefono: cotizacion.creadoPorTelefono.isNotEmpty
            ? cotizacion.creadoPorTelefono
            : (usuario?.telefono ?? ''),
      );

      await widget.clientesService.agregarReserva(reserva);

      final id = cotizacion.id;
      if (id != null) {
        try {
          await widget.service.actualizarEstado(id, Cotizacion.estadoReservada);
        } catch (_) {
          // La reserva ya se creó; el estado es informativo.
        }
      }

      if (!mounted) return;
      try {
        await _mostrarNotificacionReserva(reserva);
      } catch (_) {
        // La reserva ya se guardó; el aviso es un paso adicional.
      }
      if (!mounted) return;
      _mensaje(
        'Se creó una reserva con ${items.length} '
        '${items.length == 1 ? 'ítem' : 'ítems'} desde la cotización.',
      );
    } catch (error) {
      if (!mounted) return;
      _mensaje(
        'No se pudo crear la reserva. Revisa la conexión y las reglas '
        'de Firestore.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _convirtiendo = false);
    }
  }

  /// Abre el diálogo para agendar la reserva y avisar al administrador y al
  /// creador de la cotización.
  Future<void> _mostrarNotificacionReserva(Reserva reserva) async {
    EmpresaConfig config;
    try {
      config = await _empresaConfig;
    } catch (_) {
      config = const EmpresaConfig();
    }
    if (!mounted) return;

    final telefonoAdministrador = config.whatsappAdministrador;
    final telefonoCreador = reserva.creadoPorTelefono;
    final mismoTelefono =
        normalizarTelefonoWhatsApp(telefonoCreador).isNotEmpty &&
        normalizarTelefonoWhatsApp(telefonoCreador) ==
            normalizarTelefonoWhatsApp(telefonoAdministrador);

    final destinatarios = <DestinatarioReserva>[
      DestinatarioReserva(
        rol: 'Administrador',
        nombre: 'Administrador',
        telefono: telefonoAdministrador,
      ),
      if (!mismoTelefono)
        DestinatarioReserva(
          rol: 'Creador de la cotización',
          nombre: reserva.nombreCreador.isEmpty
              ? 'Sin nombre registrado'
              : reserva.nombreCreador,
          telefono: telefonoCreador,
        ),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => NotificacionReservaDialog(
        reserva: reserva,
        destinatarios: destinatarios,
      ),
    );
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            texto,
            style: error ? TextStyle(color: scheme.onError) : null,
          ),
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  Future<void> _confirmarEliminar() async {
    final id = widget.cotizacion.id;
    if (id == null || _eliminando) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta cotización?'),
        content: Text(
          'Se eliminará permanentemente la cotización '
          '${widget.cotizacion.numeroCotizacion} de Firestore.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _eliminando = true);

    try {
      await widget.service.eliminar(id);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Cotización eliminada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar la cotización: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cotizacion = widget.cotizacion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de cotización'),
        actions: <Widget>[
          if (widget.puedeConvertirEnReserva)
            IconButton(
              tooltip: 'Convertir en reserva',
              onPressed: _convirtiendo ? null : _convertirEnReserva,
              icon: const Icon(Icons.event_available_outlined),
            ),
          IconButton(
            tooltip: 'Abrir PDF',
            onPressed: _abrirPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          if (widget.puedeEliminar)
            if (_eliminando)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: 'Eliminar cotización',
                onPressed: cotizacion.id == null ? null : _confirmarEliminar,
                icon: const Icon(Icons.delete_outline),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 1200
                ? 32.0
                : constraints.maxWidth >= 700
                ? 24.0
                : 16.0;
            final dosColumnas = constraints.maxWidth >= 980;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _encabezado(context),
                      const SizedBox(height: 20),
                      _tarjetaCliente(context),
                      if (_tieneDatosEvento) ...<Widget>[
                        const SizedBox(height: 20),
                        _tarjetaEvento(context),
                      ],
                      if (cotizacion.notas.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 20),
                        _tarjetaNotas(context),
                      ],
                      const SizedBox(height: 20),
                      if (dosColumnas)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 3, child: _tarjetaItems(context)),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 340,
                              child: _tarjetaTotales(context),
                            ),
                          ],
                        )
                      else ...<Widget>[
                        _tarjetaItems(context),
                        const SizedBox(height: 20),
                        _tarjetaTotales(context),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cotizacion = widget.cotizacion;

    final identidad = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cotizacion.estado.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              cotizacion.moneda,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(cotizacion.numeroCotizacion, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(
          'Emitida el ${AppFormatters.dateTime(cotizacion.fecha)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'TOTAL',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppFormatters.money(cotizacion.total, moneda: cotizacion.moneda),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${cotizacion.cantidadItems} ítem(s)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 560) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: identidad),
                  const SizedBox(width: 24),
                  total,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identidad,
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerLeft, child: total),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tarjetaCliente(BuildContext context) {
    final cotizacion = widget.cotizacion;
    final moneda = Moneda.desdeCodigo(cotizacion.moneda);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.person_outline,
              title: 'Información del cliente',
              subtitle: 'Datos de contacto y condiciones de la cotización.',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final contacto = Column(
                  children: <Widget>[
                    _DatoDetalle(
                      icon: Icons.badge_outlined,
                      etiqueta: 'Nombre',
                      valor: cotizacion.clienteNombre.isEmpty
                          ? 'No registrado'
                          : cotizacion.clienteNombre,
                    ),
                    const SizedBox(height: 14),
                    _DatoDetalle(
                      icon: Icons.phone_outlined,
                      etiqueta: 'Teléfono',
                      valor: cotizacion.clienteTelefono.isEmpty
                          ? 'No registrado'
                          : cotizacion.clienteTelefono,
                    ),
                    const SizedBox(height: 14),
                    _DatoDetalle(
                      icon: Icons.alternate_email,
                      etiqueta: 'Email',
                      valor: cotizacion.clienteEmail.isEmpty
                          ? 'No registrado'
                          : cotizacion.clienteEmail,
                    ),
                  ],
                );

                final detalles = Column(
                  children: <Widget>[
                    _DatoDetalle(
                      icon: Icons.calendar_today_outlined,
                      etiqueta: 'Fecha de emisión',
                      valor: AppFormatters.date(cotizacion.fecha),
                    ),
                    const SizedBox(height: 14),
                    _DatoDetalle(
                      icon: Icons.payments_outlined,
                      etiqueta: 'Moneda',
                      valor: moneda.nombreConCodigo,
                    ),
                    const SizedBox(height: 14),
                    _DatoDetalle(
                      icon: Icons.receipt_long_outlined,
                      etiqueta: 'Ítems',
                      valor: '${cotizacion.cantidadItems}',
                    ),
                  ],
                );

                if (constraints.maxWidth >= 640) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: contacto),
                      const SizedBox(width: 30),
                      Expanded(child: detalles),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    contacto,
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    detalles,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEvento(BuildContext context) {
    final cotizacion = widget.cotizacion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.celebration_outlined,
              title: 'Datos del evento',
              subtitle:
                  'Estos datos se copiarán a la reserva cuando la cotización '
                  'se confirme.',
            ),
            const SizedBox(height: 20),
            _DatoDetalle(
              icon: Icons.location_on_outlined,
              etiqueta: 'Lugar',
              valor: cotizacion.lugar.isEmpty
                  ? 'No registrado'
                  : cotizacion.lugar,
            ),
            const SizedBox(height: 14),
            _DatoDetalle(
              icon: Icons.celebration_outlined,
              etiqueta: 'Tipo de evento',
              valor: cotizacion.tipoEvento.isEmpty
                  ? 'No registrado'
                  : cotizacion.tipoEvento,
            ),
            const SizedBox(height: 14),
            _DatoDetalle(
              icon: Icons.groups_outlined,
              etiqueta: 'Número de invitados',
              valor: cotizacion.numeroInvitados > 0
                  ? '${cotizacion.numeroInvitados}'
                  : 'No registrado',
            ),
            const SizedBox(height: 14),
            _DatoDetalle(
              icon: Icons.local_shipping_outlined,
              etiqueta: 'Costo de movilidad',
              valor: cotizacion.costoMovilidad > 0
                  ? AppFormatters.money(
                      cotizacion.costoMovilidad,
                      moneda: cotizacion.moneda,
                    )
                  : 'No registrado',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaNotas(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.notes_outlined,
              title: 'Notas y condiciones',
              subtitle: 'Información adicional incluida en el PDF.',
            ),
            const SizedBox(height: 16),
            Text(widget.cotizacion.notas, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaItems(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              icon: Icons.inventory_2_outlined,
              title: 'Productos y servicios',
              subtitle:
                  '${widget.cotizacion.cantidadItems} línea(s) cotizada(s).',
            ),
            const SizedBox(height: 18),
            if (widget.cotizacion.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Esta cotización no tiene ítems.'),
              )
            else
              _TablaItems(
                items: widget.cotizacion.items,
                moneda: widget.cotizacion.moneda,
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaTotales(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cotizacion = widget.cotizacion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.calculate_outlined,
              title: 'Totales',
            ),
            const SizedBox(height: 18),
            _MontoDetalle(
              etiqueta: 'Subtotal',
              valor: AppFormatters.money(
                cotizacion.subtotal,
                moneda: cotizacion.moneda,
              ),
            ),
            if (cotizacion.aplicarImpuesto) ...<Widget>[
              const SizedBox(height: 10),
              _MontoDetalle(
                etiqueta:
                    '${AppConfig.nombreImpuesto} '
                    '(${AppFormatters.percentage(cotizacion.porcentajeImpuesto)})',
                valor: AppFormatters.money(
                  cotizacion.impuesto,
                  moneda: cotizacion.moneda,
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '${AppConfig.nombreImpuesto} no aplicado',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _MontoDetalle(
              etiqueta: 'Costo de movilidad',
              valor: AppFormatters.money(
                cotizacion.costoMovilidad,
                moneda: cotizacion.moneda,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Total',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  AppFormatters.money(
                    cotizacion.total,
                    moneda: cotizacion.moneda,
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _abrirPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Ver y compartir PDF'),
            ),
            const SizedBox(height: 10),
            if (widget.puedeConvertirEnReserva) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _convirtiendo ? null : _convertirEnReserva,
                icon: _convirtiendo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available_outlined),
                label: Text(
                  _convirtiendo ? 'Creando reserva...' : 'Convertir en reserva',
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'PDF generado con los datos guardados en Firestore. '
              'Puedes descargarlo o compartirlo desde la vista previa.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (widget.puedeConvertirEnReserva) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'También puedes convertir esta cotización en una sola reserva '
                'con todos sus ítems. El cliente queda registrado en el panel '
                'de administración.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            FutureBuilder<EmpresaConfig>(
              future: _empresaConfig,
              builder: (context, snapshot) {
                final nombre = snapshot.data?.nombre ?? AppConfig.nombreEmpresa;
                return Text(
                  '$nombre · ${cotizacion.moneda}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DatoDetalle extends StatelessWidget {
  const _DatoDetalle({
    required this.icon,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icon;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                etiqueta,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(valor, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _MontoDetalle extends StatelessWidget {
  const _MontoDetalle({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            etiqueta,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          valor,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TablaItems extends StatelessWidget {
  const _TablaItems({required this.items, required this.moneda});

  final List<ItemCotizacion> items;
  final String moneda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 570) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Descripción',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Cant.',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'P. unit.',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Importe',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              for (var index = 0; index < items.length; index++) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 5,
                        child: Text(
                          items[index].descripcion,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          AppFormatters.quantity(items[index].cantidad),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          AppFormatters.money(
                            items[index].precioUnitario,
                            moneda: moneda,
                          ),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          AppFormatters.money(
                            items[index].total,
                            moneda: moneda,
                          ),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < items.length - 1) const Divider(),
              ],
            ],
          );
        }

        return Column(
          children: <Widget>[
            for (var index = 0; index < items.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    items[index].descripcion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${AppFormatters.quantity(items[index].cantidad)}'
                          ' × ${AppFormatters.money(items[index].precioUnitario, moneda: moneda)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        AppFormatters.money(items[index].total, moneda: moneda),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
