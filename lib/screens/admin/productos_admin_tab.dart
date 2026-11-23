import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/moneda.dart';
import '../../models/categoria_producto.dart';
import '../../models/producto.dart';
import '../../services/catalogo_service.dart';
import '../../utils/formatters.dart';
import '../../utils/num_utils.dart';
import '../../widgets/producto_imagen.dart';
import 'admin_empty_state.dart';

/// Pestaña de administración del catálogo de productos y sus categorías.
class ProductosAdminTab extends StatefulWidget {
  const ProductosAdminTab({super.key, required this.service});

  final CatalogoService service;

  @override
  State<ProductosAdminTab> createState() => _ProductosAdminTabState();
}

class _ProductosAdminTabState extends State<ProductosAdminTab> {
  late Stream<List<CategoriaProducto>> _categoriasStream;
  late Stream<List<Producto>> _productosStream;

  String _busqueda = '';
  String? _categoriaId;

  @override
  void initState() {
    super.initState();
    _categoriasStream = widget.service.escucharCategorias();
    _productosStream = widget.service.escucharProductos();
  }

  void _recargar() {
    setState(() {
      _categoriasStream = widget.service.escucharCategorias();
      _productosStream = widget.service.escucharProductos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoriaProducto>>(
      stream: _categoriasStream,
      builder: (context, categoriasSnapshot) {
        final categorias =
            categoriasSnapshot.data ?? const <CategoriaProducto>[];

        return StreamBuilder<List<Producto>>(
          stream: _productosStream,
          builder: (context, productosSnapshot) {
            final productos = productosSnapshot.data ?? const <Producto>[];
            final cargando =
                categoriasSnapshot.connectionState == ConnectionState.waiting ||
                productosSnapshot.connectionState == ConnectionState.waiting;
            final error =
                categoriasSnapshot.hasError || productosSnapshot.hasError;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _barraFiltros(context, categorias),
                  const SizedBox(height: 14),
                  Expanded(
                    child: error
                        ? AdminErrorState(
                            mensaje:
                                'Revisa la conexión y las reglas de Firestore '
                                'para las colecciones de productos.',
                            onReintentar: _recargar,
                          )
                        : cargando
                        ? const Center(child: CircularProgressIndicator())
                        : _listaProductos(context, productos, categorias),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _barraFiltros(
    BuildContext context,
    List<CategoriaProducto> categorias,
  ) {
    final buscador = TextField(
      decoration: const InputDecoration(
        labelText: 'Buscar producto',
        hintText: 'Nombre, categoría o descripción',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() => _busqueda = value),
    );

    final filtroCategoria = InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Categoría',
        prefixIcon: Icon(Icons.filter_list),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: categorias.any((categoria) => categoria.id == _categoriaId)
              ? _categoriaId
              : null,
          isExpanded: true,
          onChanged: (value) => setState(() => _categoriaId = value),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todas las categorías'),
            ),
            ...categorias.map(
              (categoria) => DropdownMenuItem<String?>(
                value: categoria.id,
                child: Text(categoria.nombre, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );

    final botones = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _abrirCategorias(context),
          icon: const Icon(Icons.category_outlined, size: 19),
          label: const Text('Categorías'),
        ),
        FilledButton.icon(
          onPressed: () => _abrirProducto(context, categorias),
          icon: const Icon(Icons.add, size: 19),
          label: const Text('Nuevo producto'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860) {
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: buscador),
              const SizedBox(width: 12),
              SizedBox(width: 230, child: filtroCategoria),
              const SizedBox(width: 12),
              botones,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buscador,
            const SizedBox(height: 10),
            filtroCategoria,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: botones),
          ],
        );
      },
    );
  }

  Widget _listaProductos(
    BuildContext context,
    List<Producto> productos,
    List<CategoriaProducto> categorias,
  ) {
    final consulta = _busqueda.trim().toLowerCase();
    final categoriaActiva =
        categorias.any((categoria) => categoria.id == _categoriaId)
        ? _categoriaId
        : null;

    final filtrados = productos
        .where((producto) {
          final coincideCategoria =
              categoriaActiva == null ||
              producto.categoriaId == categoriaActiva;
          final texto =
              '${producto.nombre} ${producto.categoriaNombre} '
                      '${producto.descripcion}'
                  .toLowerCase();
          return coincideCategoria &&
              (consulta.isEmpty || texto.contains(consulta));
        })
        .toList(growable: false);

    if (productos.isEmpty) {
      return AdminEmptyState(
        icon: Icons.inventory_2_outlined,
        titulo: 'Tu catálogo está vacío',
        mensaje:
            'Crea una categoría y después agrega tu primer producto con sus '
            'precios de compra y venta.',
        accionEtiqueta: 'Crear categoría',
        onAccion: () => _abrirCategorias(context),
      );
    }

    if (filtrados.isEmpty) {
      return AdminEmptyState(
        icon: Icons.search_off,
        titulo: 'Sin resultados',
        mensaje: 'No hay productos que coincidan con el filtro actual.',
        accionEtiqueta: 'Limpiar filtros',
        onAccion: () {
          setState(() {
            _busqueda = '';
            _categoriaId = null;
          });
        },
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisExtent: 356,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final producto = filtrados[index];
        return _ProductoCard(
          producto: producto,
          onEditar: () => _abrirProducto(context, null, producto: producto),
          onEliminar: () => _eliminarProducto(context, producto),
        );
      },
    );
  }

  Future<void> _abrirProducto(
    BuildContext context,
    List<CategoriaProducto>? categorias, {
    Producto? producto,
  }) async {
    var disponibles = categorias;
    disponibles ??= await widget.service.escucharCategorias().first;
    if (!mounted) return;

    if (disponibles.isEmpty) {
      _mensaje(
        'Primero crea una categoría para poder agregar productos.',
        error: true,
      );
      return;
    }

    final guardado = await showDialog<bool>(
      context: this.context,
      builder: (dialogContext) => ProductoFormDialog(
        service: widget.service,
        categorias: disponibles!,
        producto: producto,
      ),
    );

    if (guardado == true && mounted) {
      _mensaje(
        producto == null ? 'Producto agregado.' : 'Producto actualizado.',
      );
    }
  }

  Future<void> _abrirCategorias(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CategoriasDialog(service: widget.service),
    );
  }

  Future<void> _eliminarProducto(
    BuildContext context,
    Producto producto,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text(
          'Se eliminará "${producto.nombre}" del catálogo. '
          'Esta acción no se puede deshacer.',
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

    try {
      await widget.service.eliminarProducto(producto.id!);
      if (mounted) _mensaje('Producto eliminado.');
    } catch (error) {
      if (mounted) _mensaje('No se pudo eliminar el producto.', error: true);
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

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({
    required this.producto,
    required this.onEditar,
    required this.onEliminar,
  });

  final Producto producto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEditar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 138,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ProductoImagen(imagenBase64: producto.imagenBase64),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        producto.categoriaNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (producto.descripcion.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        producto.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'Venta: ${AppFormatters.money(producto.precioVenta)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Compra / insumo: '
                      '${AppFormatters.money(producto.precioCompra)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Margen: ${AppFormatters.money(producto.margen)} '
                      '(${AppFormatters.percentage(producto.margenPorcentaje)})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: producto.margen >= 0
                            ? scheme.primary
                            : scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: onEditar,
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Editar'),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Eliminar producto',
                          onPressed: onEliminar,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: scheme.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario para crear o editar un producto.
class ProductoFormDialog extends StatefulWidget {
  const ProductoFormDialog({
    super.key,
    required this.service,
    required this.categorias,
    this.producto,
  });

  final CatalogoService service;
  final List<CategoriaProducto> categorias;
  final Producto? producto;

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _compraController = TextEditingController();
  final TextEditingController _ventaController = TextEditingController();

  late String _categoriaId;
  String _imagenBase64 = '';
  bool _guardando = false;
  bool _cargandoImagen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final producto = widget.producto;
    _nombreController.text = producto?.nombre ?? '';
    _descripcionController.text = producto?.descripcion ?? '';
    _compraController.text = _textoPrecio(producto?.precioCompra ?? 0);
    _ventaController.text = _textoPrecio(producto?.precioVenta ?? 0);
    _imagenBase64 = producto?.imagenBase64 ?? '';

    final existeCategoria = widget.categorias.any(
      (categoria) => categoria.id == producto?.categoriaId,
    );
    _categoriaId = existeCategoria
        ? producto!.categoriaId
        : widget.categorias.first.id!;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _compraController.dispose();
    _ventaController.dispose();
    super.dispose();
  }

  static String _textoPrecio(double valor) {
    if (valor == valor.roundToDouble()) return valor.toStringAsFixed(0);
    return valor.toStringAsFixed(2);
  }

  Future<void> _seleccionarImagen() async {
    if (_cargandoImagen) return;
    setState(() => _cargandoImagen = true);

    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 70,
      );
      if (archivo == null) return;

      final bytes = await archivo.readAsBytes();
      if (bytes.length > 600 * 1024) {
        if (mounted) {
          setState(
            () => _error =
                'La imagen es demasiado grande. Elige una menor a 600 KB.',
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _imagenBase64 = base64Encode(bytes);
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la imagen seleccionada.');
      }
    } finally {
      if (mounted) setState(() => _cargandoImagen = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final categoria = widget.categorias.firstWhere(
      (item) => item.id == _categoriaId,
    );

    final producto = Producto(
      id: widget.producto?.id,
      nombre: _nombreController.text.trim(),
      categoriaId: categoria.id!,
      categoriaNombre: categoria.nombre,
      descripcion: _descripcionController.text.trim(),
      precioCompra: roundMoney(parseDecimal(_compraController.text)),
      precioVenta: roundMoney(parseDecimal(_ventaController.text)),
      imagenBase64: _imagenBase64,
      activo: widget.producto?.activo ?? true,
    );

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (producto.id == null) {
        await widget.service.agregarProducto(producto);
      } else {
        await widget.service.actualizarProducto(producto);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar el producto. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.producto == null ? 'Nuevo producto' : 'Editar producto',
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: ProductoImagen(
                          imagenBase64: _imagenBase64,
                          iconSize: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _cargandoImagen
                                ? null
                                : _seleccionarImagen,
                            icon: _cargandoImagen
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _imagenBase64.isEmpty
                                  ? 'Seleccionar imagen'
                                  : 'Cambiar imagen',
                            ),
                          ),
                          if (_imagenBase64.isNotEmpty)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _imagenBase64 = ''),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Quitar imagen'),
                            ),
                          Text(
                            'JPG o PNG. La imagen se optimiza antes de '
                            'guardarse en Firestore.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto *',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Escribe el nombre del producto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoriaId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: widget.categorias
                      .map(
                        (categoria) => DropdownMenuItem<String>(
                          value: categoria.id,
                          child: Text(
                            categoria.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _guardando
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _categoriaId = value);
                          }
                        },
                  validator: (value) =>
                      value == null ? 'Selecciona una categoría' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcionController,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _compraController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Precio compra / insumo *',
                          prefixText: '${Moneda.predeterminada.simbolo} ',
                        ),
                        validator: (value) {
                          final texto = value?.trim() ?? '';
                          if (texto.isEmpty) return 'Requerido';
                          if (parseDecimal(texto, fallback: -1) < 0) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ventaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Precio venta *',
                          prefixText: '${Moneda.predeterminada.simbolo} ',
                        ),
                        validator: (value) {
                          final texto = value?.trim() ?? '';
                          if (texto.isEmpty) return 'Requerido';
                          if (parseDecimal(texto, fallback: -1) < 0) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
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
          label: Text(_guardando ? 'Guardando...' : 'Guardar producto'),
        ),
      ],
    );
  }
}

/// Diálogo para agregar y eliminar categorías.
class CategoriasDialog extends StatefulWidget {
  const CategoriasDialog({super.key, required this.service});

  final CatalogoService service;

  @override
  State<CategoriasDialog> createState() => _CategoriasDialogState();
}

class _CategoriasDialogState extends State<CategoriasDialog> {
  final TextEditingController _nombreController = TextEditingController();
  late final Stream<List<CategoriaProducto>> _categoriasStream;
  late final Stream<List<Producto>> _productosStream;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoriasStream = widget.service.escucharCategorias();
    _productosStream = widget.service.escucharProductos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre de la categoría.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.service.agregarCategoria(nombre);
      if (mounted) {
        _nombreController.clear();
        setState(() => _guardando = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo crear la categoría.';
        });
      }
    }
  }

  Future<void> _eliminar(CategoriaProducto categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text('Se eliminará la categoría "${categoria.nombre}".'),
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
      await widget.service.eliminarCategoria(categoria.id!);
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo eliminar la categoría.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Categorías'),
      content: SizedBox(
        width: 500,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _nombreController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nueva categoría',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    onSubmitted: (_) => _agregar(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _guardando ? null : _agregar,
                  child: Text(_guardando ? '...' : 'Agregar'),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<CategoriaProducto>>(
                stream: _categoriasStream,
                builder: (context, categoriasSnapshot) {
                  final categorias =
                      categoriasSnapshot.data ?? const <CategoriaProducto>[];

                  return StreamBuilder<List<Producto>>(
                    stream: _productosStream,
                    builder: (context, productosSnapshot) {
                      final productos =
                          productosSnapshot.data ?? const <Producto>[];

                      if (categoriasSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          productosSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (categorias.isEmpty) {
                        return Center(
                          child: Text(
                            'Aún no hay categorías. Crea la primera arriba.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: categorias.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final categoria = categorias[index];
                          final cantidad = productos
                              .where(
                                (producto) =>
                                    producto.categoriaId == categoria.id,
                              )
                              .length;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(categoria.nombre),
                            subtitle: Text('$cantidad producto(s)'),
                            trailing: IconButton(
                              tooltip: cantidad == 0
                                  ? 'Eliminar categoría'
                                  : 'No se puede eliminar: tiene productos',
                              onPressed: cantidad == 0
                                  ? () => _eliminar(categoria)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
