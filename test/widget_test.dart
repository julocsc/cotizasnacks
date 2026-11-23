import 'package:cotizador_app/screens/login_screen.dart';
import 'package:cotizador_app/services/auth_service.dart';
import 'package:cotizador_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() {
    return MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(service: AuthService()),
    );
  }

  testWidgets('la pantalla de acceso pide correo y contraseña', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Acceso para personal autorizado'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });

  testWidgets('la pantalla de acceso no desborda en un móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
