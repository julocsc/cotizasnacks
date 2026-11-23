import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../models/cliente.dart';
import '../../models/empresa_config.dart';
import '../../models/producto.dart';
import '../../models/reserva.dart';
import '../../models/usuario.dart';
import '../../services/catalogo_service.dart';
import '../../services/clientes_reservas_service.dart';
import '../../services/empresa_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/formatters.dart';
import '../../utils/notificaciones_reserva.dart';
import '../../utils/num_utils.dart';
import '../../widgets/notificacion_reserva_dialog.dart';
import '../pdf_preview_screen.dart';
import 'admin_empty_state.dart';

/// Pestaña de administración de reservas.
class ReservasAdminTab extends StatefulWidget {
  const ReservasAdminTab({
    super.key,
    required this.clientesService,
    required this.catalogoService,
    required this.empresaService,
    required this.usuarioActual,
  });

  final ClientesReservasService clientesService;
  final CatalogoService catalogoService;
  final EmpresaService empresaService;
  final Usuario usuarioActual;

  @override
  State<ReservasAdminTab> createState() => _ReservasAdminTabState();
}

class _ReservasAdminTabState extends State<ReservasAdminTab> {
  late Stream<List<Cliente>> _clientesStream;
  late Stream<List<Producto>> _productosStream;
  late Stream<List<Reserva>> _reservasStream;

  String _busqueda = '';
  String? _estadoFiltro;

  @override
  void initState() {
    super.initState();
    _clientesStream = widget.clientesService.escucharClientes();
    _productosStream = widget.catalogoService.escucharProductos();
    _reservasStream = widget.clientesService.escucharReservas();
  }

  void _recargar() {
    setState(() {
      _clientesStream = widget.clientesService.escucharClientes();
      _productosStream = widget.catalogoService.escucharProductos();
      _reservasStream = widget.clientesService.escucharReservas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesStream,
      builder: (context, clientesSnapshot) {
        final clientes = clientesSnapshot.data ?? const <Cliente>[];

        return StreamBuilder<List<Producto>>(
          stream: _productosStream,
          builder: (context, productosSnapshot) {
            final productos = productosSnapshot.data ?? const <Producto>[];

            return StreamBuilder<List<Reserva>>(
              stream: _reservasStream,
              builder: (context, reservasSnapshot) {
                final reservas = reservasSnapshot.data ?? const <Reserva>[];
                final cargando =
                    clientesSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    reservasSnapshot.connectionState == ConnectionState.waiting;
                final error =
                    clientesSnapshot.hasError ||
                    productosSnapshot.hasError ||
                    reservasSnapshot.hasError;

                final consulta = _busqueda.trim().toLowerCase();
                final filtradas = reservas
                    .where((reserva) {
                      final coincideEstado =
                          _estadoFiltro == null ||
                          reserva.estado == _estadoFiltro;
                      final texto =
                          '${reserva.clienteNombre} ${reserva.productoNombre} '
                                  '${reserva.notas} '
                                  '${reserva.cotizacionNumero} '
                                  '${reserva.items.map((item) => item.descripcion).join(' ')}'
                              .toLowerCase();
                      return coincideEstado &&
                          (consulta.isEmpty || texto.contains(consulta));
                    })
                    .toList(growable: false);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _barraFiltros(context, clientes, productos),
                      const SizedBox(height: 14),
                      Expanded(
                        child: error
                            ? AdminErrorState(
                                mensaje:
                                    'Revisa la conexión y las reglas de '
                                    'Firestore para las reservas.',
                                onReintentar: _recargar,
                              )
                            : cargando
                            ? const Center(child: CircularProgressIndicator())
                            : _lista(context, reservas, filtradas),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _barraFiltros(
    BuildContext context,
    List<Cliente> clientes,
    List<Producto> productos,
  ) {
    final buscador = TextField(
      decoration: const InputDecoration(
        labelText: 'Buscar reserva',
        hintText: 'Cliente, producto o nota',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() => _busqueda = value),
    );

    final filtroEstado = InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Estado',
        prefixIcon: Icon(Icons.filter_alt_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _estadoFiltro,
          isExpanded: true,
          onChanged: (value) => setState(() => _estadoFiltro = value),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos los estados'),
            ),
            ...EstadoReserva.todos.map(
              (estado) => DropdownMenuItem<String?>(
                value: estado,
                child: Text(_capitalizar(estado)),
              ),
            ),
          ],
        ),
      ),
    );

    final boton = FilledButton.icon(
      onPressed: () => _abrirReserva(context, clientes, productos),
      icon: const Icon(Icons.event_available_outlined),
      label: const Text('Nueva reserva'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860) {
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: buscador),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: filtroEstado),
              const SizedBox(width: 12),
              boton,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buscador,
            const SizedBox(height: 10),
            filtroEstado,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: boton),
          ],
        );
      },
    );
  }

