import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_config.dart';
import '../services/auth_service.dart';
import 'cambiar_password_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Decide qué pantalla mostrar según el estado de Firebase Auth y el perfil
/// del usuario en Firestore.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  late final Stream<EstadoSesion> _estadoStream;

  @override
  void initState() {
    super.initState();
    _estadoStream = _authService.estadoSesion;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EstadoSesion>(
      stream: _estadoStream,
      builder: (context, snapshot) {
        final estado = snapshot.data;

        if (snapshot.hasError) {
          return _EstadoCuentaScreen(
            icono: Icons.cloud_off_outlined,
            titulo: 'No se pudo verificar tu cuenta',
            mensaje:
                'Revisa la conexión y las reglas de Firestore de la colección '
                'usuarios. Detalle: ${snapshot.error}',
            onSalir: _authService.cerrarSesion,
          );
        }

        if (estado == null) {
          return const _CargandoSesion();
        }

        return switch (estado) {
          SesionCerrada() => LoginScreen(service: _authService),
          SesionSinPerfil(:final uid, :final email) => _EstadoCuentaScreen(
            icono: Icons.person_off_outlined,
            titulo: 'Cuenta sin perfil autorizado',
            mensaje:
                'La cuenta $email inició sesión correctamente, pero todavía '
                'no fue agregada al personal del cotizador. Pide al '
                'administrador que te registre en la pestaña Personal. '
                'Esta pantalla se actualizará automáticamente.',
            uid: uid,
            onSalir: _authService.cerrarSesion,
          ),
          SesionActiva(:final usuario) when !usuario.activo =>
            _EstadoCuentaScreen(
              icono: Icons.block_outlined,
              titulo: 'Acceso desactivado',
              mensaje:
                  'El administrador desactivó el acceso de '
                  '${usuario.email}. Contacta al administrador si crees que '
                  'es un error.',
              onSalir: _authService.cerrarSesion,
            ),
          SesionActiva(:final usuario) when usuario.debeCambiarPassword =>
            CambiarPasswordScreen(authService: _authService, usuario: usuario),
          SesionActiva(:final usuario) => HomeShell(
            usuario: usuario,
            authService: _authService,
          ),
        };
      },
    );
  }
}

class _CargandoSesion extends StatelessWidget {
  const _CargandoSesion();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.request_quote_outlined,
                color: theme.colorScheme.onPrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppConfig.nombreApp,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla informativa para cuentas sin perfil, desactivadas o con errores.
class _EstadoCuentaScreen extends StatelessWidget {
  const _EstadoCuentaScreen({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.onSalir,
    this.uid,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final String? uid;
  final Future<void> Function() onSalir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.nombreApp)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(icono, size: 46, color: scheme.error),
                    const SizedBox(height: 14),
                    Text(titulo, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      mensaje,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (uid != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        'UID de tu cuenta',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: SelectableText(
                                uid!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar UID',
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: uid!),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('UID copiado.')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onSalir,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
