import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../services/catalogo_service.dart';
import '../utils/formatters.dart';
import 'producto_imagen.dart';

/// Diálogo para elegir un producto activo del catálogo administrado.
///
/// Devuelve el [Producto] seleccionado o `null` si el usuario cancela.
class ProductoSelectorDialog extends StatefulWidget {
  const ProductoSelectorDialog({super.key, required this.service});

  final CatalogoService service;

  @override
  State<ProductoSelectorDialog> createState() => _ProductoSelectorDialogState();
}

class _ProductoSelectorDialogState extends State<ProductoSelectorDialog> {
  late final Stream<List<Producto>> _productosStream;
  String _busqueda = '';
  String? _categoriaId;

  @override
  void initState() {
    super.initState();
    _productosStream = widget.service.escucharProductos();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.inventory_2_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Elegir del catálogo')),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 480,
        child: StreamBuilder<List<Producto>>(
          stream: _productosStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _mensajeEstado(
                theme,
                icon: Icons.cloud_off_outlined,
                titulo: 'No se pudo cargar el catálogo',
                detalle:
                    'Revisa la conexión y las reglas de Firestore para la '
                    'colección de productos.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final productos = (snapshot.data ?? const <Producto>[])
                .where((producto) => producto.activo)
                .toList(growable: false);

            if (productos.isEmpty) {
              return _mensajeEstado(
                theme,
                icon: Icons.inventory_2_outlined,
                titulo: 'No hay productos en el catálogo',
                detalle:
                    'Agrega productos desde Admin › Productos o usa la opción '
                    '"Producto no encontrado" para capturarlo manualmente.',
              );
            }

            final categorias = <String, String>{
              for (final producto in productos)
                if (producto.categoriaId.isNotEmpty)
                  producto.categoriaId: producto.categoriaNombre,
            };
            final categoriaActiva = categorias.containsKey(_categoriaId)
                ? _categoriaId
                : null;

            final consulta = _busqueda.trim().toLowerCase();
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Buscar',
                          hintText: 'Nombre, categoría o descripción',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(() => _busqueda = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: categoriaActiva,
                            isExpanded: true,
                            onChanged: (value) =>
                                setState(() => _categoriaId = value),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todas'),
                              ),
                              ...categorias.entries.map(
                                (categoria) => DropdownMenuItem<String?>(
                                  value: categoria.key,
                                  child: Text(
                                    categoria.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No hay productos que coincidan con la búsqueda.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final producto = filtrados[index];
                        return _filaProducto(context, producto);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _filaProducto(BuildContext context, Producto producto) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: ProductoImagen(
            imagenBase64: producto.imagenBase64,
            iconSize: 22,
          ),
        ),
      ),
      title: Text(
        producto.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        producto.descripcion.isEmpty
            ? producto.categoriaNombre
            : '${producto.categoriaNombre} · ${producto.descripcion}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            AppFormatters.money(producto.precioVenta),
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Precio venta',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).pop(producto),
    );
  }

  Widget _mensajeEstado(
    ThemeData theme, {
    required IconData icon,
    required String titulo,
    required String detalle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto de precio sin decimales innecesarios, listo para un formulario.
String textoPrecioEditable(double valor) {
  if (valor == valor.roundToDouble()) return valor.toStringAsFixed(0);
  return valor.toStringAsFixed(2);
}

/// Descripción sugerida para un producto del catálogo.
String descripcionDeProducto(Producto producto) {
  if (producto.descripcion.isEmpty) return producto.nombre;
  return '${producto.nombre} - ${producto.descripcion}';
}
