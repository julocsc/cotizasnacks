import 'package:flutter/material.dart';

import '../../models/cotizacion.dart';
import '../../models/ingreso.dart';
import '../../models/producto.dart';
import '../../models/reserva.dart';
import '../../services/catalogo_service.dart';
import '../../services/clientes_reservas_service.dart';
import '../../services/cotizacion_service.dart';
import '../../utils/formatters.dart';
import 'admin_empty_state.dart';

enum _VistaIngresos { fecha, evento }

enum _PeriodoIngresos { todo, mesActual, anioActual, personalizado }

/// Pestaña para consultar ventas, costos y utilidad por fecha o por evento.
class IngresosAdminTab extends StatefulWidget {
  const IngresosAdminTab({
    super.key,
    required this.cotizacionService,
    required this.catalogoService,
    required this.clientesService,
  });

  final CotizacionService cotizacionService;
  final CatalogoService catalogoService;
  final ClientesReservasService clientesService;

  @override
  State<IngresosAdminTab> createState() => _IngresosAdminTabState();
}

class _IngresosAdminTabState extends State<IngresosAdminTab> {
  late Stream<List<Cotizacion>> _cotizacionesStream;
  late Stream<List<Producto>> _productosStream;
  late Stream<List<Reserva>> _reservasStream;

  _VistaIngresos _vista = _VistaIngresos.fecha;
  _PeriodoIngresos _periodo = _PeriodoIngresos.todo;
  AgrupacionFecha _agrupacion = AgrupacionFecha.mes;
  DateTimeRange? _rangoPersonalizado;
  bool _ocultarCanceladas = true;

  @override
  void initState() {
    super.initState();
    _cotizacionesStream = widget.cotizacionService.escucharCotizaciones(
      limite: 2000,
    );
    _productosStream = widget.catalogoService.escucharProductos();
    _reservasStream = widget.clientesService.escucharReservas();
  }

  void _recargar() {
    setState(() {
      _cotizacionesStream = widget.cotizacionService.escucharCotizaciones(
        limite: 2000,
      );
      _productosStream = widget.catalogoService.escucharProductos();
      _reservasStream = widget.clientesService.escucharReservas();
    });
  }

