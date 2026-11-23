import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../utils/invitacion.dart';
import '../../utils/notificaciones_reserva.dart';
import 'admin_empty_state.dart';

/// Pestaña exclusiva del administrador para dar acceso al personal.
class PersonalAdminTab extends StatefulWidget {
  const PersonalAdminTab({
    super.key,
    required this.authService,
    required this.usuarioActual,
  });

  final AuthService authService;
  final Usuario usuarioActual;

  @override
  State<PersonalAdminTab> createState() => _PersonalAdminTabState();
}

class _PersonalAdminTabState extends State<PersonalAdminTab> {
  late Stream<List<Usuario>> _usuariosStream;

  @override
  void initState() {
    super.initState();
    _usuariosStream = widget.authService.escucharUsuarios();
  }

  void _recargar() {
    setState(() {
      _usuariosStream = widget.authService.escucharUsuarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.usuarioActual.esAdministrador) {
      return const AdminEmptyState(
        icon: Icons.lock_outline,
        titulo: 'Acceso exclusivo del administrador',
        mensaje:
            'Solo un administrador puede agregar personal y editar sus '
            'permisos.',
        accionEtiqueta: 'Volver',
        onAccion: _noop,
      );
    }

    return StreamBuilder<List<Usuario>>(
      stream: _usuariosStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: AdminErrorState(
              mensaje:
                  'No se pudo leer la colección usuarios. Revisa la conexión y '
                  'las reglas de Firestore.',
              onReintentar: _recargar,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final usuarios = snapshot.data ?? const <Usuario>[];
        final activos = usuarios.where((usuario) => usuario.activo).length;
        final admins = usuarios
            .where((usuario) => usuario.esAdministrador)
            .length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _barraSuperior(context, usuarios.length, activos, admins),
              const SizedBox(height: 14),
              Expanded(child: _lista(context, usuarios)),
            ],
          ),
        );
      },
    );
  }

  Widget _barraSuperior(
    BuildContext context,
    int total,
    int activos,
    int admins,
  ) {
    final resumen = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _contador(context, 'Total', total, Icons.groups_outlined),
        _contador(context, 'Activos', activos, Icons.check_circle_outline),
        _contador(context, 'Admins', admins, Icons.shield_outlined),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final boton = FilledButton.icon(
          onPressed: () => _abrirFormulario(context),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Agregar personal'),
        );

        if (constraints.maxWidth >= 720) {
          return Row(
            children: <Widget>[
              Expanded(child: resumen),
              const SizedBox(width: 12),
              boton,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            resumen,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: boton),
          ],
        );
      },
    );
  }

  Widget _contador(
    BuildContext context,
    String etiqueta,
    int valor,
    IconData icono,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icono, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$etiqueta: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$valor',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context, List<Usuario> usuarios) {
    if (usuarios.isEmpty) {
      return AdminEmptyState(
        icon: Icons.people_outline,
        titulo: 'Aún no hay personal registrado',
        mensaje:
            'Agrega el correo de cada persona que debe usar el cotizador. Tú '
            'decides qué permisos tiene cada una.',
        accionEtiqueta: 'Agregar personal',
        onAccion: () => _abrirFormulario(context),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: usuarios.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final usuario = usuarios[index];
        return _PersonalCard(
          usuario: usuario,
          esUsuarioActual: usuario.uid == widget.usuarioActual.uid,
          onEditar: () => _abrirFormulario(context, usuario: usuario),
          onRestablecer: () => _restablecerContrasena(usuario),
          onCambiarEstado: () => _cambiarEstado(usuario),
          onEliminar: () => _eliminar(usuario),
        );
      },
    );
  }

  Future<void> _abrirFormulario(
    BuildContext context, {
    Usuario? usuario,
  }) async {
    final resultado = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PersonalFormDialog(
        service: widget.authService,
        usuarioActual: widget.usuarioActual,
        usuario: usuario,
      ),
    );

    if (!mounted || resultado == null) return;

    if (resultado is InvitacionPersonal) {
      final correoAbierto = await _abrirInvitacion(resultado);
      if (!mounted) return;
      if (resultado.cuentaRestaurada) {
        _mensaje(
          correoAbierto
              ? 'Acceso restaurado. Revisa y envía la invitación desde tu '
                    'correo.'
              : 'Acceso restaurado. Envía el correo de restablecimiento al '
                    'usuario.',
        );
      } else {
        _mensaje(
          correoAbierto
              ? 'Acceso creado. Revisa y envía la invitación desde tu correo.'
              : 'Acceso creado. Copia la contraseña temporal para compartirla.',
        );
      }
      await _mostrarCredenciales(resultado, correoAbierto: correoAbierto);
    } else if (resultado == true) {
      _mensaje('Datos y permisos actualizados.');
    }
  }

  Future<bool> _abrirInvitacion(InvitacionPersonal invitacion) async {
    final uri = crearUriInvitacion(
      email: invitacion.usuario.email,
      nombre: invitacion.usuario.nombre,
      passwordTemporal: invitacion.passwordTemporal,
      cuentaRestaurada: invitacion.cuentaRestaurada,
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  Future<void> _mostrarCredenciales(
    InvitacionPersonal invitacion, {
    required bool correoAbierto,
  }) async {
    if (!mounted) return;
    final email = invitacion.usuario.email;
    final password = invitacion.passwordTemporal;
    final restaurada = invitacion.cuentaRestaurada;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: <Widget>[
            Icon(
              restaurada
                  ? Icons.restore_outlined
                  : Icons.mark_email_read_outlined,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                restaurada ? 'Acceso restaurado' : 'Invitación de acceso',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                restaurada
                    ? 'El correo ya tenía una cuenta de Firebase Auth. '
                          'Restauramos su perfil y enviamos un enlace para '
                          'restablecer la contraseña.'
                    : correoAbierto
                    ? 'Se abrió tu cliente de correo con la invitación. Envía '
                          'el mensaje para que la persona reciba sus datos.'
                    : 'No se pudo abrir el cliente de correo. Copia los datos '
                          'y envíalos por el medio que prefieras.',
              ),
              const SizedBox(height: 14),
              _datoCredencial(dialogContext, 'Correo', email),
              if (!restaurada) ...<Widget>[
                const SizedBox(height: 8),
                _datoCredencial(dialogContext, 'Contraseña temporal', password),
              ],
              const SizedBox(height: 12),
              Text(
                restaurada
                    ? 'Si la persona no recuerda su contraseña anterior, debe '
                          'usar el enlace de restablecimiento que recibió por '
                          'correo. También puedes reenviarlo desde la lista de '
                          'personal.'
                    : 'En el primer inicio de sesión la app le pedirá crear una '
                          'nueva contraseña antes de entrar.',
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () async {
              final abierto = await _abrirInvitacion(invitacion);
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    abierto
                        ? 'Se abrió el correo con la invitación.'
                        : 'No se pudo abrir el cliente de correo.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.send_outlined, size: 18),
            label: Text(restaurada ? 'Reenviar aviso' : 'Reenviar invitación'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: restaurada
                      ? 'Correo: $email\n\n'
                            'Tu acceso al cotizador fue restaurado. Revisa el '
                            'correo de restablecimiento de contraseña.'
                      : 'Correo: $email\n'
                            'Contraseña temporal: $password\n\n'
                            'En tu primer inicio de sesión la app te pedirá '
                            'crear una nueva contraseña.',
                ),
              );
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    restaurada ? 'Datos copiados.' : 'Credenciales copiadas.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _datoCredencial(BuildContext context, String etiqueta, String valor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            valor,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restablecerContrasena(Usuario usuario) async {
    try {
      await widget.authService.enviarCorreoRestablecimiento(usuario.email);
      if (mounted) {
        _mensaje('Enviamos un enlace de restablecimiento a ${usuario.email}.');
      }
    } catch (_) {
      if (mounted) {
        _mensaje(
          'No se pudo enviar el correo de restablecimiento.',
          error: true,
        );
      }
    }
  }

  Future<void> _cambiarEstado(Usuario usuario) async {
    if (usuario.uid == widget.usuarioActual.uid) {
      _mensaje('No puedes desactivar tu propia cuenta.', error: true);
      return;
    }

    final nuevoEstado = !usuario.activo;
    if (!nuevoEstado) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Quitar acceso?'),
          content: Text(
            '${usuario.nombreVisible} (${usuario.email}) no podrá iniciar '
            'sesión en el cotizador hasta que lo actives de nuevo.',
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
              child: const Text('Quitar acceso'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    try {
      await widget.authService.cambiarEstadoPersonal(usuario.uid, nuevoEstado);
      if (mounted) {
        _mensaje(nuevoEstado ? 'Acceso activado.' : 'Acceso desactivado.');
      }
    } catch (error) {
      if (mounted) {
        _mensaje(
          error is StateError ? error.message : 'No se pudo cambiar el acceso.',
          error: true,
        );
      }
    }
  }

  Future<void> _eliminar(Usuario usuario) async {
    if (usuario.uid == widget.usuarioActual.uid) {
      _mensaje('No puedes eliminar tu propia cuenta.', error: true);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar acceso'),
        content: Text(
          'Se eliminará el perfil de ${usuario.nombreVisible} '
          '(${usuario.email}). La persona perderá el acceso al cotizador de '
          'inmediato.\n\n'
          'La cuenta de Firebase Authentication se conserva. Si vuelves a '
          'agregar el mismo correo, la app restaurará el perfil y enviará un '
          'enlace para restablecer la contraseña.',
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
      await widget.authService.eliminarPersonal(usuario);
      if (mounted) {
        _mensaje('Perfil de ${usuario.nombreVisible} eliminado.');
      }
    } catch (error) {
      if (mounted) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          _mensaje(
            'Firestore rechazó la eliminación. Publica las reglas actualizadas '
            'con: firebase deploy --only firestore:rules',
            error: true,
          );
        } else {
          _mensaje(
            error is StateError
                ? error.message
                : 'No se pudo eliminar el acceso. Intenta de nuevo.',
            error: true,
          );
        }
      }
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

  static void _noop() {}
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({
    required this.usuario,
    required this.esUsuarioActual,
    required this.onEditar,
    required this.onRestablecer,
    required this.onCambiarEstado,
    required this.onEliminar,
  });

  final Usuario usuario;
  final bool esUsuarioActual;
  final VoidCallback onEditar;
  final VoidCallback onRestablecer;
  final VoidCallback onCambiarEstado;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activo = usuario.activo;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 23,
              backgroundColor: usuario.esAdministrador
                  ? scheme.primaryContainer
                  : scheme.secondaryContainer,
              child: Text(
                usuario.inicial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: usuario.esAdministrador
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
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
                        usuario.nombreVisible,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (esUsuarioActual)
                        _badge(context, 'Tú', scheme.primary),
                      _badge(
                        context,
                        RolUsuario.etiqueta(usuario.rol),
                        usuario.esAdministrador
                            ? scheme.primary
                            : scheme.secondary,
                      ),
                      _badge(
                        context,
                        activo ? 'Activo' : 'Inactivo',
                        activo ? scheme.tertiary : scheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    usuario.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (usuario.telefono.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'Celular: ${usuario.telefono.trim()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    usuario.esAdministrador
                        ? 'Acceso completo a todas las secciones.'
                        : _resumenPermisos(usuario),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: onEditar,
                        icon: const Icon(
                          Icons.manage_accounts_outlined,
                          size: 18,
                        ),
                        label: const Text('Editar permisos'),
                      ),
                      IconButton(
                        tooltip: 'Enviar correo de restablecimiento',
                        onPressed: onRestablecer,
                        icon: const Icon(Icons.lock_reset, size: 20),
                      ),
                      Switch.adaptive(
                        value: activo,
                        onChanged: esUsuarioActual
                            ? null
                            : (_) => onCambiarEstado(),
                      ),
                      IconButton(
                        tooltip: esUsuarioActual
                            ? 'No puedes eliminar tu propia cuenta'
                            : 'Eliminar acceso',
                        onPressed: esUsuarioActual ? null : onEliminar,
                        icon: Icon(
                          Icons.person_remove_outlined,
                          size: 20,
                          color: esUsuarioActual ? null : scheme.error,
                        ),
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

  Widget _badge(BuildContext context, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  static String _resumenPermisos(Usuario usuario) {
    final permisos = <String>[
      if (usuario.permisos.crearCotizaciones) 'Cotizaciones',
      if (usuario.permisos.verHistorial) 'Historial',
      if (usuario.permisos.gestionarProductos) 'Productos',
      if (usuario.permisos.gestionarClientes) 'Clientes',
      if (usuario.permisos.gestionarReservas) 'Reservas',
      if (usuario.permisos.verIngresos) 'Ingresos',
    ];
    if (permisos.isEmpty) return 'Sin permisos asignados.';
    return 'Permisos: ${permisos.join(', ')}.';
  }
}

class _PersonalFormDialog extends StatefulWidget {
  const _PersonalFormDialog({
    required this.service,
    required this.usuarioActual,
    this.usuario,
  });

  final AuthService service;
  final Usuario usuarioActual;
  final Usuario? usuario;

  @override
  State<_PersonalFormDialog> createState() => _PersonalFormDialogState();
}

class _PersonalFormDialogState extends State<_PersonalFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late String _rol;
  late bool _activo;
  late PermisosUsuario _permisos;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.usuario != null;
  bool get _editandoPropiaCuenta =>
      widget.usuario?.uid == widget.usuarioActual.uid;
  bool get _esAdminSeleccionado => _rol == RolUsuario.administrador;

  @override
  void initState() {
    super.initState();
    final usuario = widget.usuario;
    _nombreController.text = usuario?.nombre ?? '';
    _emailController.text = usuario?.email ?? '';
    _telefonoController.text = usuario?.telefono ?? '';
    _passwordController.text = _generarPassword();
    _rol = usuario?.rol ?? RolUsuario.personal;
    _activo = usuario?.activo ?? true;
    _permisos = usuario == null || usuario.esAdministrador
        ? PermisosUsuario.personal
        : usuario.permisos;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static String _generarPassword() {
    const caracteres =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List<String>.generate(
      10,
      (_) => caracteres[random.nextInt(caracteres.length)],
    ).join();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        final actual = widget.usuario!;
        if (_editandoPropiaCuenta &&
            (_rol != RolUsuario.administrador || !_activo)) {
          throw StateError(
            'No puedes quitarte el rol de administrador ni desactivar tu '
            'propia cuenta.',
          );
        }

        final actualizado = actual.copyWith(
          nombre: _nombreController.text.trim(),
          telefono: _telefonoController.text.trim(),
          rol: _rol,
          activo: _activo,
          permisos: _esAdminSeleccionado
              ? PermisosUsuario.administrador
              : _permisos,
        );
        await widget.service.actualizarPersonal(actualizado);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final password = _passwordController.text;
        final invitacion = await widget.service.crearPersonal(
          nombre: _nombreController.text,
          email: _emailController.text,
          telefono: _telefonoController.text.trim(),
          password: password,
          permisos: _esAdminSeleccionado
              ? PermisosUsuario.administrador
              : _permisos,
          rol: _rol,
        );
        if (mounted) {
          Navigator.of(context).pop(invitacion);
        }
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = _traducirError(error);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = error is StateError
              ? error.message
              : 'No se pudo guardar. Revisa la conexión e intenta de nuevo.';
        });
      }
    }
  }

  String _traducirError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'El acceso por correo no está habilitado en Firebase.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'No se pudo crear la cuenta (${error.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar personal' : 'Agregar personal'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nombreController,
                  enabled: !_guardando,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Escribe el nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  enabled: !_guardando && !_esEdicion,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico *',
                    prefixIcon: const Icon(Icons.mail_outline),
                    helperText: _esEdicion
                        ? 'El correo se administra desde Firebase Auth y no '
                              'se puede cambiar aquí.'
                        : 'Con este correo iniciará sesión en el cotizador.',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Escribe el correo';
                    final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email);
                    if (!valido) return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoController,
                  enabled: !_guardando,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Celular con código de país *',
                    prefixIcon: Icon(Icons.phone_iphone_outlined),
                    hintText: '+51 999 999 999',
                    helperText:
                        'Se usa para enviar las notificaciones de reservas '
                        'por WhatsApp.',
                  ),
                  validator: (value) {
                    final telefono = value?.trim() ?? '';
                    if (telefono.isEmpty) {
                      return 'Escribe el celular con código de país';
                    }
                    if (!telefono.startsWith('+')) {
                      return 'Incluye el código de país, por ejemplo +51';
                    }
                    if (!telefonoWhatsAppValido(telefono)) {
                      return 'Número de celular no válido';
                    }
                    return null;
                  },
                ),
                if (!_esEdicion) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _passwordController,
                          enabled: !_guardando,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña temporal *',
                            prefixIcon: Icon(Icons.password_outlined),
                            helperText:
                                'Se enviará por correo como invitación. La '
                                'persona deberá cambiarla al entrar.',
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Generar otra contraseña',
                        onPressed: _guardando
                            ? null
                            : () => setState(
                                () => _passwordController.text =
                                    _generarPassword(),
                              ),
                        icon: const Icon(Icons.autorenew),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _rol,
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    helperText: _editandoPropiaCuenta
                        ? 'No puedes quitarte tu propio rol de administrador.'
                        : null,
                  ),
                  items: RolUsuario.todos
                      .map(
                        (rol) => DropdownMenuItem<String>(
                          value: rol,
                          child: Text(RolUsuario.etiqueta(rol)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _guardando || _editandoPropiaCuenta
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _rol = value);
                          }
                        },
                ),
                if (_esEdicion) ...<Widget>[
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Acceso activo'),
                    subtitle: Text(
                      _activo
                          ? 'Puede iniciar sesión en el cotizador.'
                          : 'No puede iniciar sesión hasta que lo actives.',
                    ),
                    value: _activo,
                    onChanged: _guardando || _editandoPropiaCuenta
                        ? null
                        : (value) => setState(() => _activo = value),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Permisos',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _esAdminSeleccionado
                      ? 'El rol Administrador tiene acceso completo y no '
                            'requiere configurar permisos.'
                      : 'Marca solo las secciones a las que tendrá acceso.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _switchPermiso(
                  'Crear cotizaciones',
                  'Formulario de nueva cotización',
                  Icons.add_circle_outline,
                  _permisos.crearCotizaciones,
                  (value) => setState(
                    () => _permisos = _permisos.copyWith(
                      crearCotizaciones: value,
                    ),
                  ),
                ),
                _switchPermiso(
                  'Ver historial',
                  'Historial de cotizaciones y PDF',
                  Icons.history_outlined,
                  _permisos.verHistorial,
                  (value) => setState(
                    () => _permisos = _permisos.copyWith(verHistorial: value),
                  ),
                ),
                _switchPermiso(
                  'Productos y categorías',
                  'Pestaña de administración del catálogo',
                  Icons.inventory_2_outlined,
                  _permisos.gestionarProductos,
                  (value) => setState(
                    () => _permisos = _permisos.copyWith(
                      gestionarProductos: value,
                    ),
                  ),
                ),
                _switchPermiso(
                  'Clientes',
                  'Pestaña de administración de clientes',
                  Icons.people_outline,
                  _permisos.gestionarClientes,
                  (value) => setState(
                    () => _permisos = _permisos.copyWith(
                      gestionarClientes: value,
                    ),
                  ),
                ),
                _switchPermiso(
                  'Reservas',
                  'Pestaña de administración de reservas',
                  Icons.event_available_outlined,
                  _permisos.gestionarReservas,
                  (value) => setState(
                    () => _permisos = _permisos.copyWith(
                      gestionarReservas: value,
                    ),
                  ),
                ),
                _switchPermiso(
                  'Ver ingresos',
                  'Pestaña de ventas, costos y utilidad',
                  Icons.query_stats_outlined,
                  _permisos.verIngresos,
                  (value) => setState(
                    () => _permisos = _permisos.copyWith(verIngresos: value),
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
              : const Icon(Icons.save_outlined),
          label: Text(_guardando ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _switchPermiso(
    String titulo,
    String subtitulo,
    IconData icono,
    bool valor,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icono, size: 20),
      title: Text(titulo),
      subtitle: Text(subtitulo),
      value: _esAdminSeleccionado ? true : valor,
      onChanged: _guardando || _esAdminSeleccionado
          ? null
          : (value) => onChanged(value),
    );
  }
}
