import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';

/// Pantalla bloqueante que aparece cuando la cuenta todavía usa la contraseña
/// temporal. El usuario debe crear una contraseña propia antes de entrar.
class CambiarPasswordScreen extends StatefulWidget {
  const CambiarPasswordScreen({
    super.key,
    required this.authService,
    required this.usuario,
    this.esObligatorio = true,
  });

  final AuthService authService;
  final Usuario usuario;

  /// Cuando es `true` la pantalla bloquea el acceso. Cuando es `false` se
  /// abre desde el menú de la cuenta y se puede cancelar.
  final bool esObligatorio;

  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _nuevaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();

  bool _verPassword = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.authService.cambiarPassword(
        passwordActual: _actualController.text,
        passwordNueva: _nuevaController.text,
      );
      if (!widget.esObligatorio && mounted) {
        Navigator.of(context).pop(true);
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
              : 'No se pudo cambiar la contraseña. Revisa tu conexión.';
        });
      }
    }
  }

  String _traducirError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'La contraseña temporal no es correcta.';
      case 'weak-password':
        return 'La nueva contraseña es demasiado débil.';
      case 'requires-recent-login':
        return 'Vuelve a iniciar sesión e intenta de nuevo.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red.';
      default:
        return 'No se pudo cambiar la contraseña (${error.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
              scheme.secondaryContainer.withValues(alpha: 0.45),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.password_outlined,
                                color: scheme.onPrimary,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.esObligatorio
                                ? 'Crea tu nueva contraseña'
                                : 'Cambiar contraseña',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.esObligatorio
                                ? 'Estás usando una contraseña temporal. Para '
                                      'proteger tu cuenta debes cambiarla antes '
                                      'de entrar a ${AppConfig.nombreApp}.\n\n'
                                      'Cuenta: ${widget.usuario.email}'
                                : 'Actualiza la contraseña de tu cuenta.\n\n'
                                      'Cuenta: ${widget.usuario.email}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _actualController,
                            enabled: !_guardando,
                            obscureText: !_verPassword,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña temporal actual',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Escribe tu contraseña actual';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nuevaController,
                            enabled: !_guardando,
                            obscureText: !_verPassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Nueva contraseña',
                              prefixIcon: const Icon(Icons.lock_reset),
                              suffixIcon: IconButton(
                                tooltip: _verPassword
                                    ? 'Ocultar contraseñas'
                                    : 'Mostrar contraseñas',
                                onPressed: () => setState(
                                  () => _verPassword = !_verPassword,
                                ),
                                icon: Icon(
                                  _verPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.length < 8) {
                                return 'Usa al menos 8 caracteres';
                              }
                              if (password == _actualController.text) {
                                return 'La nueva contraseña debe ser diferente';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmarController,
                            enabled: !_guardando,
                            obscureText: !_verPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _guardar(),
                            decoration: const InputDecoration(
                              labelText: 'Confirmar nueva contraseña',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '') != _nuevaController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    Icons.error_outline,
                                    size: 19,
                                    color: scheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onErrorContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _guardando
                                  ? 'Guardando...'
                                  : 'Guardar nueva contraseña',
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _guardando
                                ? null
                                : widget.esObligatorio
                                ? widget.authService.cerrarSesion
                                : () => Navigator.of(context).pop(false),
                            child: Text(
                              widget.esObligatorio
                                  ? 'Cerrar sesión'
                                  : 'Cancelar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
