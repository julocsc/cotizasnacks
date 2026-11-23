import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/clientes_reservas_service.dart';
import '../../services/cotizacion_service.dart';
import '../../services/empresa_service.dart';
import 'clientes_admin_tab.dart';
import 'empresa_admin_tab.dart';
import 'ingresos_admin_tab.dart';
import 'personal_admin_tab.dart';
import 'productos_admin_tab.dart';
import 'reservas_admin_tab.dart';

/// Secciones del panel de administración.
enum AdminSeccion {
  productos,
  clientes,
  reservas,
  ingresos,
  personal,
  empresa;

  String get etiqueta {
    switch (this) {
      case AdminSeccion.productos:
        return 'Productos';
      case AdminSeccion.clientes:
        return 'Clientes';
      case AdminSeccion.reservas:
        return 'Reservas';
      case AdminSeccion.ingresos:
        return 'Ingresos';
      case AdminSeccion.personal:
        return 'Personal';
      case AdminSeccion.empresa:
        return 'Mi empresa';
    }
  }

  String get descripcion {
    switch (this) {
      case AdminSeccion.productos:
        return 'Productos y categorías';
      case AdminSeccion.clientes:
        return 'Clientes';
      case AdminSeccion.reservas:
        return 'Reservas';
      case AdminSeccion.ingresos:
        return 'Ingresos y utilidad';
      case AdminSeccion.personal:
        return 'Gestión de personal';
      case AdminSeccion.empresa:
        return 'Datos y logotipo de la empresa';
    }
  }

  IconData get icono {
    switch (this) {
      case AdminSeccion.productos:
        return Icons.inventory_2_outlined;
      case AdminSeccion.clientes:
        return Icons.people_outline;
      case AdminSeccion.reservas:
        return Icons.event_available_outlined;
      case AdminSeccion.ingresos:
        return Icons.query_stats_outlined;
      case AdminSeccion.personal:
        return Icons.manage_accounts_outlined;
      case AdminSeccion.empresa:
        return Icons.storefront_outlined;
    }
  }

  bool permitidaPara(Usuario usuario) {
    switch (this) {
      case AdminSeccion.productos:
        return usuario.puedeGestionarProductos;
      case AdminSeccion.clientes:
        return usuario.puedeGestionarClientes;
      case AdminSeccion.reservas:
        return usuario.puedeGestionarReservas;
      case AdminSeccion.ingresos:
        return usuario.puedeVerIngresos;
      case AdminSeccion.personal:
        return usuario.puedeGestionarPersonal;
      case AdminSeccion.empresa:
        return usuario.esAdministrador;
    }
  }

  static List<AdminSeccion> permitidas(Usuario usuario) {
    return AdminSeccion.values
        .where((seccion) => seccion.permitidaPara(usuario))
        .toList(growable: false);
  }
}

/// Panel de administración con las pestañas permitidas para el usuario.
class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.seccionInicial,
    required this.usuario,
    required this.authService,
    required this.catalogoService,
    required this.clientesService,
    required this.cotizacionService,
    required this.empresaService,
  });

  final AdminSeccion seccionInicial;
  final Usuario usuario;
  final AuthService authService;
  final CatalogoService catalogoService;
  final ClientesReservasService clientesService;
  final CotizacionService cotizacionService;
  final EmpresaService empresaService;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<AdminSeccion> _secciones;

  @override
  void initState() {
    super.initState();
    _secciones = AdminSeccion.permitidas(widget.usuario);
    _tabController = TabController(
      length: _secciones.isEmpty ? 1 : _secciones.length,
      vsync: this,
      initialIndex: _indiceInicial(),
    );
  }

  int _indiceInicial() {
    final indice = _secciones.indexOf(widget.seccionInicial);
    return indice >= 0 ? indice : 0;
  }

  @override
  void didUpdateWidget(covariant AdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nuevasSecciones = AdminSeccion.permitidas(widget.usuario);
    final cambiaronSecciones = !_mismaLista(_secciones, nuevasSecciones);

    if (cambiaronSecciones) {
      _secciones = nuevasSecciones;
      _tabController.dispose();
      _tabController = TabController(
        length: _secciones.isEmpty ? 1 : _secciones.length,
        vsync: this,
        initialIndex: _indiceInicial(),
      );
    }

    if (oldWidget.seccionInicial != widget.seccionInicial ||
        cambiaronSecciones) {
      final indice = _indiceInicial();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != indice) {
          _tabController.animateTo(indice);
        }
      });
    }
  }

  static bool _mismaLista(List<AdminSeccion> a, List<AdminSeccion> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Panel de administración',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Gestiona productos, clientes, reservas, ingresos y '
                      'personal.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.usuario.esAdministrador)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Administrador',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_secciones.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline,
                      size: 52,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sin acceso a la administración',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pide al administrador que habilite alguna sección en '
                      'tus permisos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...<Widget>[
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _secciones
                  .map(
                    (seccion) =>
                        Tab(icon: Icon(seccion.icono), text: seccion.etiqueta),
                  )
                  .toList(growable: false),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _secciones
                  .map((seccion) => _contenido(seccion))
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _contenido(AdminSeccion seccion) {
    switch (seccion) {
      case AdminSeccion.productos:
        return ProductosAdminTab(service: widget.catalogoService);
      case AdminSeccion.clientes:
        return ClientesAdminTab(
          service: widget.clientesService,
          cotizacionService: widget.cotizacionService,
        );
      case AdminSeccion.reservas:
        return ReservasAdminTab(
          clientesService: widget.clientesService,
          catalogoService: widget.catalogoService,
          empresaService: widget.empresaService,
          usuarioActual: widget.usuario,
        );
      case AdminSeccion.ingresos:
        return IngresosAdminTab(
          cotizacionService: widget.cotizacionService,
          catalogoService: widget.catalogoService,
          clientesService: widget.clientesService,
        );
      case AdminSeccion.personal:
        return PersonalAdminTab(
          authService: widget.authService,
          usuarioActual: widget.usuario,
        );
      case AdminSeccion.empresa:
        return EmpresaAdminTab(
          service: widget.empresaService,
          usuarioActual: widget.usuario,
        );
    }
  }
}
