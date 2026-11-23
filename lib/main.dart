import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/app_config.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Necesario para mostrar meses en español con el paquete intl.
  await initializeDateFormatting(AppConfig.locale);
  Intl.defaultLocale = AppConfig.locale;

  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } catch (error) {
    runApp(_StartupErrorApp(error: error));
    return;
  }

  // Si todavía no se ha ejecutado `flutterfire configure`, mostramos una guía
  // en lugar de lanzar una excepción difícil de interpretar.
  if (_tienePlaceholders(options)) {
    runApp(const _SetupRequiredApp());
    return;
  }

  try {
    await Firebase.initializeApp(options: options);
  } catch (error, stackTrace) {
    runApp(_StartupErrorApp(error: error, stackTrace: stackTrace));
    return;
  }

  runApp(const CotizadorApp());
}

bool _tienePlaceholders(FirebaseOptions options) {
  bool esPlaceholder(String value) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized.startsWith('REPLACE_');
  }

  return esPlaceholder(options.apiKey) ||
      esPlaceholder(options.appId) ||
      esPlaceholder(options.projectId);
}

/// Aplicación principal.
class CotizadorApp extends StatelessWidget {
  const CotizadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.nombreApp,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('es', 'PE'),
      supportedLocales: const <Locale>[Locale('es', 'PE')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Pantalla de ayuda cuando `lib/firebase_options.dart` aún tiene valores de
/// ejemplo. No intenta conectarse a Firebase.
class _SetupRequiredApp extends StatelessWidget {
  const _SetupRequiredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        appBar: AppBar(title: const Text('Configura Firebase')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.local_fire_department_outlined,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Falta conectar tu proyecto de Firebase',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ejecuta el FlutterFire CLI desde la raíz del proyecto '
                        'para generar las credenciales de Android y Web:',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const SelectableText(
                          'flutterfire configure --platforms=android,web',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'El comando reemplaza lib/firebase_options.dart con los '
                        'valores reales y crea las apps de Firebase necesarias.',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'También debes habilitar Cloud Firestore en la consola '
                        'de Firebase y publicar reglas de seguridad adecuadas.',
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Consulta README.md para ver el paso a paso y el esquema '
                        'de datos recomendado.',
                      ),
                    ],
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

/// Muestra el error de arranque sin ocultar información útil para depuración.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        appBar: AppBar(title: const Text('No se pudo iniciar Firebase')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error de configuración',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Revisa que las credenciales de firebase_options.dart '
                        'correspondan al proyecto y que las plataformas Android '
                        'y Web estén registradas.',
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          error.toString(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (kDebugMode && stackTrace != null) ...<Widget>[
                        const SizedBox(height: 12),
                        SelectableText(
                          stackTrace.toString(),
                          maxLines: 8,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
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