  Widget _lista(
    BuildContext context,
    List<Reserva> reservas,
    List<Reserva> filtradas,
  ) {
    if (reservas.isEmpty) {
      return AdminEmptyState(
        icon: Icons.event_available_outlined,
        titulo: 'Aún no hay reservas',
        mensaje:
            'Crea una reserva manualmente o abre una cotización del historial '
            'y usa "Convertir en reserva".',
        accionEtiqueta: 'Crear reserva',
        onAccion: () async {
          final clientes = await widget.clientesService
              .escucharClientes()
              .first;
          final productos = await widget.catalogoService
              .escucharProductos()
              .first;
          if (!mounted) return;
          _abrirReserva(this.context, clientes, productos);
        },
      );
    }

    if (filtradas.isEmpty) {
      return AdminEmptyState(
        icon: Icons.search_off,
        titulo: 'Sin resultados',
        mensaje: 'No hay reservas que coincidan con el filtro actual.',
        accionEtiqueta: 'Limpiar filtros',
        onAccion: () {
          setState(() {
            _busqueda = '';
            _estadoFiltro = null;
          });
        },
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filtradas.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final reserva = filtradas[index];
        return _ReservaCard(
          reserva: reserva,
          onVerDetalle: () => _verDetalle(reserva),
          onEditar: () => _editarReserva(reserva),
          onCambiarEstado: (estado) => _cambiarEstado(reserva, estado),
          onEliminar: () => _eliminarReserva(reserva),
          onBoleta: () => _abrirBoleta(reserva),
        );
      },
    );
  }

  Future<void> _editarReserva(Reserva reserva) async {
    final clientes = await widget.clientesService.escucharClientes().first;
    final productos = await widget.catalogoService.escucharProductos().first;
    if (!mounted) return;
    _abrirReserva(context, clientes, productos, reserva: reserva);
  }

  Future<void> _verDetalle(Reserva reserva) async {
    final accion = await showDialog<_AccionDetalleReserva>(
      context: context,
      builder: (dialogContext) => _ReservaDetalleDialog(reserva: reserva),
    );
    if (!mounted || accion == null) return;
    if (accion == _AccionDetalleReserva.editar) {
      await _editarReserva(reserva);
    } else if (accion == _AccionDetalleReserva.notificar) {
      await _notificarReserva(reserva);
    } else if (accion == _AccionDetalleReserva.boleta) {
      await _abrirBoleta(reserva);
    }
  }

  Future<void> _notificarReserva(Reserva reserva) async {
    EmpresaConfig config;
    try {
      config = await widget.empresaService.obtenerConfiguracion();
    } catch (_) {
      config = const EmpresaConfig();
    }
    if (!mounted) return;

    final telefonoAdministrador = config.whatsappAdministrador;
    final telefonoCreador = reserva.creadoPorTelefono.isNotEmpty
        ? reserva.creadoPorTelefono
        : widget.usuarioActual.telefono;
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
              ? widget.usuarioActual.nombreVisible
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

  Future<void> _abrirReserva(
    BuildContext context,
    List<Cliente> clientes,
    List<Producto> productos, {
    Reserva? reserva,
  }) async {
    if (clientes.isEmpty) {
      _mensaje(
        'Primero registra un cliente para poder crear reservas.',
        error: true,
      );
      return;
    }

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ReservaFormDialog(
        service: widget.clientesService,
        clientes: clientes,
        productos: productos,
        usuarioActual: widget.usuarioActual,
        reserva: reserva,
      ),
    );

    if (guardado == true && mounted) {
      _mensaje(reserva == null ? 'Reserva creada.' : 'Reserva actualizada.');
    }
  }

