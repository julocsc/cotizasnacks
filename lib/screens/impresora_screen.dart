import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/empresa_config.dart';
import '../models/producto.dart';
import '../models/reserva.dart';
import '../services/catalogo_service.dart';
import '../services/clientes_reservas_service.dart';
import '../services/empresa_service.dart';
import '../services/pdf_service.dart';
import '../utils/formatters.dart';
import '../utils/num_utils.dart';
import 'pdf_preview_screen.dart';

/// Sección de impresión de boletas y cotizaciones de gastos por reserva.
class ImpresoraScreen extends StatefulWidget {
  const ImpresoraScreen({
    super.key,
    required this.clientesService,
    required this.catalogoService,
    required this.empresaService,
  });

  final ClientesReservasService clientesService;
  final CatalogoService catalogoService;
  final EmpresaService empresaService;

  @override
  State<ImpresoraScreen> createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends State<ImpresoraScreen> {
  final PdfService _pdfService = PdfService();

  late Stream<List<Reserva>> _reservasStream;
  late Stream<List<Producto>> _productosStream;
  late Future<EmpresaConfig> _empresaFuture;

  String _busqueda = '';
  bool _soloCompletadas = false;

  @override
  void initState() {
    super.initState();
    _reservasStream = widget.clientesService.escucharReservas();
    _productosStream = widget.catalogoService.escucharProductos();
    _empresaFuture = widget.empresaService.obtenerConfiguracion();
  }

  void _recargar() {
    setState(() {
      _reservasStream = widget.clientesService.escucharReservas();
      _productosStream = widget.catalogoService.escucharProductos();
      _empresaFuture = widget.empresaService.obtenerConfiguracion();
    });
  }

  Future<EmpresaConfig> _empresa() async {
    try {
      return await _empresaFuture;
    } catch (_) {
      return const EmpresaConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reserva>>(
      stream: _reservasStream,
      builder: (context, reservasSnapshot) {
        return StreamBuilder<List<Producto>>(
          stream: _productosStream,
          builder: (context, productosSnapshot) {
            final cargando =
                reservasSnapshot.connectionState == ConnectionState.waiting ||
                productosSnapshot.connectionState == ConnectionState.waiting;
            final error =
                reservasSnapshot.hasError || productosSnapshot.hasError;

            final reservas = reservasSnapshot.data ?? const <Reserva>[];
            final productos = productosSnapshot.data ?? const <Producto>[];
            final consulta = _busqueda.trim().toLowerCase();
            final filtradas = reservas
                .where((reserva) {
                  if (_soloCompletadas && !reserva.estaCompletada) return false;
                  final texto =
                      '${reserva.clienteNombre} ${reserva.cotizacionNumero} '
                              '${reserva.lugar} ${reserva.tipoEvento} '
                              '${reserva.items.map((item) => item.descripcion).join(' ')}'
                          .toLowerCase();
                  return consulta.isEmpty || texto.contains(consulta);
                })
                .toList(growable: false);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _encabezado(context),
                  const SizedBox(height: 12),
                  _filtros(context),
                  const SizedBox(height: 14),
                  Expanded(
                    child: error
                        ? _EstadoError(onReintentar: _recargar)
                        : cargando
                        ? const Center(child: CircularProgressIndicator())
                        : _lista(context, filtradas, productos),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _encabezado(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.print_outlined, color: scheme.onSecondaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Impresora', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 3),
              Text(
                'Genera la boleta de reservas completadas y la cotización de '
                'gastos por insumos, mano de obra y otros.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filtros(BuildContext context) {
    final buscador = TextField(
      decoration: const InputDecoration(
        labelText: 'Buscar reserva',
        hintText: 'Cliente, cotización, lugar o ítem',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() => _busqueda = value),
    );

    final filtro = FilterChip(
      label: const Text('Solo completadas'),
      avatar: const Icon(Icons.task_alt, size: 18),
      selected: _soloCompletadas,
      onSelected: (value) => setState(() => _soloCompletadas = value),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 680) {
          return Row(
            children: <Widget>[
              Expanded(child: buscador),
              const SizedBox(width: 12),
              filtro,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buscador,
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: filtro),
          ],
        );
      },
    );
  }

  Widget _lista(
    BuildContext context,
    List<Reserva> reservas,
    List<Producto> productos,
  ) {
    if (reservas.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.print_disabled_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No hay reservas para imprimir',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _soloCompletadas
                    ? 'Marca una reserva como completada para habilitar su '
                          'boleta.'
                    : 'Crea reservas desde el panel de administración para '
                          'generar boletas y gastos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final productosPorId = <String, Producto>{
      for (final producto in productos)
        if (producto.id != null) producto.id!: producto,
    };

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: reservas.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final reserva = reservas[index];
        return _TarjetaImpresion(
          reserva: reserva,
          onBoleta: () => _abrirBoleta(reserva),
          onGastos: () => _abrirGastos(reserva, productosPorId),
        );
      },
    );
  }

  Future<void> _abrirBoleta(Reserva reserva) async {
    if (!reserva.estaCompletada) {
      _mensaje(
        'Marca la reserva como completada para generar la boleta.',
        error: true,
      );
      return;
    }

    final empresa = await _empresa();
    if (!mounted) return;
    final numero = PdfService.numeroBoleta(reserva);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DocumentoPdfScreen(
          titulo: 'Boleta · $numero',
          nombreArchivo: 'boleta_${_archivoSeguro(numero)}.pdf',
          generar: () => _pdfService.generarBoleta(reserva, empresa: empresa),
        ),
      ),
    );
  }

  Future<void> _abrirGastos(
    Reserva reserva,
    Map<String, Producto> productos,
  ) async {
    final actualizada = await showDialog<Reserva>(
      context: context,
      builder: (dialogContext) => _GastosReservaDialog(
        reserva: reserva,
        productos: productos,
        service: widget.clientesService,
      ),
    );
    if (actualizada == null || !mounted) return;

    final empresa = await _empresa();
    if (!mounted) return;
    final numero = PdfService.numeroCotizacionGastos(actualizada);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DocumentoPdfScreen(
          titulo: 'Gastos · $numero',
          nombreArchivo: 'gastos_${_archivoSeguro(numero)}.pdf',
          generar: () => _pdfService.generarCotizacionGastos(
            actualizada,
            productos: productos,
            empresa: empresa,
          ),
        ),
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

  static String _archivoSeguro(String texto) {
    return texto.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}

class _TarjetaImpresion extends StatelessWidget {
  const _TarjetaImpresion({
    required this.reserva,
    required this.onBoleta,
    required this.onGastos,
  });

  final Reserva reserva;
  final VoidCallback onBoleta;
  final VoidCallback onGastos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completada = reserva.estaCompletada;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 21,
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
                          _EstadoChip(estado: reserva.estado),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${AppFormatters.dateTime(reserva.fecha)}'
                        '${reserva.lugar.isEmpty ? '' : ' · ${reserva.lugar}'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (reserva.cotizacionNumero.isNotEmpty)
                        Text(
                          'Cotización: ${reserva.cotizacionNumero}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
              child: Wrap(
                spacing: 22,
                runSpacing: 8,
                children: <Widget>[
                  _MontoResumen(
                    etiqueta: 'Subtotal',
                    valor: AppFormatters.money(
                      reserva.subtotal,
                      moneda: reserva.moneda,
                    ),
                  ),
                  _MontoResumen(
                    etiqueta: 'Movilidad',
                    valor: AppFormatters.money(
                      reserva.costoMovilidad,
                      moneda: reserva.moneda,
                    ),
                  ),
                  _MontoResumen(
                    etiqueta: 'Total',
                    valor: AppFormatters.money(
                      reserva.total,
                      moneda: reserva.moneda,
                    ),
                    destacado: true,
                  ),
                  _MontoResumen(
                    etiqueta: 'Saldo',
                    valor: AppFormatters.money(
                      reserva.saldoPendiente,
                      moneda: reserva.moneda,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: <Widget>[
                Tooltip(
                  message: completada
                      ? 'Generar boleta de venta'
                      : 'Solo disponible para reservas completadas',
                  child: OutlinedButton.icon(
                    onPressed: completada ? onBoleta : null,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Boleta'),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onGastos,
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('Gastos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (estado) {
      EstadoReserva.completada => scheme.tertiary,
      EstadoReserva.confirmada => scheme.primary,
      EstadoReserva.cancelada => scheme.error,
      _ => scheme.secondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _capitalizar(estado),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MontoResumen extends StatelessWidget {
  const _MontoResumen({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          etiqueta,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: destacado ? scheme.primary : null,
          ),
        ),
      ],
    );
  }
}

/// Diálogo para revisar y ajustar los gastos de cada ítem de la reserva.
class _GastosReservaDialog extends StatefulWidget {
  const _GastosReservaDialog({
    required this.reserva,
    required this.productos,
    required this.service,
  });

  final Reserva reserva;
  final Map<String, Producto> productos;
  final ClientesReservasService service;

  @override
  State<_GastosReservaDialog> createState() => _GastosReservaDialogState();
}

class _GastosReservaDialogState extends State<_GastosReservaDialog> {
  late List<_GastoItemForm> _forms;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final items = widget.reserva.items.isNotEmpty
        ? widget.reserva.items
        : <ReservaItem>[
            ReservaItem(
              descripcion: widget.reserva.productoNombre.isEmpty
                  ? 'Servicio de la reserva'
                  : widget.reserva.productoNombre,
              productoId: widget.reserva.productoId,
              cantidad: widget.reserva.cantidad <= 0
                  ? 1
                  : widget.reserva.cantidad,
              precioUnitario: widget.reserva.precioUnitario,
              costoUnitario: widget.reserva.costoUnitario,
              tipoCosto: widget.reserva.tipoCosto,
            ),
          ];

    _forms = items
        .map((item) {
          final producto = widget.productos[item.productoId];
          final costoInicial = item.costoUnitario > 0
              ? item.costoUnitario
              : producto?.precioCompra ?? 0;
          return _GastoItemForm(
            item: item,
            costo: TextEditingController(text: _textoNumero(costoInicial)),
            tipo: item.tipoCosto,
          );
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.costo.dispose();
    }
    super.dispose();
  }

  static String _textoNumero(double valor) {
    if (valor == valor.roundToDouble()) return valor.toStringAsFixed(0);
    return valor.toStringAsFixed(2);
  }

  List<ReservaItem> get _itemsActualizados {
    return _forms
        .map((form) {
          return form.item.copyWith(
            costoUnitario: roundMoney(parseDecimal(form.costo.text)),
            tipoCosto: form.tipo,
          );
        })
        .toList(growable: false);
  }

  Reserva get _reservaActualizada {
    if (widget.reserva.items.isEmpty) {
      if (_forms.isEmpty) return widget.reserva;
      final form = _forms.first;
      return widget.reserva.copyWith(
        costoUnitario: roundMoney(parseDecimal(form.costo.text)),
        tipoCosto: form.tipo,
      );
    }
    return widget.reserva.copyWith(items: _itemsActualizados);
  }

  double get _totalInsumos => _reservaActualizada.costoInsumos;
  double get _totalManoObra => _reservaActualizada.costoManoObra;
  double get _totalOtros => _reservaActualizada.costoOtros;
  double get _totalGastos => _reservaActualizada.costoTotal;

  Future<void> _guardar() async {
    if (_guardando) return;
    final actualizada = _reservaActualizada;
    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (widget.reserva.id != null) {
        await widget.service.actualizarReserva(actualizada);
      }
      if (!mounted) return;
      Navigator.of(context).pop(actualizada);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudieron guardar los costos. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.request_quote_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('Gastos · ${widget.reserva.clienteNombre}')),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Clasifica el costo de cada ítem. Los importes se usarán en la '
                'cotización de gastos y en la utilidad estimada.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (_forms.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Esta reserva no tiene ítems detallados. Agrega ítems desde '
                    'la cotización de origen para asignarles un costo.',
                  ),
                )
              else
                for (var index = 0; index < _forms.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 24),
                  _filaItem(context, _forms[index], index),
                ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: <Widget>[
                    _filaTotal(context, 'Insumos', _totalInsumos),
                    const SizedBox(height: 6),
                    _filaTotal(context, 'Mano de obra', _totalManoObra),
                    const SizedBox(height: 6),
                    _filaTotal(context, 'Otros', _totalOtros),
                    const Divider(height: 18),
                    _filaTotal(
                      context,
                      'Total gastos',
                      _totalGastos,
                      destacado: true,
                    ),
                  ],
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
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
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_guardando ? 'Guardando...' : 'Guardar e imprimir'),
        ),
      ],
    );
  }

  Widget _filaItem(BuildContext context, _GastoItemForm form, int index) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${index + 1}. ${form.item.descripcion}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: form.tipo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  isDense: true,
                ),
                items: TipoCostoReserva.todos
                    .map(
                      (tipo) => DropdownMenuItem<String>(
                        value: tipo,
                        child: Text(TipoCostoReserva.etiqueta(tipo)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _guardando
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => form.tipo = value);
                        }
                      },
              ),
            ),
            SizedBox(
              width: 175,
              child: TextField(
                controller: form.costo,
                enabled: !_guardando,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Costo unitario',
                  isDense: true,
                  suffixText: widget.reserva.moneda,
                ),
              ),
            ),
            SizedBox(
              width: 175,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Costo total',
                  isDense: true,
                ),
                child: Text(
                  AppFormatters.money(
                    roundMoney(
                      form.item.cantidad * parseDecimal(form.costo.text),
                    ),
                    moneda: widget.reserva.moneda,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filaTotal(
    BuildContext context,
    String etiqueta,
    double valor, {
    bool destacado = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            etiqueta,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: destacado ? FontWeight.w800 : null,
            ),
          ),
        ),
        Text(
          AppFormatters.money(valor, moneda: widget.reserva.moneda),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: destacado ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _GastoItemForm {
  _GastoItemForm({required this.item, required this.costo, required this.tipo});

  final ReservaItem item;
  final TextEditingController costo;
  String tipo;
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, size: 52, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar las reservas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Revisa la conexión y las reglas de Firestore.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalizar(String texto) {
  if (texto.isEmpty) return texto;
  return '${texto[0].toUpperCase()}${texto.substring(1)}';
}
