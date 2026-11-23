import 'package:flutter/material.dart';

import '../models/cotizacion.dart';
import '../models/usuario.dart';
import '../services/clientes_reservas_service.dart';
import '../services/cotizacion_service.dart';
import '../utils/formatters.dart';
import 'detalle_cotizacion_screen.dart';

/// Historial en tiempo real respaldado por un `Stream` de Cloud Firestore.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({
    super.key,
    required this.service,
    required this.clientesService,
    required this.onCrearCotizacion,
    this.usuarioActual,
    this.puedeCrearCotizacion = true,
    this.puedeConvertirEnReserva = true,
    this.puedeEliminar = true,
  });

  final CotizacionService service;
  final ClientesReservasService clientesService;
  final VoidCallback onCrearCotizacion;
  final Usuario? usuarioActual;
  final bool puedeCrearCotizacion;
  final bool puedeConvertirEnReserva;
  final bool puedeEliminar;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Stream<List<Cotizacion>> _cotizaciones;

  @override
  void initState() {
    super.initState();
    _cotizaciones = widget.service.escucharCotizaciones();
  }

  @override
  void didUpdateWidget(covariant HistorialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _cotizaciones = widget.service.escucharCotizaciones();
    }
  }

  void _reintentar() {
    setState(() {
      _cotizaciones = widget.service.escucharCotizaciones();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 1200
              ? 32.0
              : constraints.maxWidth >= 700
              ? 24.0
              : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      24,
                      horizontal,
                      16,
                    ),
                    child: _encabezado(context, constraints.maxWidth),
                  ),
                  Expanded(
                    child: StreamBuilder<List<Cotizacion>>(
                      stream: _cotizaciones,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _EstadoError(
                            error: snapshot.error!,
                            onReintentar: _reintentar,
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final cotizaciones =
                            snapshot.data ?? const <Cotizacion>[];

                        if (cotizaciones.isEmpty) {
                          return _EstadoVacio(
                            onCrearCotizacion: widget.onCrearCotizacion,
                            puedeCrear: widget.puedeCrearCotizacion,
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            4,
                            horizontal,
                            36,
                          ),
                          itemCount: cotizaciones.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final cotizacion = cotizaciones[index];
                            return _TarjetaCotizacion(
                              cotizacion: cotizacion,
                              onTap: () => _abrirDetalle(cotizacion),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(BuildContext context, double ancho) {
    final theme = Theme.of(context);
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'Historial en la nube',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Actualización en tiempo real',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.sync,
                      size: 14,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tiempo real',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Consulta las cotizaciones guardadas en Firestore. Los cambios '
          'aparecen automáticamente en todos los dispositivos.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final boton = FilledButton.icon(
      onPressed: widget.onCrearCotizacion,
      icon: const Icon(Icons.add),
      label: const Text('Nueva cotización'),
    );

    if (!widget.puedeCrearCotizacion) {
      return titulo;
    }

    if (ancho >= 660) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: titulo),
          const SizedBox(width: 20),
          boton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[titulo, const SizedBox(height: 16), boton],
    );
  }

  Future<void> _abrirDetalle(Cotizacion cotizacion) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DetalleCotizacionScreen(
          cotizacion: cotizacion,
          service: widget.service,
          clientesService: widget.clientesService,
          usuarioActual: widget.usuarioActual,
          puedeConvertirEnReserva: widget.puedeConvertirEnReserva,
          puedeEliminar: widget.puedeEliminar,
        ),
      ),
    );
  }
}

class _TarjetaCotizacion extends StatelessWidget {
  const _TarjetaCotizacion({required this.cotizacion, required this.onTap});

  final Cotizacion cotizacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inicial = cotizacion.clienteNombre.trim().isEmpty
        ? '?'
        : cotizacion.clienteNombre.trim()[0].toUpperCase();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 23,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  inicial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cotizacion.clienteNombre.isEmpty
                          ? 'Cliente sin nombre'
                          : cotizacion.clienteNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          cotizacion.numeroCotizacion,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          AppFormatters.dateTime(cotizacion.fecha),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${cotizacion.cantidadItems} ítem(s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (cotizacion.estado ==
                            Cotizacion.estadoReservada) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Reservada',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    AppFormatters.money(
                      cotizacion.total,
                      moneda: cotizacion.moneda,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Ver detalle',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.onCrearCotizacion,
    required this.puedeCrear,
  });

  final VoidCallback onCrearCotizacion;
  final bool puedeCrear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aún no hay cotizaciones',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                puedeCrear
                    ? 'Crea tu primera cotización; se guardará en Firestore y '
                          'aparecerá aquí al instante.'
                    : 'Cuando se registre una cotización aparecerá aquí '
                          'automáticamente.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (puedeCrear) ...<Widget>[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onCrearCotizacion,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear cotización'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 38,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No se pudo cargar el historial',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifica tu conexión, que Firestore esté habilitado y que '
                    'las reglas de seguridad permitan la lectura.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      error.toString(),
                      maxLines: 4,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onReintentar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
