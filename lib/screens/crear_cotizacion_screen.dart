import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_config.dart';
import '../core/moneda.dart';
import '../models/cotizacion.dart';
import '../models/item_cotizacion.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../services/catalogo_service.dart';
import '../services/cotizacion_service.dart';
import '../utils/formatters.dart';
import '../utils/num_utils.dart';
import '../widgets/producto_selector_dialog.dart';
import '../widgets/section_header.dart';

/// Formulario para crear una cotización con ítems dinámicos.
class CrearCotizacionScreen extends StatefulWidget {
  const CrearCotizacionScreen({
    super.key,
    required this.service,
    required this.catalogoService,
    required this.onCotizacionGuardada,
    this.usuarioActual,
  });

  final CotizacionService service;
  final CatalogoService catalogoService;
  final VoidCallback onCotizacionGuardada;

  /// Usuario que crea la cotización. Sus datos se guardan para notificarle
  /// cuando la cotización se convierta en reserva.
  final Usuario? usuarioActual;

  @override
  State<CrearCotizacionScreen> createState() => _CrearCotizacionScreenState();
}

class _CrearCotizacionScreenState extends State<CrearCotizacionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  final TextEditingController _lugarController = TextEditingController();
  final TextEditingController _tipoEventoController = TextEditingController();
  final TextEditingController _invitadosController = TextEditingController();
  final TextEditingController _costoMovilidadController =
      TextEditingController();
  final TextEditingController _impuestoController = TextEditingController(
    text: AppConfig.impuestoPredeterminado.toStringAsFixed(0),
  );

  final List<_ItemFormData> _items = <_ItemFormData>[];
  int _siguienteItemId = 0;

  bool _aplicarImpuesto = true;
  bool _guardando = false;
  Moneda _moneda = Moneda.predeterminada;

  double _subtotal = 0;
  double _impuesto = 0;
  double _movilidad = 0;
  double _total = 0;
  double _tasaImpuesto = AppConfig.impuestoPredeterminado;

  @override
  void initState() {
    super.initState();
    _items.add(_crearItemData());
    _impuestoController.addListener(_recalcular);
    _costoMovilidadController.addListener(_recalcular);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recalcular();
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _notasController.dispose();
    _lugarController.dispose();
    _tipoEventoController.dispose();
    _invitadosController.dispose();
    _costoMovilidadController.dispose();
    _impuestoController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  _ItemFormData _crearItemData({
    String descripcion = '',
    String cantidad = '1',
    String precio = '',
    String? productoId,
  }) {
    final item = _ItemFormData(
      id: _siguienteItemId++,
      descripcion: descripcion,
      cantidad: cantidad,
      precio: precio,
      productoId: productoId,
    );
    item.cantidadController.addListener(_recalcular);
    item.precioController.addListener(_recalcular);
    return item;
  }

  void _agregarItemManual() {
    setState(() => _items.add(_crearItemData()));
    _recalcular();
  }

  Future<Producto?> _elegirProducto() {
    return showDialog<Producto>(
      context: context,
      builder: (dialogContext) =>
          ProductoSelectorDialog(service: widget.catalogoService),
    );
  }

  void _aplicarProductoAItem(_ItemFormData item, Producto producto) {
    setState(() => item.productoId = producto.id);
    item.descripcionController.text = descripcionDeProducto(producto);
    if (item.cantidadController.text.trim().isEmpty) {
      item.cantidadController.text = '1';
    }
    item.precioController.text = textoPrecioEditable(producto.precioVenta);
    _recalcular();
  }

  Future<void> _agregarDesdeCatalogo() async {
    if (_guardando) return;
    final producto = await _elegirProducto();
    if (producto == null || !mounted) return;

    final itemVacio = _items.length == 1 && _items.first.estaVacio
        ? _items.first
        : null;
    if (itemVacio != null) {
      _aplicarProductoAItem(itemVacio, producto);
      return;
    }

    setState(() {
      _items.add(
        _crearItemData(
          descripcion: descripcionDeProducto(producto),
          precio: textoPrecioEditable(producto.precioVenta),
          productoId: producto.id,
        ),
      );
    });
    _recalcular();
  }

  Future<void> _elegirProductoParaItem(_ItemFormData item) async {
    if (_guardando) return;
    final producto = await _elegirProducto();
    if (producto == null || !mounted) return;
    _aplicarProductoAItem(item, producto);
  }

  void _eliminarItem(_ItemFormData item) {
    if (_items.length == 1) return;
    setState(() => _items.remove(item));
    // Esperamos al siguiente frame para que el campo deje de estar montado.
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
    _recalcular();
  }

  void _recalcular() {
    if (!mounted) return;

    final subtotal = roundMoney(
      _items.fold<double>(0, (acumulado, item) => acumulado + item.total),
    );
    final tasa = _aplicarImpuesto
        ? parseDecimal(_impuestoController.text).clamp(0, 100).toDouble()
        : 0.0;
    final impuesto = roundMoney(subtotal * tasa / 100);
    final movilidad = roundMoney(parseDecimal(_costoMovilidadController.text));

    setState(() {
      _subtotal = subtotal;
      _tasaImpuesto = tasa;
      _impuesto = impuesto;
      _movilidad = movilidad;
      _total = roundMoney(subtotal + impuesto + movilidad);
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      _mostrarMensaje('Revisa los campos marcados antes de guardar.');
      return;
    }

    final items = <ItemCotizacion>[];
    for (final item in _items) {
      final descripcion = item.descripcionController.text.trim();
      final cantidad = parseDecimal(item.cantidadController.text);
      final precio = parseDecimal(item.precioController.text);
      if (descripcion.isEmpty || cantidad <= 0 || precio < 0) {
        _mostrarMensaje('Hay un ítem incompleto. Verifica sus datos.');
        return;
      }
      items.add(
        ItemCotizacion(
          descripcion: descripcion,
          cantidad: cantidad,
          precioUnitario: precio,
          productoId: item.productoId,
        ),
      );
    }

    if (items.isEmpty) {
      _mostrarMensaje('Agrega al menos un producto o servicio.');
      return;
    }

    final ahora = DateTime.now();
    final usuario = widget.usuarioActual;
    final cotizacion = Cotizacion.crear(
      numeroCotizacion: _generarFolio(ahora),
      clienteNombre: _nombreController.text,
      clienteTelefono: _telefonoParaGuardar(),
      clienteEmail: _emailController.text,
      fecha: ahora,
      items: items,
      aplicarImpuesto: _aplicarImpuesto,
      porcentajeImpuesto: _aplicarImpuesto
          ? parseDecimal(_impuestoController.text)
          : 0,
      moneda: _moneda.codigo,
      notas: _notasController.text,
      lugar: _lugarController.text,
      tipoEvento: _tipoEventoController.text,
      numeroInvitados: asInt(_invitadosController.text),
      costoMovilidad: roundMoney(parseDecimal(_costoMovilidadController.text)),
      creadoPorUid: usuario?.uid ?? '',
      creadoPorNombre: usuario?.nombreVisible ?? '',
      creadoPorEmail: usuario?.email ?? '',
      creadoPorTelefono: usuario?.telefono ?? '',
    );

    setState(() => _guardando = true);

    try {
      await widget.service.guardar(cotizacion);
      if (!mounted) return;

      final folio = cotizacion.numeroCotizacion;
      _limpiarFormulario();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Cotización $folio guardada en la nube.',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      widget.onCotizacionGuardada();
    } catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrarMensaje(_mensajeDeError(error), error: true);
    }
  }

  String _mensajeDeError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied') ||
        text.contains('missing or insufficient permissions')) {
      return 'Firestore rechazó la escritura. Revisa tus reglas de seguridad.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'No hay conexión con Firestore. Intenta de nuevo.';
    }
    return 'No se pudo guardar la cotización. Intenta de nuevo.';
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            mensaje,
            style: error ? TextStyle(color: scheme.onError) : null,
          ),
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  Future<void> _confirmarLimpiar() async {
    if (_guardando) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Limpiar la cotización?'),
        content: const Text(
          'Se borrarán los datos del cliente y todos los ítems capturados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      _limpiarFormulario();
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nombreController.clear();
    _telefonoController.clear();
    _emailController.clear();
    _notasController.clear();
    _lugarController.clear();
    _tipoEventoController.clear();
    _invitadosController.clear();
    _costoMovilidadController.clear();

    final itemsAnteriores = List<_ItemFormData>.of(_items);
    setState(() {
      _items
        ..clear()
        ..add(_crearItemData());
      _aplicarImpuesto = true;
      _moneda = Moneda.predeterminada;
      _subtotal = 0;
      _impuesto = 0;
      _movilidad = 0;
      _total = 0;
      _tasaImpuesto = AppConfig.impuestoPredeterminado;
      _guardando = false;
    });

    _impuestoController.text = AppConfig.impuestoPredeterminado.toStringAsFixed(
      0,
    );
    _recalcular();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in itemsAnteriores) {
        item.dispose();
      }
    });
  }

  /// Normaliza el teléfono capturado al formato peruano `+51 999999999`.
  String _telefonoParaGuardar() {
    final texto = _telefonoController.text.trim();
    if (texto.isEmpty) return '';
    var digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length > 9 && digitos.startsWith('51')) {
      digitos = digitos.substring(2);
    }
    if (digitos.isEmpty) return '';
    return '${AppConfig.prefijoTelefono} $digitos';
  }

  String _generarFolio(DateTime fecha) {
    String dos(int value) => value.toString().padLeft(2, '0');
    final milisegundos = fecha.millisecond.toString().padLeft(3, '0');
    return 'COT-${fecha.year}${dos(fecha.month)}${dos(fecha.day)}-'
        '${dos(fecha.hour)}${dos(fecha.minute)}${dos(fecha.second)}'
        '$milisegundos';
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
          final usarDosColumnas = constraints.maxWidth >= 1080;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _encabezado(context),
                      const SizedBox(height: 22),
                      if (usarDosColumnas)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: <Widget>[
                                  _tarjetaCliente(context),
                                  const SizedBox(height: 20),
                                  _tarjetaEvento(context),
                                  const SizedBox(height: 20),
                                  _tarjetaItems(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 370,
                              child: _tarjetaResumen(context),
                            ),
                          ],
                        )
                      else ...<Widget>[
                        _tarjetaCliente(context),
                        const SizedBox(height: 20),
                        _tarjetaEvento(context),
                        const SizedBox(height: 20),
                        _tarjetaItems(context),
                        const SizedBox(height: 20),
                        _tarjetaResumen(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Nueva cotización', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Captura los datos del cliente y desglosa los productos o '
                'servicios. Los importes se calculan automáticamente.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Chip(
          avatar: Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          label: const Text('Se guarda en Firestore'),
          backgroundColor: theme.colorScheme.secondaryContainer,
          side: BorderSide.none,
        ),
      ],
    );
  }

  Widget _tarjetaCliente(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.person_outline,
              title: 'Datos del cliente',
              subtitle: 'Información que aparecerá en la cotización.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente *',
                hintText: 'Nombre o razón social',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                final nombre = value?.trim() ?? '';
                if (nombre.isEmpty) return 'Escribe el nombre del cliente';
                if (nombre.length < 2) return 'El nombre es demasiado corto';
                return null;
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final telefono = TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '999 999 999',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '${AppConfig.prefijoTelefono} ',
                  ),
                  validator: (value) {
                    final texto = value?.trim() ?? '';
                    if (texto.isEmpty) return null;
                    final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digitos.length < 6 || digitos.length > 12) {
                      return 'Escribe un teléfono válido';
                    }
                    return null;
                  },
                );
                final email = TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'cliente@empresa.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return null;
                    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!regex.hasMatch(email)) {
                      return 'Escribe un email válido';
                    }
                    return null;
                  },
                );

                if (constraints.maxWidth >= 620) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: telefono),
                      const SizedBox(width: 14),
                      Expanded(child: email),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    telefono,
                    const SizedBox(height: 14),
                    email,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notasController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas o condiciones (opcional)',
                hintText: 'Ej. Tiempo de entrega, anticipo, garantía...',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEvento(BuildContext context) {
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
                  'Se guardan con la cotización y pasan a la reserva cuando se '
                  'confirma. La fecha, la hora y el abono se definen al '
                  'convertirla en reserva.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _lugarController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Lugar del evento',
                hintText: 'Salón, dirección o ciudad',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tipoEventoController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tipo de evento',
                hintText: 'Boda, cumpleaños, corporativo...',
                prefixIcon: Icon(Icons.celebration_outlined),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final invitados = TextFormField(
                  controller: _invitadosController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'N.º de invitados',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                );
                final movilidad = TextFormField(
                  controller: _costoMovilidadController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Costo de movilidad',
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    suffixText: _moneda.codigo,
                  ),
                );

                if (constraints.maxWidth >= 520) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: invitados),
                      const SizedBox(width: 14),
                      Expanded(child: movilidad),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    invitados,
                    const SizedBox(height: 14),
                    movilidad,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaItems(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.inventory_2_outlined,
              title: 'Productos y servicios',
              subtitle: 'Cada línea suma al subtotal de la cotización.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _guardando ? null : _agregarDesdeCatalogo,
                  icon: const Icon(Icons.inventory_2_outlined, size: 19),
                  label: const Text('Elegir del catálogo'),
                ),
                OutlinedButton.icon(
                  onPressed: _guardando ? null : _agregarItemManual,
                  icon: const Icon(Icons.add_circle_outline, size: 19),
                  label: const Text('Producto no encontrado'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < _items.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 12),
              _editorItem(context, _items[index], index),
            ],
            const SizedBox(height: 12),
            Text(
              'Los productos se cargan desde Admin › Productos. Si algo no '
              'está en el catálogo, usa "Producto no encontrado" y escribe la '
              'descripción y el precio manualmente.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorItem(BuildContext context, _ItemFormData item, int index) {
    final theme = Theme.of(context);

    final descripcion = TextFormField(
      controller: item.descripcionController,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Descripción *',
        hintText: 'Producto o servicio',
        prefixIcon: Icon(Icons.article_outlined),
      ),
      validator: (value) {
        if ((value?.trim() ?? '').isEmpty) {
          return 'Escribe una descripción';
        }
        return null;
      },
    );

    final cantidad = TextFormField(
      controller: item.cantidadController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: const InputDecoration(
        labelText: 'Cantidad *',
        suffixText: 'uds.',
      ),
      validator: (value) {
        final numero = parseDecimal(value ?? '', fallback: -1);
        if (numero <= 0) return 'Mayor a 0';
        return null;
      },
    );

    final precio = TextFormField(
      controller: item.precioController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: 'Precio unitario *',
        prefixText: '${_moneda.simbolo} ',
      ),
      validator: (value) {
        final texto = value?.trim() ?? '';
        if (texto.isEmpty) return 'Requerido';
        final numero = parseDecimal(texto, fallback: -1);
        if (numero < 0) return 'Inválido';
        return null;
      },
    );

    final totalLinea = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Importe',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            AppFormatters.money(item.total, moneda: _moneda.codigo),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );

    return Container(
      key: ValueKey<int>(item.id),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 13,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Ítem ${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.productoId != null) ...<Widget>[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Tomado del catálogo de productos',
                  child: Icon(
                    Icons.verified_outlined,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Elegir del catálogo',
                onPressed: _guardando
                    ? null
                    : () => _elegirProductoParaItem(item),
                icon: const Icon(Icons.inventory_2_outlined),
                color: theme.colorScheme.primary,
              ),
              IconButton(
                tooltip: _items.length == 1
                    ? 'Agrega otro ítem primero'
                    : 'Eliminar ítem',
                onPressed: _items.length == 1 || _guardando
                    ? null
                    : () => _eliminarItem(item),
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 670) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 5, child: descripcion),
                    const SizedBox(width: 10),
                    SizedBox(width: 100, child: cantidad),
                    const SizedBox(width: 10),
                    SizedBox(width: 140, child: precio),
                    const SizedBox(width: 12),
                    totalLinea,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  descripcion,
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: cantidad),
                      const SizedBox(width: 12),
                      Expanded(child: precio),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: totalLinea),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionHeader(
              icon: Icons.calculate_outlined,
              title: 'Resumen',
              subtitle: 'Revisa los importes antes de guardar.',
            ),
            const SizedBox(height: 18),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Moneda',
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Moneda>(
                  value: _moneda,
                  isExpanded: true,
                  onChanged: _guardando
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _moneda = value);
                        },
                  items: Moneda.todas
                      .map(
                        (moneda) => DropdownMenuItem<Moneda>(
                          value: moneda,
                          child: Text(
                            moneda.etiqueta,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    title: const Text('Aplicar IGV (18%)'),
                    subtitle: const Text(
                      'Impuesto General a las Ventas del Perú',
                    ),
                    value: _aplicarImpuesto,
                    onChanged: _guardando
                        ? null
                        : (value) {
                            setState(() => _aplicarImpuesto = value);
                            _recalcular();
                          },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Porcentaje de IGV',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 112,
                          child: TextFormField(
                            controller: _impuestoController,
                            enabled: _aplicarImpuesto && !_guardando,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: '%',
                            ),
                            validator: (value) {
                              if (!_aplicarImpuesto) return null;
                              final tasa = parseDecimal(
                                value ?? '',
                                fallback: -1,
                              );
                              if (tasa < 0 || tasa > 100) {
                                return 'Entre 0 y 100';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _MontoFila(
              etiqueta: 'Subtotal',
              valor: AppFormatters.money(_subtotal, moneda: _moneda.codigo),
            ),
            if (_aplicarImpuesto) ...<Widget>[
              const SizedBox(height: 9),
              _MontoFila(
                etiqueta:
                    '${AppConfig.nombreImpuesto} '
                    '(${AppFormatters.percentage(_tasaImpuesto)})',
                valor: AppFormatters.money(_impuesto, moneda: _moneda.codigo),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 9),
              Text(
                '${AppConfig.nombreImpuesto} no aplicado',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 9),
            _MontoFila(
              etiqueta: 'Costo de movilidad',
              valor: AppFormatters.money(_movilidad, moneda: _moneda.codigo),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
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
                  AppFormatters.money(_total, moneda: _moneda.codigo),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_items.length} ítem(s) · ${_moneda.codigo} '
              '(${_moneda.simbolo})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_guardando ? 'Guardando...' : 'Guardar cotización'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _guardando ? null : _confirmarLimpiar,
              icon: const Icon(Icons.restart_alt, size: 19),
              label: const Text('Limpiar formulario'),
            ),
            const SizedBox(height: 4),
            Text(
              'El folio, la fecha ISO y los totales se agregan automáticamente '
              'al guardar en Firestore.',
              textAlign: TextAlign.center,
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

class _ItemFormData {
  _ItemFormData({
    required this.id,
    String descripcion = '',
    String cantidad = '1',
    String precio = '',
    this.productoId,
  }) : descripcionController = TextEditingController(text: descripcion),
       cantidadController = TextEditingController(text: cantidad),
       precioController = TextEditingController(text: precio);

  final int id;
  final TextEditingController descripcionController;
  final TextEditingController cantidadController;
  final TextEditingController precioController;

  /// Producto del catálogo del admin cuando la línea proviene de ahí.
  String? productoId;

  double get cantidad => parseDecimal(cantidadController.text);
  double get precioUnitario => parseDecimal(precioController.text);
  double get total => roundMoney(cantidad * precioUnitario);

  bool get estaVacio =>
      descripcionController.text.trim().isEmpty &&
      precioController.text.trim().isEmpty;

  void dispose() {
    descripcionController.dispose();
    cantidadController.dispose();
    precioController.dispose();
  }
}

class _MontoFila extends StatelessWidget {
  const _MontoFila({required this.etiqueta, required this.valor});

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
