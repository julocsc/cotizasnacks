import 'package:cotizador_app/core/app_config.dart';
import 'package:cotizador_app/models/empresa_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmpresaConfig', () {
    test('usa los datos predeterminados cuando no existe el documento', () {
      final config = EmpresaConfig.fromMap(null);

      expect(config.nombre, AppConfig.nombreEmpresa);
      expect(config.telefono, AppConfig.telefonoEmpresa);
      expect(config.direccion, AppConfig.direccionEmpresa);
      expect(config.logoBase64, isEmpty);
    });

    test('reconstruye los datos configurables de la empresa', () {
      final config = EmpresaConfig.fromMap(<String, dynamic>{
        'nombre': '  Dulce Tentación  ',
        'eslogan': 'Postres artesanales',
        'telefono': '+51 987 654 321',
        'telefonoAdministrador': '+51 912 345 678',
        'email': 'ventas@dulcetentacion.pe',
        'direccion': 'Av. Principal 123, Lima',
        'sitioWeb': '@dulcetentacion',
        'logoBase64': 'abc123',
      });

      expect(config.nombre, 'Dulce Tentación');
      expect(config.eslogan, 'Postres artesanales');
      expect(config.telefono, '+51 987 654 321');
      expect(config.telefonoAdministrador, '+51 912 345 678');
      expect(config.whatsappAdministrador, '+51 912 345 678');
      expect(config.email, 'ventas@dulcetentacion.pe');
      expect(config.direccion, 'Av. Principal 123, Lima');
      expect(config.sitioWeb, '@dulcetentacion');
      expect(config.logoBase64, 'abc123');
    });

    test('normaliza el correo al guardar y conserva el logotipo', () {
      const config = EmpresaConfig(
        nombre: 'Mi Negocio',
        email: 'VENTAS@NEGOCIO.COM',
        logoBase64: 'logo-en-base64',
      );

      final map = config.toMap();
      expect(map['email'], 'ventas@negocio.com');
      expect(map['logoBase64'], 'logo-en-base64');
      expect(map['nombre'], 'Mi Negocio');
    });

    test('usa el móvil de la empresa si no hay WhatsApp del administrador', () {
      const config = EmpresaConfig(
        telefono: '+51 987 654 321',
        telefonoAdministrador: '',
      );

      expect(config.whatsappAdministrador, '+51 987 654 321');
      expect(config.toMap()['telefonoAdministrador'], '');
    });
  });
}