  Future<void> _cambiarEstado(Reserva reserva, String estado) async {
    if (reserva.id == null) return;
    try {
      await widget.clientesService.actualizarEstadoReserva(reserva.id!, estado);
      if (mounted) _mensaje('Estado actualizado a ${_capitalizar(estado)}.');
    } catch (error) {
      if (mounted) _mensaje('No se pudo actualizar el estado.', error: true);
    }
  }

  Future<void> _abrirBoleta(Reserva reserva) async {
    if (!reserva.estaCompletada) {
      _mensaje(
        'Marca la reserva como completada para generar la boleta.',
        error: true,
      );
      return;
    }

    EmpresaConfig config;
    try {
      config = await widget.empresaService.obtenerConfiguracion();
    } catch (_) {
      config = const EmpresaConfig();
    }
    if (!mounted) return;

    final numero = PdfService.numeroBoleta(reserva);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DocumentoPdfScreen(
          titulo: 'Boleta · $numero',
          nombreArchivo:
              'boleta_${numero.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf',
          generar: () => PdfService().generarBoleta(reserva, empresa: config),
        ),
      ),
    );
  }

  Future<void> _eliminarReserva(Reserva reserva) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar reserva?'),
        content: Text('Se eliminará la reserva de "${reserva.clienteNombre}".'),
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

    try {
      await widget.clientesService.eliminarReserva(reserva.id!);
      if (mounted) _mensaje('Reserva eliminada.');
    } catch (error) {
      if (mounted) _mensaje('No se pudo eliminar la reserva.', error: true);
    }
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
}

class _ReservaCard extends StatelessWidget {
  const _ReservaCard({
    required this.reserva,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onCambiarEstado,
    required this.onEliminar,
    required this.onBoleta,
  });

