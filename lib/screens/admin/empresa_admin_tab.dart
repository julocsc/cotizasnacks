import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/empresa_config.dart';
import '../../models/usuario.dart';
import '../../services/empresa_service.dart';
import '../../widgets/empresa_logo.dart';
import 'admin_empty_state.dart';

/// Pestaña del administrador para personalizar los datos de la empresa emisora.
///
/// Estos valores se usan en el encabezado y el pie del PDF de cada cotización.
class EmpresaAdminTab extends StatefulWidget {
  const EmpresaAdminTab({
    super.key,
    required this.service,
    required this.usuarioActual,
  });

  final EmpresaService service;
  final Usuario usuarioActual;

  @override
  State<EmpresaAdminTab> createState() => _EmpresaAdminTabState();
}

class _EmpresaAdminTabState extends State<EmpresaAdminTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _esloganController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _telefonoAdministradorController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _sitioWebController = TextEditingController();

  StreamSubscription<EmpresaConfig>? _suscripcion;
  String _logoBase64 = '';
  bool _cargado = false;
  bool _guardando = false;
  bool _cargandoLogo = false;
  String? _errorCarga;
  String? _errorGuardado;

  @override
  void initState() {
    super.initState();
    _escuchar();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _nombreController.dispose();
    _esloganController.dispose();
    _telefonoController.dispose();
    _telefonoAdministradorController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _sitioWebController.dispose();
    super.dispose();
  }

  void _escuchar() {
    _suscripcion?.cancel();
    _errorCarga = null;
    _cargado = false;

    _suscripcion = widget.service.escucharConfiguracion().listen(
      _aplicarConfiguracion,
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _errorCarga = _mensajeErrorCarga(error);
        });
      },
    );
  }

  void _aplicarConfiguracion(EmpresaConfig config) {
    if (!mounted) return;

    setState(() {
      _errorCarga = null;
      if (_cargado) return;

      _nombreController.text = config.nombre;
      _esloganController.text = config.eslogan;
      _telefonoController.text = config.telefono;
      _telefonoAdministradorController.text = config.telefonoAdministrador;
      _emailController.text = config.email;
      _direccionController.text = config.direccion;
      _sitioWebController.text = config.sitioWeb;
      _logoBase64 = config.logoBase64;
      _cargado = true;
    });
  }

  Future<void> _seleccionarLogo() async {
    if (_cargandoLogo) return;
    setState(() => _cargandoLogo = true);

    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 80,
      );
      if (archivo == null) return;

      final bytes = await archivo.readAsBytes();
      if (bytes.length > 600 * 1024) {
        if (mounted) {
          setState(
            () => _errorGuardado =
                'El logotipo es demasiado grande. Elige una imagen menor a '
                '600 KB.',
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _logoBase64 = base64Encode(bytes);
        _errorGuardado = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorGuardado = 'No se pudo cargar la imagen.');
      }
    } finally {
      if (mounted) setState(() => _cargandoLogo = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });

    final config = EmpresaConfig(
      nombre: _nombreController.text.trim(),
      eslogan: _esloganController.text.trim(),
      telefono: _telefonoController.text.trim(),
      telefonoAdministrador: _telefonoAdministradorController.text.trim(),
      email: _emailController.text.trim(),
      direccion: _direccionController.text.trim(),
      sitioWeb: _sitioWebController.text.trim(),
      logoBase64: _logoBase64,
    );

    try {
      await widget.service.guardarConfiguracion(config);
      if (!mounted) return;
      setState(() => _guardando = false);
      _mensaje('Datos de la empresa actualizados. El PDF ya los incluye.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = _mensajeErrorGuardado(error);
      });
    }
  }

  String _mensajeErrorCarga(Object error) {
    if (_esPermisoDenegado(error)) {
      return 'Firestore rechazó la lectura de la configuración. Publica las '
          'reglas actualizadas con: firebase deploy --only firestore:rules';
    }
    return 'No se pudo leer la configuración de la empresa. Revisa la '
        'conexión y las reglas de Firestore.';
  }

  String _mensajeErrorGuardado(Object error) {
    if (_esPermisoDenegado(error)) {
      return 'Firestore rechazó el guardado. Publica las reglas actualizadas '
          'con: firebase deploy --only firestore:rules';
    }
    return 'No se pudieron guardar los datos. Revisa la conexión e intenta '
        'de nuevo.';
  }

  static bool _esPermisoDenegado(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.usuarioActual.esAdministrador) {
      return const AdminEmptyState(
        icon: Icons.lock_outline,
        titulo: 'Acceso exclusivo del administrador',
        mensaje:
            'Solo un administrador puede cambiar los datos y el logotipo de '
            'la empresa.',
        accionEtiqueta: 'Volver',
        onAccion: _noop,
      );
    }

    if (_errorCarga != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: AdminErrorState(
          mensaje: _errorCarga!,
          onReintentar: () => setState(_escuchar),
        ),
      );
    }

    if (!_cargado) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 900 ? 28.0 : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _encabezado(context),
                    const SizedBox(height: 16),
                    _tarjetaIdentidad(context),
                    const SizedBox(height: 16),
                    _tarjetaContacto(context),
                    if (_errorGuardado != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _mensajeError(context, _errorGuardado!),
                    ],
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _guardando ? 'Guardando...' : 'Guardar cambios',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _encabezado(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.storefront_outlined,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Datos de la empresa', style: theme.textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                'Estos datos aparecen en el encabezado y el pie del PDF de '
                'cada cotización.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaIdentidad(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Identidad visual',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final logo = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    EmpresaLogo(logoBase64: _logoBase64, size: 108),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: _cargandoLogo ? null : _seleccionarLogo,
                          icon: _cargandoLogo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_library_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _logoBase64.isEmpty
                                ? 'Subir logotipo'
                                : 'Cambiar logotipo',
                          ),
                        ),
                        if (_logoBase64.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setState(() => _logoBase64 = ''),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Quitar'),
                          ),
                      ],
                    ),
                  ],
                );

                final campos = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _nombreController,
                      enabled: !_guardando,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del negocio *',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Escribe el nombre del negocio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _esloganController,
                      enabled: !_guardando,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Eslogan o descripción breve',
                        prefixIcon: Icon(Icons.campaign_outlined),
                      ),
                    ),
                  ],
                );

                if (constraints.maxWidth >= 560) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      logo,
                      const SizedBox(width: 20),
                      Expanded(child: campos),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(child: logo),
                    const SizedBox(height: 14),
                    campos,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              'JPG o PNG. La imagen se optimiza y se guarda en Firestore. Si '
              'no subes un logotipo, el PDF usará las iniciales del negocio.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaContacto(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Contacto que aparece en el PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefonoController,
              enabled: !_guardando,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Número de móvil de la empresa',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+51 999 999 999',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoAdministradorController,
              enabled: !_guardando,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
              ],
              decoration: const InputDecoration(
                labelText: 'WhatsApp del administrador',
                prefixIcon: Icon(Icons.chat_outlined),
                hintText: '+51 999 999 999',
                helperText:
                    'Recibe los avisos de reservas. Si lo dejas vacío se usa '
                    'el móvil de la empresa.',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionController,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Dirección de la empresa',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sitioWebController,
              enabled: !_guardando,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Sitio web o red social',
                prefixIcon: Icon(Icons.public_outlined),
                hintText: 'https://miempresa.com  ·  @miempresa',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              enabled: !_guardando,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo de contacto',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(email);
                if (!valido) return 'Correo no válido';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajeError(BuildContext context, String mensaje) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}