  ({DateTime? desde, DateTime? hasta}) _rangoFechas() {
    final ahora = DateTime.now();
    switch (_periodo) {
      case _PeriodoIngresos.todo:
        return (desde: null, hasta: null);
      case _PeriodoIngresos.mesActual:
        return (
          desde: DateTime(ahora.year, ahora.month),
          hasta: DateTime(ahora.year, ahora.month + 1, 0),
        );
      case _PeriodoIngresos.anioActual:
        return (
          desde: DateTime(ahora.year),
          hasta: DateTime(ahora.year, 12, 31),
        );
      case _PeriodoIngresos.personalizado:
        final rango = _rangoPersonalizado;
        return (desde: rango?.start, hasta: rango?.end);
    }
  }

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final seleccionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(ahora.year + 10, 12, 31),
      initialDateRange: _rangoPersonalizado,
      helpText: 'Período de ingresos',
      saveText: 'Aplicar',
    );
    if (seleccionado == null) return;
    setState(() {
      _rangoPersonalizado = seleccionado;
      _periodo = _PeriodoIngresos.personalizado;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cotizacion>>(
      stream: _cotizacionesStream,
      builder: (context, cotizacionesSnapshot) {
        return StreamBuilder<List<Producto>>(
          stream: _productosStream,
          builder: (context, productosSnapshot) {
            return StreamBuilder<List<Reserva>>(
              stream: _reservasStream,
              builder: (context, reservasSnapshot) {
                final cargando =
                    cotizacionesSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    productosSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    reservasSnapshot.connectionState == ConnectionState.waiting;
                final error =
                    cotizacionesSnapshot.hasError ||
                    productosSnapshot.hasError ||
                    reservasSnapshot.hasError;

                if (error) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: AdminErrorState(
                      mensaje:
                          'Revisa la conexión y las reglas de Firestore para '
                          'cotizaciones, productos y reservas.',
                      onReintentar: _recargar,
                    ),
                  );
                }

                if (cargando) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cotizaciones =
                    cotizacionesSnapshot.data ?? const <Cotizacion>[];
                final productos = productosSnapshot.data ?? const <Producto>[];
                final reservas = reservasSnapshot.data ?? const <Reserva>[];
                final productosPorId = <String, Producto>{
                  for (final producto in productos)
                    if (producto.id != null) producto.id!: producto,
                };

                final rango = _rangoFechas();
                final resumenesFecha = IngresoCalculadora.agruparPorFecha(
                  cotizaciones,
                  productosPorId,
                  agrupacion: _agrupacion,
                  desde: rango.desde,
                  hasta: rango.hasta,
                );
                var eventos = IngresoCalculadora.eventos(
                  reservas,
                  cotizaciones,
                  productosPorId,
                  desde: rango.desde,
                  hasta: rango.hasta,
                );
                if (_ocultarCanceladas) {
                  eventos = eventos
                      .where(
                        (evento) =>
                            evento.reserva.estado != EstadoReserva.cancelada,
                      )
                      .toList(growable: false);
                }

                final total = _vista == _VistaIngresos.fecha
                    ? IngresoCalculadora.totalizar(resumenesFecha)
                    : IngresoCalculadora.totalizar(
                        eventos.map((evento) => evento.resumen),
                      );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _filtros(context),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: <Widget>[
                            _tarjetasTotales(context, total),
                            const SizedBox(height: 12),
                            _notaCalculo(context, total.itemsSinCosto),
                            const SizedBox(height: 16),
                            if (_vista == _VistaIngresos.fecha)
                              _listaPorFecha(context, resumenesFecha)
                            else
                              _listaEventos(context, eventos),
                          ],
                        ),
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

  Widget _filtros(BuildContext context) {
    final theme = Theme.of(context);
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _chipPeriodo('Todo', _PeriodoIngresos.todo),
        _chipPeriodo('Este mes', _PeriodoIngresos.mesActual),
        _chipPeriodo('Este año', _PeriodoIngresos.anioActual),
        ChoiceChip(
          label: Text(
            _periodo == _PeriodoIngresos.personalizado &&
                    _rangoPersonalizado != null
                ? '${AppFormatters.shortDate(_rangoPersonalizado!.start)} - '
                      '${AppFormatters.shortDate(_rangoPersonalizado!.end)}'
                : 'Elegir fechas',
          ),
          selected: _periodo == _PeriodoIngresos.personalizado,
          onSelected: (_) => _elegirRango(),
        ),
      ],
    );

    final selectorVista = SegmentedButton<_VistaIngresos>(
      segments: const <ButtonSegment<_VistaIngresos>>[
        ButtonSegment<_VistaIngresos>(
          value: _VistaIngresos.fecha,
          icon: Icon(Icons.calendar_month_outlined),
          label: Text('Por fecha'),
        ),
        ButtonSegment<_VistaIngresos>(
          value: _VistaIngresos.evento,
          icon: Icon(Icons.event_available_outlined),
          label: Text('Por evento'),
        ),
      ],
      selected: <_VistaIngresos>{_vista},
      onSelectionChanged: (seleccion) {
        setState(() => _vista = seleccion.first);
      },
    );

    final agrupacion = IgnorePointer(
      ignoring: _vista == _VistaIngresos.evento,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: _vista == _VistaIngresos.fecha ? 1 : 0.45,
        child: SizedBox(
          width: 170,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Agrupar por',
              prefixIcon: Icon(Icons.stacked_bar_chart_outlined),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AgrupacionFecha>(
                value: _agrupacion,
                isExpanded: true,
                onChanged: _vista == _VistaIngresos.evento
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _agrupacion = value);
                        }
                      },
                items: const <DropdownMenuItem<AgrupacionFecha>>[
                  DropdownMenuItem<AgrupacionFecha>(
                    value: AgrupacionFecha.dia,
                    child: Text('Día'),
                  ),
                  DropdownMenuItem<AgrupacionFecha>(
                    value: AgrupacionFecha.mes,
                    child: Text('Mes'),
                  ),
                  DropdownMenuItem<AgrupacionFecha>(
                    value: AgrupacionFecha.anio,
                    child: Text('Año'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final ocultarCanceladas = _vista == _VistaIngresos.evento
        ? FilterChip(
            label: const Text('Ocultar canceladas'),
            selected: _ocultarCanceladas,
            onSelected: (value) => setState(() => _ocultarCanceladas = value),
          )
        : const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[selectorVista, agrupacion, ocultarCanceladas],
          ),
          const SizedBox(height: 10),
          chips,
        ],
      ),
    );
  }

  Widget _chipPeriodo(String etiqueta, _PeriodoIngresos periodo) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected: _periodo == periodo,
      onSelected: (_) => setState(() => _periodo = periodo),
    );
  }

  Widget _tarjetasTotales(BuildContext context, ResumenIngresos total) {
    final tarjetas = <Widget>[
      _TarjetaTotal(
        titulo: 'Ventas netas',
        valor: AppFormatters.money(total.ventas),
        detalle: '${total.cantidadVentas} venta(s) con cotización',
        icono: Icons.payments_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      _TarjetaTotal(
        titulo: 'Costos',
        valor: AppFormatters.money(total.costos),
        detalle: 'Precio de compra del catálogo',
        icono: Icons.inventory_2_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      _TarjetaTotal(
        titulo: 'Utilidad',
        valor: AppFormatters.money(total.utilidad),
        detalle: total.utilidad >= 0 ? 'Ganancia del período' : 'Pérdida',
        icono: Icons.trending_up,
        color: total.utilidad >= 0
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.error,
      ),
      _TarjetaTotal(
        titulo: 'Margen',
        valor: AppFormatters.percentage(total.margen),
        detalle: 'Utilidad / ventas netas',
        icono: Icons.percent,
        color: Theme.of(context).colorScheme.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 1060
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const espacio = 12.0;
        final ancho =
            (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: tarjetas
              .map((tarjeta) => SizedBox(width: ancho, child: tarjeta))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _notaCalculo(BuildContext context, int itemsSinCosto) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            itemsSinCosto > 0 ? Icons.info_outline : Icons.verified_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              itemsSinCosto > 0
                  ? 'La utilidad usa el subtotal sin impuestos y el costo de '
                        'compra de los productos del catálogo. Hay '
                        '$itemsSinCosto línea(s) manuales sin producto '
                        'asociado, por lo que no suman costo.'
                  : 'La utilidad usa el subtotal sin impuestos y el precio de '
                        'compra actual de los productos del catálogo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaPorFecha(BuildContext context, List<ResumenIngresos> resumenes) {
    if (resumenes.isEmpty) {
      return AdminEmptyState(
        icon: Icons.query_stats_outlined,
        titulo: 'Sin ventas en el período',
        mensaje:
            'No hay cotizaciones registradas para las fechas seleccionadas. '
            'Prueba con otro período o con "Todo".',
        accionEtiqueta: 'Ver todo',
        onAccion: () => setState(() => _periodo = _PeriodoIngresos.todo),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Detalle por ${_etiquetaAgrupacion(_agrupacion).toLowerCase()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final resumen in resumenes) ...<Widget>[
          _ResumenFechaCard(resumen: resumen),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _listaEventos(BuildContext context, List<IngresoEvento> eventos) {
    if (eventos.isEmpty) {
      return AdminEmptyState(
        icon: Icons.event_busy_outlined,
        titulo: 'Sin eventos en el período',
        mensaje:
            'No hay reservas para las fechas seleccionadas. Las reservas se '
            'crean desde la pestaña Reservas o al convertir una cotización.',
        accionEtiqueta: 'Ver todo',
        onAccion: () => setState(() => _periodo = _PeriodoIngresos.todo),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Detalle por evento',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final evento in eventos) ...<Widget>[
          _EventoCard(evento: evento),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _etiquetaAgrupacion(AgrupacionFecha agrupacion) {
    switch (agrupacion) {
      case AgrupacionFecha.dia:
        return 'Día';
      case AgrupacionFecha.mes:
        return 'Mes';
      case AgrupacionFecha.anio:
        return 'Año';
    }
  }
}

class _TarjetaTotal extends StatelessWidget {
  const _TarjetaTotal({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.icono,
    required this.color,
  });

  final String titulo;
  final String valor;
  final String detalle;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, size: 19, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    titulo,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valor,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenFechaCard extends StatelessWidget {
  const _ResumenFechaCard({required this.resumen});

  final ResumenIngresos resumen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final proporcion = resumen.ventas <= 0
        ? 0.0
        : (resumen.utilidad / resumen.ventas).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    resumen.etiqueta,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${resumen.cantidadVentas} cotización(es)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: <Widget>[
                _dato(
                  context,
                  'Ventas',
                  AppFormatters.money(resumen.ventas),
                  scheme.onSurface,
                ),
                _dato(
                  context,
                  'Costos',
                  AppFormatters.money(resumen.costos),
                  scheme.onSurfaceVariant,
                ),
                _dato(
                  context,
                  'Utilidad',
                  AppFormatters.money(resumen.utilidad),
                  resumen.utilidad >= 0 ? scheme.tertiary : scheme.error,
                ),
                _dato(
                  context,
                  'Margen',
                  AppFormatters.percentage(resumen.margen),
                  scheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: proporcion,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                color: resumen.utilidad >= 0 ? scheme.tertiary : scheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(
    BuildContext context,
    String etiqueta,
    String valor,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          etiqueta,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EventoCard extends StatelessWidget {
  const _EventoCard({required this.evento});

  final IngresoEvento evento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reserva = evento.reserva;
    final colorEstado = _colorEstado(scheme, reserva.estado);
    final fecha = reserva.fecha.toLocal();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                    '${fecha.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _mesCorto(fecha),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
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
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _capitalizar(reserva.estado),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorEstado,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppFormatters.dateTime(reserva.fecha),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reserva.resumenProductos.isEmpty
                        ? 'Sin productos específicos'
                        : reserva.resumenProductos,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (evento.tieneCotizacion)
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: <Widget>[
                        _datoEvento(
                          context,
                          'Venta',
                          AppFormatters.money(evento.ventas),
                          scheme.onSurface,
                        ),
                        _datoEvento(
                          context,
                          'Costo',
                          AppFormatters.money(evento.costos),
                          scheme.onSurfaceVariant,
                        ),
                        _datoEvento(
                          context,
                          'Utilidad',
                          AppFormatters.money(evento.utilidad),
                          evento.utilidad >= 0 ? scheme.tertiary : scheme.error,
                        ),
                        _datoEvento(
                          context,
                          'Margen',
                          AppFormatters.percentage(evento.margen),
                          scheme.secondary,
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.link_off,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Evento sin cotización vinculada: no se puede '
                              'calcular la utilidad.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (reserva.cotizacionNumero.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Cotización: ${reserva.cotizacionNumero}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datoEvento(
    BuildContext context,
    String etiqueta,
    String valor,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          etiqueta,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          valor,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
