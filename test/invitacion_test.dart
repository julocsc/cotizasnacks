import 'package:cotizador_app/models/usuario.dart';
import 'package:cotizador_app/utils/invitacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invitación por correo', () {
    test('incluye el correo y la contraseña temporal', () {
      final uri = crearUriInvitacion(
        email: 'nuevo@empresa.com',
        nombre: 'Ana Torres',
        passwordTemporal: 'Temp12345',
      );

      expect(uri.scheme, 'mailto');
      expect(uri.path, 'nuevo@empresa.com');
      expect(uri.queryParameters['subject'], contains('Cotizador Pro'));
      expect(uri.queryParameters['body'], contains('Ana Torres'));
      expect(uri.queryParameters['body'], contains('nuevo@empresa.com'));
      expect(uri.queryParameters['body'], contains('Temp12345'));
      expect(uri.queryParameters['body'], contains('nueva contraseña'));
    });
  });

  group('Contraseña temporal', () {
    test('los perfiles nuevos deben cambiar la contraseña al entrar', () {
      final usuario = Usuario.fromMap('u3', <String, dynamic>{
        'email': 'nuevo@empresa.com',
        'nombre': 'Nuevo',
        'rol': RolUsuario.personal,
        'activo': true,
        'debeCambiarPassword': true,
      });

      expect(usuario.debeCambiarPassword, isTrue);
    });

    test('los perfiles existentes sin la marca no se bloquean', () {
      final usuario = Usuario.fromMap('u4', <String, dynamic>{
        'email': 'antiguo@empresa.com',
        'nombre': 'Antiguo',
        'rol': RolUsuario.personal,
        'activo': true,
      });

      expect(usuario.debeCambiarPassword, isFalse);
    });
  });
}
