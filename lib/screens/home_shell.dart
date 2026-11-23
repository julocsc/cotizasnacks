import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/catalogo_service.dart';
import '../services/clientes_reservas_service.dart';
import '../services/cotizacion_service.dart';
import '../services/empresa_service.dart';
import 'admin/admin_screen.dart';
import 'cambiar_password_screen.dart';
import 'crear_cotizacion_screen.dart';
import 'historial_screen.dart';
import 'impresora_screen.dart';

enum _TipoSeccion { crear, historial, impresora, admin }

/// Contenedor principal con navegación adaptativa y permisos por usuario.
///
/// - `Drawer` en móviles.
/// - `NavigationRail` en tablets y escritorio/web.
/// - `NavigationBar` en móviles.
///
/// Las secciones se generan a partir de los permisos del perfil, por lo que
/// un cambio hecho por el administrador se refleja en tiempo real.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.usuario,
    required this.authService,
  });

  final Usuario usuario;
  final AuthService authService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CotizacionService _service = CotizacionService();
  final CatalogoService _catalogoService = CatalogoService();
  final ClientesReservasService _clientesService = ClientesReservasService();
  final EmpresaService _empresaService = EmpresaService();

  int _indice = 0;
  AdminSeccion _adminSeccion = AdminSeccion.productos;

  Usuario get _usuario => widget.usuario;

  List<_TipoSeccion> get _tipos {
    return <_TipoSeccion>[
      if (_usuario.puedeCrearCotizaciones) _TipoSeccion.crear,
      if (_usuario.puedeVerHistorial) _TipoSeccion.historial,
      if (_usuario.puedeGestionarReservas) _TipoSeccion.impresora,
      if (_usuario.tieneAccesoAdministracion) _TipoSeccion.admin,
    ];
  }

  int _indiceDe(_TipoSeccion tipo) => _tipos.indexOf(tipo);

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final total = _tipos.length;
    if (total == 0) {
      _indice = 0;
    } else if (_indice >= total) {
      _indice = total - 1;
    }

    if (!_usuario.tieneAccesoAdministracion) {
      _adminSeccion = AdminSeccion.productos;
    } else if (!_adminSeccion.permitidaPara(_usuario)) {
      _adminSeccion = AdminSeccion.permitidas(_usuario).first;
    }
  }

  void _irACrear() {
    final indice = _indiceDe(_TipoSeccion.crear);
    if (indice >= 0) setState(() => _indice = indice);
  }

  void _irAlHistorial() {
    final indice = _indiceDe(_TipoSeccion.historial);
    if (indice >= 0) {
      setState(() => _indice = indice);
    } else {
      _mensaje('Cotización guardada. No tienes permiso para ver el historial.');
    }
  }

  void _seleccionarSeccion(_TipoSeccion tipo, {AdminSeccion? adminSeccion}) {
    _scaffoldKey.currentState?.closeDrawer();
    final indice = _indiceDe(tipo);
    if (indice < 0) return;
    setState(() {
      _indice = indice;
      if (tipo == _TipoSeccion.admin && adminSeccion != null) {
        _adminSeccion = adminSeccion;
      }
    });
  }

  Future<void> _cerrarSesion() async {
    await widget.authService.cerrarSesion();
  }

  Future<void> _cambiarPassword() async {
    _scaffoldKey.currentState?.closeDrawer();
    final actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CambiarPasswordScreen(
          authService: widget.authService,
          usuario: _usuario,
          esObligatorio: false,
        ),
      ),
    );
    if (actualizado == true) {
      _mensaje('Contraseña actualizada correctamente.');
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mostrarRail = constraints.maxWidth >= 900;
        final railExtendido = constraints.maxWidth >= 1220;
        final tipos = _tipos;
        final indiceSeguro = tipos.isEmpty
            ? 0
            : _indice.clamp(0, tipos.length - 1);

        return Scaffold(
          key: _scaffoldKey,
          drawer: _construirDrawer(context),
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.request_quote_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                const Text(AppConfig.nombreApp),
              ],
            ),
            actions: <Widget>[
              Tooltip(
                message: 'Datos sincronizados en tiempo real',
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.cloud_done_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Cuenta de ${_usuario.nombreVisible}',
                onSelected: (value) {
                  if (value == 'password') {
                    _cambiarPassword();
                  } else if (value == 'salir') {
                    _cerrarSesion();
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    enabled: false,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text(_usuario.inicial)),
                      title: Text(_usuario.nombreVisible),
                      subtitle: Text(_usuario.email),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'password',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.lock_reset),
                      title: Text('Cambiar contraseña'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'salir',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout),
                      title: Text('Cerrar sesión'),
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, left: 4),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    child: Text(
                      _usuario.inicial,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: tipos.isEmpty
              ? _sinPermisos(context)
              : Row(
                  children: <Widget>[
                    if (mostrarRail) ...<Widget>[
                      NavigationRail(
                        selectedIndex: indiceSeguro,
                        extended: railExtendido,
                        labelType: railExtendido
                            ? null
                            : NavigationRailLabelType.all,
                        groupAlignment: -0.85,
                        onDestinationSelected: (index) =>
                            setState(() => _indice = index),
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 22),
                          child: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            child: Icon(
                              Icons.business_center_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                        destinations: tipos
                            .map(
                              (tipo) => NavigationRailDestination(
                                icon: Icon(_icono(tipo)),
                                selectedIcon: Icon(_iconoSeleccionado(tipo)),
                                label: Text(_etiqueta(tipo)),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: IndexedStack(
                        index: indiceSeguro,
                        children: tipos
                            .map((tipo) => _contenido(tipo))
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: mostrarRail || tipos.isEmpty
              ? null
              : NavigationBar(
                  selectedIndex: indiceSeguro,
                  onDestinationSelected: (index) =>
                      setState(() => _indice = index),
                  destinations: tipos
                      .map(
                        (tipo) => NavigationDestination(
                          icon: Icon(_icono(tipo)),
                          selectedIcon: Icon(_iconoSeleccionado(tipo)),
                          label: _etiqueta(tipo),
                        ),
                      )
                      .toList(growable: false),
                ),
        );
      },
    );
  }

  Widget _contenido(_TipoSeccion tipo) {
    switch (tipo) {
      case _TipoSeccion.crear:
        return CrearCotizacionScreen(
          service: _service,
          catalogoService: _catalogoService,
          onCotizacionGuardada: _irAlHistorial,
          usuarioActual: _usuario,
        );
      case _TipoSeccion.historial:
        return HistorialScreen(
          service: _service,
          clientesService: _clientesService,
          onCrearCotizacion: _irACrear,
          usuarioActual: _usuario,
          puedeCrearCotizacion: _usuario.puedeCrearCotizaciones,
          puedeConvertirEnReserva: _usuario.puedeGestionarReservas,
          puedeEliminar: _usuario.puedeCrearCotizaciones,
        );
      case _TipoSeccion.impresora:
        return ImpresoraScreen(
          clientesService: _clientesService,
          catalogoService: _catalogoService,
          empresaService: _empresaService,
        );
      case _TipoSeccion.admin:
        return AdminScreen(
          seccionInicial: _adminSeccion,
          usuario: _usuario,
          authService: widget.authService,
          catalogoService: _catalogoService,
          clientesService: _clientesService,
          cotizacionService: _service,
          empresaService: _empresaService,
        );
    }
  }

  Widget _sinPermisos(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 54,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text('Sin permisos asignados', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta está activa, pero el administrador aún no te '
                'habilitó ninguna sección. Cuando lo haga, la app se '
                'actualizará automáticamente.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tipos = _tipos;
    final seccionesAdmin = AdminSeccion.permitidas(_usuario);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.request_quote_outlined,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppConfig.nombreApp,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Cotizaciones y administración',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      _usuario.inicial,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _usuario.nombreVisible,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          _usuario.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          RolUsuario.etiqueta(_usuario.rol),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _usuario.esAdministrador
                                ? scheme.primary
                                : scheme.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            if (tipos.contains(_TipoSeccion.crear))
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Nueva cotización'),
                selected: _indice == _indiceDe(_TipoSeccion.crear),
                onTap: () => _seleccionarSeccion(_TipoSeccion.crear),
              ),
            if (tipos.contains(_TipoSeccion.historial))
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Historial'),
                selected: _indice == _indiceDe(_TipoSeccion.historial),
                onTap: () => _seleccionarSeccion(_TipoSeccion.historial),
              ),
            if (tipos.contains(_TipoSeccion.impresora))
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Impresora'),
                subtitle: const Text('Boletas y gastos'),
                selected: _indice == _indiceDe(_TipoSeccion.impresora),
                onTap: () => _seleccionarSeccion(_TipoSeccion.impresora),
              ),
            if (seccionesAdmin.isNotEmpty) ...<Widget>[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Text(
                  'ADMINISTRACIÓN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              for (final seccion in seccionesAdmin)
                ListTile(
                  leading: Icon(seccion.icono),
                  title: Text(seccion.descripcion),
                  selected:
                      _indice == _indiceDe(_TipoSeccion.admin) &&
                      _adminSeccion == seccion,
                  onTap: () => _seleccionarSeccion(
                    _TipoSeccion.admin,
                    adminSeccion: seccion,
                  ),
                ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text(
                'Los cambios se sincronizan en tiempo real con Firestore.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Cambiar contraseña'),
              onTap: _cambiarPassword,
            ),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                'Cerrar sesión',
                style: TextStyle(color: scheme.error),
              ),
              onTap: _cerrarSesion,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icono(_TipoSeccion tipo) {
    switch (tipo) {
      case _TipoSeccion.crear:
        return Icons.add_circle_outline;
      case _TipoSeccion.historial:
        return Icons.history_outlined;
      case _TipoSeccion.impresora:
        return Icons.print_outlined;
      case _TipoSeccion.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  static IconData _iconoSeleccionado(_TipoSeccion tipo) {
    switch (tipo) {
      case _TipoSeccion.crear:
        return Icons.add_circle;
      case _TipoSeccion.historial:
        return Icons.history;
      case _TipoSeccion.impresora:
        return Icons.print;
      case _TipoSeccion.admin:
        return Icons.admin_panel_settings;
    }
  }

  static String _etiqueta(_TipoSeccion tipo) {
    switch (tipo) {
      case _TipoSeccion.crear:
        return 'Nueva';
      case _TipoSeccion.historial:
        return 'Historial';
      case _TipoSeccion.impresora:
        return 'Impresora';
      case _TipoSeccion.admin:
        return 'Admin';
    }
  }
}
