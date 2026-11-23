import 'package:flutter/material.dart';

import '../../models/cliente.dart';
import '../../models/cotizacion.dart';
import '../../services/clientes_reservas_service.dart';
import '../../services/cotizacion_service.dart';
import 'admin_empty_state.dart';

/// Pestaña de administración de clientes.
///
/// Muestra los clientes registrados y también los que aparecen en el historial
/// de cotizaciones, para que puedan guardarse y usarse en reservas.
class ClientesAdminTab extends StatefulWidget {
  const ClientesAdminTab({
    super.key,
    required this.service,
    required this.cotizacionService,
  });

  final ClientesReservasService service;
  final CotizacionService cotizacionService;

  @override
  State<ClientesAdminTab> createState() => _ClientesAdminTabState();
}

class _ClientesAdminTabState extends State<ClientesAdminTab> {
  late Stream<List<Cliente>> _clientesStream;
  late Stream<List<Cotizacion>> _cotizacionesStream;

  String _busqueda = '';
  bool _importando = false;

  @override
  void initState() {
    super.initState();
    _clientesStream = widget.service.escucharClientes();
    _cotizacionesStream = widget.cotizacionService.escucharCotizaciones();
  }

  void _recargar() {
    setState(() {
      _clientesStream = widget.service.escucharClientes();
      _cotizacionesStream = widget.cotizacionService.escucharCotizaciones();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesStream,
      builder: (context, clientesSnapshot) {
        return StreamBuilder<List<Cotizacion>>(
          stream: _cotizacionesStream,
          builder: (context, cotizacionesSnapshot) {
            final clientes = clientesSnapshot.data ?? const <Cliente>[];
            final cotizaciones =
                cotizacionesSnapshot.data ?? const <Cotizacion>[];
            final cotizados = _clientesDesdeCotizaciones(
              cotizaciones,
              clientes,
            );
            final vistas = <_ClienteVista>[
              for (final cliente in clientes)
                _ClienteVista(cliente: cliente, registrado: true),
              for (final cliente in cotizados)
                _ClienteVista(cliente: cliente, registrado: false),
            ];

            final consulta = _busqueda.trim().toLowerCase();
            final filtrados = vistas
                .where((vista) {
                  final cliente = vista.cliente;
                  final texto =
                      '${cliente.nombre} ${cliente.telefono} '
                              '${cliente.email} ${cliente.documento}'
                          .toLowerCase();
                  return consulta.isEmpty || texto.contains(consulta);
                })
                .toList(growable: false);

            final cargando =
                clientesSnapshot.connectionState == ConnectionState.waiting ||
                cotizacionesSnapshot.connectionState == ConnectionState.waiting;
            final error =
                clientesSnapshot.hasError || cotizacionesSnapshot.hasError;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _barraFiltros(context, cotizados),
                  const SizedBox(height: 14),
                  Expanded(
                    child: error
                        ? AdminErrorState(
                            mensaje:
                                'Revisa la conexión y las reglas de Firestore '
                                'para las colecciones de clientes y '
                                'cotizaciones.',
                            onReintentar: _recargar,
                          )
                        : cargando
                        ? const Center(child: CircularProgressIndicator())
                        : _lista(context, vistas, filtrados),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _barraFiltros(BuildContext context, List<Cliente> cotizados) {
    final buscador = TextField(
      decoration: const InputDecoration(
        labelText: 'Buscar cliente',
        hintText: 'Nombre, teléfono, email o documento',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() => _busqueda = value),
    );

    final acciones = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        if (cotizados.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _importando ? null : () => _importarCotizados(cotizados),
            icon: _importando
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined, size: 19),
            label: Text('Importar ${cotizados.length} cotizado(s)'),
          ),
        FilledButton.icon(
          onPressed: () => _abrirCliente(context),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Nuevo cliente'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            children: <Widget>[
              Expanded(child: buscador),
              const SizedBox(width: 12),
              acciones,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buscador,
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: acciones),
          ],
        );
      },
    );
  }

  /// Obtiene los clientes únicos del historial que aún no están registrados.
  List<Cliente> _clientesDesdeCotizaciones(
    List<Cotizacion> cotizaciones,
    List<Cliente> registrados,
  ) {
    final clavesRegistradas = registrados
        .map((cliente) => cliente.claveContacto)
        .toSet();
    final resultado = <Cliente>[];
    final clavesAgregadas = <String>{};

    for (final cotizacion in cotizaciones) {
      final nombre = cotizacion.clienteNombre.trim();
      if (nombre.isEmpty) continue;

      final candidato = Cliente(
        nombre: nombre,
        telefono: cotizacion.clienteTelefono,
        email: cotizacion.clienteEmail,
      );
      final clave = candidato.claveContacto;
      if (clavesRegistradas.contains(clave) ||
          clavesAgregadas.contains(clave)) {
        continue;
      }
      if (registrados.any((cliente) => cliente.coincideCon(candidato))) {
        continue;
      }

      clavesAgregadas.add(clave);
      resultado.add(candidato);
    }

    return resultado;
  }

  Widget _lista(
    BuildContext context,
    List<_ClienteVista> vistas,
    List<_ClienteVista> filtrados,
  ) {
    if (vistas.isEmpty) {
      return AdminEmptyState(
        icon: Icons.people_outline,
        titulo: 'Aún no hay clientes',
        mensaje:
            'Registra un cliente manualmente o crea una cotización. Los '
            'clientes cotizados también aparecerán aquí.',
        accionEtiqueta: 'Registrar cliente',
        onAccion: () => _abrirCliente(context),
      );
    }

    if (filtrados.isEmpty) {
      return AdminEmptyState(
        icon: Icons.search_off,
        titulo: 'Sin resultados',
        mensaje: 'No hay clientes que coincidan con la búsqueda.',
        accionEtiqueta: 'Limpiar búsqueda',
        onAccion: () => setState(() => _busqueda = ''),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filtrados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final vista = filtrados[index];
        return _ClienteCard(
          cliente: vista.cliente,
          registrado: vista.registrado,
          onEditar: () => _abrirCliente(context, cliente: vista.cliente),
          onEliminar: vista.registrado
              ? () => _eliminarCliente(context, vista.cliente)
              : null,
          onImportar: vista.registrado
              ? null
              : () => _registrarCotizado(vista.cliente),
        );
      },
    );
  }

  Future<void> _importarCotizados(List<Cliente> cotizados) async {
    if (_importando || cotizados.isEmpty) return;
    setState(() => _importando = true);

    try {
      final importados = await widget.service.importarClientes(cotizados);
      if (!mounted) return;
      _mensaje(
        importados == 0
            ? 'No había clientes nuevos por importar.'
            : 'Se importaron $importados cliente(s) desde cotizaciones.',
      );
    } catch (error) {
      if (mounted) {
        _mensaje('No se pudieron importar los clientes.', error: true);
      }
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Future<void> _registrarCotizado(Cliente cliente) async {
    try {
      await widget.service.asegurarCliente(cliente);
      if (mounted) {
        _mensaje('Cliente ${cliente.nombre} guardado en la lista de clientes.');
      }
    } catch (error) {
      if (mounted) {
        _mensaje('No se pudo guardar el cliente cotizado.', error: true);
      }
    }
  }

  Future<void> _abrirCliente(BuildContext context, {Cliente? cliente}) async {
    final esNuevo = cliente?.id == null;
    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          ClienteFormDialog(service: widget.service, cliente: cliente),
    );

    if (guardado == true && mounted) {
      _mensaje(esNuevo ? 'Cliente registrado.' : 'Cliente actualizado.');
    }
  }

  Future<void> _eliminarCliente(BuildContext context, Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar cliente?'),
        content: Text(
          'Se eliminará a "${cliente.nombre}". Las reservas existentes '
          'conservarán el nombre del cliente como referencia.',
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
      await widget.service.eliminarCliente(cliente.id!);
      if (mounted) _mensaje('Cliente eliminado.');
    } catch (error) {
      if (mounted) _mensaje('No se pudo eliminar el cliente.', error: true);
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

class _ClienteVista {
  const _ClienteVista({required this.cliente, required this.registrado});

  final Cliente cliente;

  /// `true` si está en la colección `clientes`; `false` si solo proviene de
  /// una cotización del historial.
  final bool registrado;
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({
    required this.cliente,
    required this.registrado,
    required this.onEditar,
    this.onEliminar,
    this.onImportar,
  });

  final Cliente cliente;
  final bool registrado;
  final VoidCallback onEditar;
  final VoidCallback? onEliminar;
  final VoidCallback? onImportar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inicial = cliente.nombre.trim().isEmpty
        ? '?'
        : cliente.nombre.trim().characters.first.toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.secondaryContainer,
              child: Text(
                inicial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
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
                      Text(cliente.nombre, style: theme.textTheme.titleMedium),
                      if (!registrado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Desde cotizaciones',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!registrado) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Aparece en el historial de cotizaciones. Guárdalo para '
                      'poder asignarle reservas.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: <Widget>[
                      if (cliente.telefono.isNotEmpty)
                        _DatoCliente(
                          icon: Icons.phone_outlined,
                          texto: cliente.telefono,
                        ),
                      if (cliente.email.isNotEmpty)
                        _DatoCliente(
                          icon: Icons.alternate_email,
                          texto: cliente.email,
                        ),
                      if (cliente.documento.isNotEmpty)
                        _DatoCliente(
                          icon: Icons.badge_outlined,
                          texto: cliente.documento,
                        ),
                    ],
                  ),
                  if (cliente.notas.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      cliente.notas,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onImportar != null)
              IconButton(
                tooltip: 'Guardar en clientes',
                onPressed: onImportar,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                color: scheme.primary,
              ),
            IconButton(
              tooltip: registrado
                  ? 'Editar cliente'
                  : 'Registrar con estos datos',
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            if (onEliminar != null)
              IconButton(
                tooltip: 'Eliminar cliente',
                onPressed: onEliminar,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: scheme.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _DatoCliente extends StatelessWidget {
  const _DatoCliente({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          texto,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Formulario para crear o editar un cliente.
class ClienteFormDialog extends StatefulWidget {
  const ClienteFormDialog({super.key, required this.service, this.cliente});

  final ClientesReservasService service;
  final Cliente? cliente;

  @override
  State<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends State<ClienteFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    _nombreController.text = cliente?.nombre ?? '';
    _telefonoController.text = cliente?.telefono ?? '';
    _emailController.text = cliente?.email ?? '';
    _documentoController.text = cliente?.documento ?? '';
    _notasController.text = cliente?.notas ?? '';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _documentoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cliente = Cliente(
      id: widget.cliente?.id,
      nombre: _nombreController.text.trim(),
      telefono: _telefonoController.text.trim(),
      email: _emailController.text.trim(),
      documento: _documentoController.text.trim(),
      notas: _notasController.text.trim(),
    );

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (cliente.id == null) {
        await widget.service.agregarCliente(cliente);
      } else {
        await widget.service.actualizarCliente(cliente);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar el cliente. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o razón social *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Escribe el nombre del cliente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '+51 999 999 999',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return null;
                    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    return regex.hasMatch(email)
                        ? null
                        : 'Escribe un email válido';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documentoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'DNI / RUC / documento',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
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
          label: Text(_guardando ? 'Guardando...' : 'Guardar cliente'),
        ),
      ],
    );
  }
}