  final Reserva reserva;
  final VoidCallback onVerDetalle;
  final VoidCallback onEditar;
  final ValueChanged<String> onCambiarEstado;
  final VoidCallback onEliminar;
  final VoidCallback onBoleta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estadoColor = _colorEstado(scheme, reserva.estado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    '${reserva.fecha.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _mesCorto(reserva.fecha),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        reserva.clienteNombre,
                        style: theme.textTheme.titleMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _capitalizar(reserva.estado),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: estadoColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppFormatters.dateTime(reserva.fecha)}'
                    '${reserva.items.isNotEmpty
                        ? ' · ${reserva.items.length} ítem(s) · ${AppFormatters.quantity(reserva.cantidadTotal)} uds.'
                        : reserva.cantidad > 0
                        ? ' · ${AppFormatters.quantity(reserva.cantidad)} uds.'
                        : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (reserva.items.isEmpty &&
                      reserva.productoNombre.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      'Producto: ${reserva.productoNombre}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ] else if (reserva.items.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      reserva.items.length == 1
                          ? 'Producto: ${reserva.items.first.descripcion}'
                          : 'Productos: ${reserva.items.take(2).map((item) => item.descripcion).join(', ')}'
                                '${reserva.items.length > 2 ? ' +${reserva.items.length - 2}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (reserva.cotizacionNumero.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Cotización: ${reserva.cotizacionNumero}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    'Total: ${AppFormatters.money(reserva.total, moneda: reserva.moneda)}'
                    '${reserva.costoMovilidad > 0 ? ' · Movilidad: ${AppFormatters.money(reserva.costoMovilidad, moneda: reserva.moneda)}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (reserva.notas.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      reserva.notas,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: onVerDetalle,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Ver detalle'),
                      ),
                      if (reserva.estaCompletada)
                        TextButton.icon(
                          onPressed: onBoleta,
                          icon: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          label: const Text('Boleta'),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'Cambiar estado',
                        onSelected: onCambiarEstado,
                        itemBuilder: (context) => EstadoReserva.todos
                            .map(
                              (estado) => PopupMenuItem<String>(
                                value: estado,
                                child: Text(_capitalizar(estado)),
                              ),
                            )
                            .toList(growable: false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.sync_alt, size: 18),
                              const SizedBox(width: 4),
                              Text('Estado', style: theme.textTheme.labelLarge),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar reserva',
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Eliminar reserva',
                        onPressed: onEliminar,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: scheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorEstado(ColorScheme scheme, String estado) {
    switch (estado) {
      case EstadoReserva.confirmada:
        return scheme.primary;
      case EstadoReserva.completada:
        return scheme.tertiary;
      case EstadoReserva.cancelada:
        return scheme.error;
      default:
        return scheme.secondary;
    }
  }
}

/// Formulario para crear o editar una reserva.
class ReservaFormDialog extends StatefulWidget {
  const ReservaFormDialog({
    super.key,
    required this.service,
    required this.clientes,
    required this.productos,
    required this.usuarioActual,
    this.reserva,
  });

  final ClientesReservasService service;
  final List<Cliente> clientes;
  final List<Producto> productos;
  final Usuario usuarioActual;
  final Reserva? reserva;

  @override
  State<ReservaFormDialog> createState() => _ReservaFormDialogState();
}

class _ReservaFormDialogState extends State<ReservaFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cantidadController = TextEditingController(
    text: '1',
  );
  final TextEditingController _notasController = TextEditingController();
  final TextEditingController _lugarController = TextEditingController();
  final TextEditingController _tipoEventoController = TextEditingController();
  final TextEditingController _invitadosController = TextEditingController();
  final TextEditingController _costoMovilidadController =
      TextEditingController();
  final TextEditingController _abonoInicialController = TextEditingController();
  final TextEditingController _precioUnitarioController =
      TextEditingController();

  late String _clienteId;
  String _productoId = '';
  late DateTime _fecha;
  late TimeOfDay _hora;
  String _estado = EstadoReserva.pendiente;
  bool _guardando = false;
  String? _error;

  /// Reservas creadas desde una cotización conservan sus ítems originales.
  bool get _reservaConItems => widget.reserva?.items.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    final reserva = widget.reserva;
    final clienteExiste = widget.clientes.any(
      (cliente) => cliente.id == reserva?.clienteId,
    );
    _clienteId = clienteExiste ? reserva!.clienteId : widget.clientes.first.id!;

    final productoExiste = widget.productos.any(
      (producto) => producto.id == reserva?.productoId,
    );
    _productoId = productoExiste ? reserva!.productoId : '';

    _fecha = reserva?.fecha ?? DateTime.now().add(const Duration(days: 1));
    _hora = TimeOfDay.fromDateTime(_fecha);
    _estado = reserva?.estado ?? EstadoReserva.pendiente;
    _cantidadController.text = _textoNumero(
      _reservaConItems ? reserva!.cantidadTotal : reserva?.cantidad ?? 1,
    );
    _notasController.text = reserva?.notas ?? '';
    _lugarController.text = reserva?.lugar ?? '';
    _tipoEventoController.text = reserva?.tipoEvento ?? '';
    _invitadosController.text = (reserva?.numeroInvitados ?? 0) > 0
        ? '${reserva!.numeroInvitados}'
        : '';
    _costoMovilidadController.text = _textoNumero(reserva?.costoMovilidad ?? 0);
    _abonoInicialController.text = _textoNumero(reserva?.abonoInicial ?? 0);
    _precioUnitarioController.text = _textoNumero(reserva?.precioUnitario ?? 0);
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _notasController.dispose();
    _lugarController.dispose();
    _tipoEventoController.dispose();
    _invitadosController.dispose();
    _costoMovilidadController.dispose();
    _abonoInicialController.dispose();
    _precioUnitarioController.dispose();
    super.dispose();
  }

  static String _textoNumero(double valor) {
    if (valor == valor.roundToDouble()) return valor.toStringAsFixed(0);
    return valor.toStringAsFixed(2);
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

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cliente = widget.clientes.firstWhere((item) => item.id == _clienteId);
    Producto? producto;
    for (final item in widget.productos) {
      if (item.id == _productoId) {
        producto = item;
        break;
      }
    }

    final reservaAnterior = widget.reserva;
    final items = reservaAnterior?.items ?? const <ReservaItem>[];
    final cantidad = items.isEmpty
        ? roundMoney(parseDecimal(_cantidadController.text))
        : roundMoney(
            items.fold<double>(0, (total, item) => total + item.cantidad),
          );

    final reserva = Reserva(
      id: reservaAnterior?.id,
      clienteId: cliente.id!,
      clienteNombre: cliente.nombre,
      productoId: items.isEmpty
          ? producto?.id ?? ''
          : reservaAnterior?.productoId ?? '',
      productoNombre: items.isEmpty
          ? producto?.nombre ?? ''
          : reservaAnterior?.productoNombre ?? '',
      fecha: _fecha,
      cantidad: cantidad,
      precioUnitario: items.isEmpty
          ? roundMoney(parseDecimal(_precioUnitarioController.text))
          : reservaAnterior?.precioUnitario ?? 0,
      costoUnitario: reservaAnterior?.costoUnitario ?? 0,
      tipoCosto: reservaAnterior?.tipoCosto ?? TipoCostoReserva.insumo,
      estado: _estado,
      notas: _notasController.text.trim(),
      cotizacionId: reservaAnterior?.cotizacionId ?? '',
      cotizacionNumero: reservaAnterior?.cotizacionNumero ?? '',
      items: items,
      lugar: _lugarController.text.trim(),
      tipoEvento: _tipoEventoController.text.trim(),
      numeroInvitados: asInt(_invitadosController.text),
      costoMovilidad: roundMoney(parseDecimal(_costoMovilidadController.text)),
      abonoInicial: roundMoney(parseDecimal(_abonoInicialController.text)),
      moneda: reservaAnterior?.moneda ?? AppConfig.moneda,
      creadoPorUid: reservaAnterior?.creadoPorUid.isNotEmpty == true
          ? reservaAnterior!.creadoPorUid
          : widget.usuarioActual.uid,
      creadoPorNombre: reservaAnterior?.creadoPorNombre.isNotEmpty == true
          ? reservaAnterior!.creadoPorNombre
          : widget.usuarioActual.nombreVisible,
      creadoPorEmail: reservaAnterior?.creadoPorEmail.isNotEmpty == true
          ? reservaAnterior!.creadoPorEmail
          : widget.usuarioActual.email,
      creadoPorTelefono: reservaAnterior?.creadoPorTelefono.isNotEmpty == true
          ? reservaAnterior!.creadoPorTelefono
          : widget.usuarioActual.telefono,
    );

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (reserva.id == null) {
        await widget.service.agregarReserva(reserva);
      } else {
        await widget.service.actualizarReserva(reserva);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar la reserva. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.reserva == null ? 'Nueva reserva' : 'Editar reserva'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _clienteId,
                  decoration: const InputDecoration(
                    labelText: 'Cliente *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: widget.clientes
                      .map(
                        (cliente) => DropdownMenuItem<String>(
                          value: cliente.id,
                          child: Text(
                            cliente.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _guardando
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _clienteId = value);
                          }
                        },
                  validator: (value) =>
                      value == null ? 'Selecciona un cliente' : null,
                ),
                const SizedBox(height: 12),
                if (_reservaConItems)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 19,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Esta reserva conserva los '
                            '${widget.reserva!.items.length} ítem(s) '
                            '${widget.reserva!.cotizacionNumero.isEmpty ? 'de la cotización de origen' : 'de la cotización ${widget.reserva!.cotizacionNumero}'}. '
                            'Puedes cambiar la fecha, el estado y las notas.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _productoId,
                    decoration: const InputDecoration(
                      labelText: 'Producto (opcional)',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Sin producto específico'),
                      ),
                      ...widget.productos.map(
                        (producto) => DropdownMenuItem<String>(
                          value: producto.id,
                          child: Text(
                            producto.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (value) => setState(() => _productoId = value ?? ''),
                  ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _guardando ? null : _seleccionarFecha,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(AppFormatters.shortDate(_fecha)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _guardando ? null : _seleccionarHora,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_hora.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lugarController,
                  enabled: !_guardando,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Lugar del evento',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'Salón, dirección o ciudad',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tipoEventoController,
                  enabled: !_guardando,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de evento',
                    prefixIcon: Icon(Icons.celebration_outlined),
                    hintText: 'Boda, cumpleaños, corporativo...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _invitadosController,
                        enabled: !_guardando,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'N.º de invitados',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costoMovilidadController,
                        enabled: !_guardando,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Costo de movilidad',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_reservaConItems) ...<Widget>[
                  TextFormField(
                    controller: _precioUnitarioController,
                    enabled: !_guardando,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario de venta',
                      prefixIcon: Icon(Icons.sell_outlined),
                      helperText:
                          'Se multiplica por la cantidad y se suma al costo de '
                          'movilidad para obtener el total de la boleta.',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _abonoInicialController,
                  enabled: !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Abono inicial',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _reservaConItems
                          ? InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Cantidad total',
                                prefixIcon: Icon(Icons.numbers_outlined),
                              ),
                              child: Text(
                                '${AppFormatters.quantity(widget.reserva!.cantidadTotal)} uds. '
                                'en ${widget.reserva!.items.length} ítem(s)',
                              ),
                            )
                          : TextFormField(
                              controller: _cantidadController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Cantidad *',
                                suffixText: 'uds.',
                              ),
                              validator: (value) {
                                final numero = parseDecimal(
                                  value ?? '',
                                  fallback: -1,
                                );
                                if (numero <= 0) return 'Mayor a 0';
                                return null;
                              },
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: EstadoReserva.todos
                            .map(
                              (estado) => DropdownMenuItem<String>(
                                value: estado,
                                child: Text(_capitalizar(estado)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _guardando
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _estado = value);
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notasController,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_guardando ? 'Guardando...' : 'Guardar reserva'),
        ),
      ],
    );
  }
}

/// Acción elegida en el diálogo de detalle de una reserva.
enum _AccionDetalleReserva { editar, notificar, boleta }

/// Diálogo con todos los datos de una reserva y sus ítems.
class _ReservaDetalleDialog extends StatelessWidget {
  const _ReservaDetalleDialog({required this.reserva});

  final Reserva reserva;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estadoColor = _ReservaCard._colorEstado(scheme, reserva.estado);
    final items = reserva.items;

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.event_available_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Detalle de la reserva')),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: scheme.secondaryContainer,
                      child: Text(
                        reserva.clienteNombre.trim().isEmpty
                            ? '?'
                            : reserva.clienteNombre.trim()[0].toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reserva.clienteNombre,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _capitalizar(reserva.estado),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: estadoColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _datoDetalle(
                context,
                icon: Icons.calendar_today_outlined,
                etiqueta: 'Fecha del evento',
                valor: AppFormatters.date(reserva.fecha),
              ),
              _datoDetalle(
                context,
                icon: Icons.schedule_outlined,
                etiqueta: 'Hora de inicio',
                valor: reserva.horaInicio,
              ),
              _datoDetalle(
                context,
                icon: Icons.location_on_outlined,
                etiqueta: 'Lugar',
                valor: reserva.lugar.isEmpty ? 'No registrado' : reserva.lugar,
              ),
              _datoDetalle(
                context,
                icon: Icons.celebration_outlined,
                etiqueta: 'Tipo de evento',
                valor: reserva.tipoEvento.isEmpty
                    ? 'No registrado'
                    : reserva.tipoEvento,
              ),
              _datoDetalle(
                context,
                icon: Icons.groups_outlined,
                etiqueta: 'Número de invitados',
                valor: reserva.numeroInvitados > 0
                    ? '${reserva.numeroInvitados}'
                    : 'No registrado',
              ),
              _datoDetalle(
                context,
                icon: Icons.local_shipping_outlined,
                etiqueta: 'Costo de movilidad',
                valor: AppFormatters.money(
                  reserva.costoMovilidad,
                  moneda: reserva.moneda,
                ),
              ),
              _datoDetalle(
                context,
                icon: Icons.payments_outlined,
                etiqueta: 'Abono inicial',
                valor: AppFormatters.money(
                  reserva.abonoInicial,
                  moneda: reserva.moneda,
                ),
              ),
              _datoDetalle(
                context,
                icon: Icons.account_balance_wallet_outlined,
                etiqueta: 'Total de la reserva',
                valor: AppFormatters.money(
                  reserva.total,
                  moneda: reserva.moneda,
                ),
              ),
              _datoDetalle(
                context,
                icon: Icons.price_check_outlined,
                etiqueta: 'Saldo pendiente',
                valor: AppFormatters.money(
                  reserva.saldoPendiente,
                  moneda: reserva.moneda,
                ),
              ),
              if (reserva.costoTotal > 0)
                _datoDetalle(
                  context,
                  icon: Icons.request_quote_outlined,
                  etiqueta: 'Gastos estimados',
                  valor:
                      'Insumos ${AppFormatters.money(reserva.costoInsumos, moneda: reserva.moneda)} · '
                      'Mano de obra ${AppFormatters.money(reserva.costoManoObra, moneda: reserva.moneda)} · '
                      'Otros ${AppFormatters.money(reserva.costoOtros, moneda: reserva.moneda)}',
                ),
              _datoDetalle(
                context,
                icon: Icons.inventory_2_outlined,
                etiqueta: 'Resumen de productos',
                valor: reserva.resumenProductos.isEmpty
                    ? 'Sin productos específicos'
                    : reserva.resumenProductos,
              ),
              _datoDetalle(
                context,
                icon: Icons.numbers_outlined,
                etiqueta: 'Cantidad total',
                valor:
                    '${AppFormatters.quantity(reserva.cantidadTotal)} uds. '
                    'en ${reserva.cantidadItems} ítem(s)',
              ),
              if (reserva.items.isEmpty && reserva.precioUnitario > 0)
                _datoDetalle(
                  context,
                  icon: Icons.sell_outlined,
                  etiqueta: 'Precio unitario',
                  valor: AppFormatters.money(
                    reserva.precioUnitario,
                    moneda: reserva.moneda,
                  ),
                ),
              _datoDetalle(
                context,
                icon: Icons.receipt_long_outlined,
                etiqueta: 'Cotización de origen',
                valor: reserva.cotizacionNumero.isEmpty
                    ? 'Reserva creada manualmente'
                    : reserva.cotizacionNumero,
              ),
              if (reserva.nombreCreador.isNotEmpty)
                _datoDetalle(
                  context,
                  icon: Icons.person_outline,
                  etiqueta: 'Creador de la cotización',
                  valor: reserva.nombreCreador,
                ),
              if (reserva.notas.isNotEmpty)
                _datoDetalle(
                  context,
                  icon: Icons.notes_outlined,
                  etiqueta: 'Notas',
                  valor: reserva.notas,
                ),
              if (items.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  'Ítems reservados',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
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
                        title: Text(item.descripcion),
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
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(_AccionDetalleReserva.notificar),
          icon: const Icon(Icons.send_outlined),
          label: const Text('Notificar'),
        ),
        if (reserva.estaCompletada)
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_AccionDetalleReserva.boleta),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Boleta'),
          ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(_AccionDetalleReserva.editar),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar reserva'),
        ),
      ],
    );
  }

  Widget _datoDetalle(
    BuildContext context, {
    required IconData icon,
    required String etiqueta,
    required String valor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
      ),
    );
  }
}

String _capitalizar(String texto) {
  if (texto.isEmpty) return texto;
  return '${texto[0].toUpperCase()}${texto.substring(1)}';
}

String _mesCorto(DateTime fecha) {
  const meses = <String>[
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return meses[fecha.month - 1];
}
