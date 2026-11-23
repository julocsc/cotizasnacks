import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../services/auth_service.dart';

/// Pantalla de acceso al cotizador.
///
/// Solo se admite el inicio de sesión con correo y contraseña. Las cuentas
/// nuevas las crea un administrador desde la pestaña "Personal".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.service});

  final AuthService service;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _verPassword = false;
  bool _guardando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    try {
      await widget.service.iniciarSesion(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _mensaje(_traducirError(error));
    } catch (_) {
      if (mounted) {
        _mensaje('No se pudo iniciar sesión. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _restablecerContrasena() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _mensaje('Escribe tu correo para enviarte el enlace de recuperación.');
      return;
    }

    try {
      await widget.service.enviarCorreoRestablecimiento(email);
      if (mounted) {
        _mensaje('Te enviamos un enlace para restablecer tu contraseña.');
      }
    } catch (_) {
      if (mounted) {
        _mensaje('No se pudo enviar el correo de recuperación.');
      }
    }
  }

  String _traducirError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red.';
      case 'operation-not-allowed':
        return 'El acceso por correo no está habilitado en Firebase.';
      default:
        return 'No se pudo iniciar sesión. Intenta de nuevo.';
    }
  }

  void _mensaje(String texto) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto, style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
      );
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
                constraints: const BoxConstraints(maxWidth: 430),
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
                                Icons.request_quote_outlined,
                                color: scheme.onPrimary,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            AppConfig.nombreApp,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Acceso para personal autorizado',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            enabled: !_guardando,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const <String>[AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'nombre@empresa.com',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return 'Escribe tu correo';
                              }
                              final valido = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email);
                              if (!valido) return 'Correo no válido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !_guardando,
                            obscureText: !_verPassword,
                            autofillHints: const <String>[
                              AutofillHints.password,
                            ],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _iniciarSesion(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _verPassword
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
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
                              if ((value ?? '').isEmpty) {
                                return 'Escribe tu contraseña';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _guardando ? null : _iniciarSesion,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _guardando ? 'Verificando...' : 'Iniciar sesión',
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _guardando
                                ? null
                                : _restablecerContrasena,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 19,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'El administrador crea las cuentas desde '
                                    'la pestaña Personal del panel de '
                                    'administración.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
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
