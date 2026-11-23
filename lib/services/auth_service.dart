import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/app_config.dart';
import '../models/usuario.dart';

/// Estado de la sesión que consume la pantalla de inicio.
sealed class EstadoSesion {
  const EstadoSesion();
}

/// No hay una cuenta de Firebase Auth autenticada.
class SesionCerrada extends EstadoSesion {
  const SesionCerrada();
}

/// La cuenta existe, pero todavía no tiene un perfil autorizado en Firestore.
class SesionSinPerfil extends EstadoSesion {
  const SesionSinPerfil({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// La cuenta está autenticada y tiene un perfil en `usuarios/{uid}`.
class SesionActiva extends EstadoSesion {
  const SesionActiva({required this.usuario});

  final Usuario usuario;
}

/// Datos de la cuenta recién creada. La contraseña temporal solo existe en
/// memoria y se comparte con la invitación por correo.
class InvitacionPersonal {
  const InvitacionPersonal({
    required this.usuario,
    required this.passwordTemporal,
    this.cuentaRestaurada = false,
  });

  final Usuario usuario;

  /// Contraseña temporal. Está vacía cuando se restaura el perfil de una
  /// persona que ya tenía una cuenta de Firebase Auth.
  final String passwordTemporal;

  /// `true` cuando el correo ya pertenecía a una cuenta eliminada y se
  /// reactivó su perfil en lugar de crear una cuenta nueva.
  final bool cuentaRestaurada;
}

/// Autenticación por correo y administración de los perfiles del personal.
///
/// Los perfiles se guardan en `usuarios/{uid}`. El UID es el mismo que asigna
/// Firebase Authentication, de modo que las reglas de Firestore pueden validar
/// el rol y los permisos de cada cuenta.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  CollectionReference<Map<String, dynamic>> get _usuariosEliminados =>
      _firestore.collection('usuarios_eliminados');

  User? get usuarioAuth => _auth.currentUser;

  /// Emite el estado de la sesión y se actualiza en tiempo real cuando el
  /// administrador cambia los permisos del usuario conectado.
  ///
  /// El listener de Firestore se cancela explícitamente al cerrar sesión para
  /// evitar que Firestore emita `permission-denied` mientras se propaga el
  /// cierre de sesión a todas las suscripciones.
  Stream<EstadoSesion> get estadoSesion {
    late final StreamController<EstadoSesion> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? perfilSub;

    Future<void> cancelarPerfil() async {
      final sub = perfilSub;
      perfilSub = null;
      await sub?.cancel();
    }

    controller = StreamController<EstadoSesion>(
      onListen: () {
        authSub = _auth.authStateChanges().listen((user) {
          unawaited(cancelarPerfil());

          if (user == null) {
            if (!controller.isClosed) {
              controller.add(const SesionCerrada());
            }
            return;
          }

          perfilSub = _usuarios
              .doc(user.uid)
              .snapshots()
              .listen(
                (doc) {
                  // Ignora eventos tardíos del listener de una sesión anterior.
                  if (_auth.currentUser?.uid != user.uid) return;
                  if (controller.isClosed) return;

                  final data = doc.data();
                  if (!doc.exists || data == null) {
                    controller.add(
                      SesionSinPerfil(uid: user.uid, email: user.email ?? ''),
                    );
                    return;
                  }
                  controller.add(
                    SesionActiva(
                      usuario: Usuario.fromMap(
                        user.uid,
                        data,
                        emailFallback: user.email ?? '',
                      ),
                    ),
                  );
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (controller.isClosed) return;

                  // Al cerrar sesión el listener puede fallar con
                  // permission-denied antes de completar la cancelación. En ese
                  // caso el estado correcto es "sesión cerrada", no un error.
                  if (_auth.currentUser == null) {
                    controller.add(const SesionCerrada());
                  } else if (_auth.currentUser?.uid == user.uid) {
                    controller.addError(error, stackTrace);
                  }
                },
              );
        }, onError: controller.addError);
      },
      onCancel: () async {
        await authSub?.cancel();
        await cancelarPerfil();
      },
    );

    return controller.stream;
  }

  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final credencial = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credencial.user;
    if (user != null) {
      await _crearPerfilAdminSiCorresponde(user);
    }
  }

  /// Crea el perfil del administrador cuando su correo está en
  /// [AppConfig.correosAdministradores] y todavía no existe el documento.
  Future<void> _crearPerfilAdminSiCorresponde(User user) async {
    final email = (user.email ?? '').trim().toLowerCase();
    if (!AppConfig.esCorreoAdministrador(email)) return;

    final referencia = _usuarios.doc(user.uid);
    final doc = await referencia.get();
    if (doc.exists) return;

    final usuario = Usuario(
      uid: user.uid,
      email: email,
      nombre: email.split('@').first,
      rol: RolUsuario.administrador,
      permisos: PermisosUsuario.administrador,
    );
    await referencia.set(<String, dynamic>{
      ...usuario.toMap(),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cerrarSesion() => _auth.signOut();

  Future<void> enviarCorreoRestablecimiento(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  /// Escucha todos los perfiles y los ordena por nombre.
  Stream<List<Usuario>> escucharUsuarios() {
    return _usuarios.snapshots().map((snapshot) {
      final usuarios = snapshot.docs.map((doc) {
        final data = doc.data();
        return Usuario.fromMap(
          doc.id,
          data,
          emailFallback: data['email']?.toString() ?? '',
        );
      }).toList();
      usuarios.sort(
        (a, b) => a.nombreVisible.toLowerCase().compareTo(
          b.nombreVisible.toLowerCase(),
        ),
      );
      return usuarios;
    });
  }

  Future<Usuario> obtenerPerfil(String uid) async {
    final doc = await _usuarios.doc(uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      throw StateError('El perfil del usuario no existe.');
    }
    return Usuario.fromMap(uid, data);
  }

  Future<Usuario?> obtenerPerfilActual() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _usuarios.doc(user.uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Usuario.fromMap(user.uid, data, emailFallback: user.email ?? '');
  }

  /// Crea la cuenta de Firebase Auth y su perfil de Firestore.
  ///
  /// La cuenta se crea en una instancia secundaria de Firebase para no cerrar
  /// la sesión del administrador que está agregando al personal. El perfil se
  /// marca con `debeCambiarPassword` para que la persona defina una contraseña
  /// propia en su primer inicio de sesión.
  Future<InvitacionPersonal> crearPersonal({
    required String nombre,
    required String email,
    required String password,
    required PermisosUsuario permisos,
    String telefono = '',
    String rol = RolUsuario.personal,
  }) async {
    final admin = await _exigirAdministrador();
    final emailNormalizado = email.trim().toLowerCase();
    if (emailNormalizado.isEmpty) {
      throw ArgumentError('El correo es obligatorio.');
    }

    final nombreApp =
        'creador-personal-${DateTime.now().microsecondsSinceEpoch}';
    final appSecundaria = await Firebase.initializeApp(
      name: nombreApp,
      options: Firebase.app().options,
    );
    final authSecundaria = FirebaseAuth.instanceFor(app: appSecundaria);

    try {
      final UserCredential credencial;
      try {
        credencial = await authSecundaria.createUserWithEmailAndPassword(
          email: emailNormalizado,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        // Si el correo ya tiene una cuenta de Firebase Auth, puede tratarse de
        // un perfil eliminado desde esta misma app. En ese caso restauramos el
        // perfil para que el administrador pueda volver a dar acceso.
        if (error.code == 'email-already-in-use') {
          final eliminado = await _buscarPerfilEliminado(emailNormalizado);
          if (eliminado != null) {
            return await _restaurarPerfilEliminado(
              anterior: eliminado,
              admin: admin,
              nombre: nombre,
              telefono: telefono,
              rol: rol,
              permisos: permisos,
            );
          }
        }
        rethrow;
      }

      final user = credencial.user;
      if (user == null) {
        throw StateError('No se pudo crear la cuenta de Firebase Auth.');
      }

      final usuario = Usuario(
        uid: user.uid,
        email: emailNormalizado,
        nombre: nombre.trim().isEmpty ? emailNormalizado : nombre.trim(),
        telefono: telefono.trim(),
        rol: rol == RolUsuario.administrador
            ? RolUsuario.administrador
            : RolUsuario.personal,
        activo: true,
        debeCambiarPassword: true,
        permisos: rol == RolUsuario.administrador
            ? PermisosUsuario.administrador
            : permisos,
      );

      try {
        await _usuarios.doc(user.uid).set(<String, dynamic>{
          ...usuario.toMap(),
          'creadoEn': FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
          'creadoPor': admin.uid,
        });
      } catch (error) {
        // Si falla la escritura del perfil, no dejamos una cuenta huérfana.
        try {
          await user.delete();
        } catch (_) {
          // Sin permisos para borrar la cuenta: el perfil no existe y la
          // persona no podrá entrar al cotizador.
        }
        rethrow;
      }

      // La cuenta se creó correctamente: cualquier registro de eliminación
      // anterior para este correo ya no es necesario.
      await _limpiarEliminados(emailNormalizado);

      return InvitacionPersonal(usuario: usuario, passwordTemporal: password);
    } finally {
      try {
        await authSecundaria.signOut();
      } catch (_) {
        // La instancia secundaria se elimina de todos modos.
      }
      try {
        await appSecundaria.delete();
      } catch (_) {
        // No es crítico si el runtime tarda en liberar la instancia.
      }
    }
  }

  Future<Usuario?> _buscarPerfilEliminado(String email) async {
    final resultado = await _usuariosEliminados
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (resultado.docs.isEmpty) return null;

    final doc = resultado.docs.first;
    return Usuario.fromMap(doc.id, doc.data(), emailFallback: email);
  }

  Future<void> _limpiarEliminados(String email) async {
    try {
      final resultado = await _usuariosEliminados
          .where('email', isEqualTo: email)
          .get();
      for (final doc in resultado.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // La limpieza del registro es secundaria: no bloquea el alta.
    }
  }

  /// Reactiva el perfil de una persona cuyo acceso se eliminó antes.
  ///
  /// La cuenta de Firebase Auth sigue existiendo, por lo que no es posible
  /// asignarle una contraseña nueva desde el cliente. Se envía un enlace de
  /// restablecimiento y se marca `debeCambiarPassword` para que la persona
  /// defina una contraseña propia al entrar.
  Future<InvitacionPersonal> _restaurarPerfilEliminado({
    required Usuario anterior,
    required Usuario admin,
    required String nombre,
    required String telefono,
    required String rol,
    required PermisosUsuario permisos,
  }) async {
    final rolFinal = rol == RolUsuario.administrador
        ? RolUsuario.administrador
        : RolUsuario.personal;
    final usuario = Usuario(
      uid: anterior.uid,
      email: anterior.email,
      nombre: nombre.trim().isEmpty ? anterior.nombreVisible : nombre.trim(),
      telefono: telefono.trim().isEmpty ? anterior.telefono : telefono.trim(),
      rol: rolFinal,
      activo: true,
      debeCambiarPassword: true,
      permisos: rolFinal == RolUsuario.administrador
          ? PermisosUsuario.administrador
          : permisos,
    );

    await _usuarios.doc(usuario.uid).set(<String, dynamic>{
      ...usuario.toMap(),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
      'creadoPor': admin.uid,
      'actualizadoPor': admin.uid,
      'restauradoEn': FieldValue.serverTimestamp(),
    });
    await _usuariosEliminados.doc(usuario.uid).delete();

    try {
      await _auth.sendPasswordResetEmail(email: usuario.email);
    } catch (_) {
      // Si el envío falla, el administrador aún puede usar el botón de
      // restablecimiento de la lista de personal.
    }

    return InvitacionPersonal(
      usuario: usuario,
      passwordTemporal: '',
      cuentaRestaurada: true,
    );
  }

  /// Guarda una nueva contraseña para el usuario conectado y retira la marca
  /// que obliga a cambiarla en el primer inicio de sesión.
  Future<void> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('Debes iniciar sesión para cambiar tu contraseña.');
    }

    final credencial = EmailAuthProvider.credential(
      email: email,
      password: passwordActual,
    );
    await user.reauthenticateWithCredential(credencial);
    await user.updatePassword(passwordNueva);

    await _usuarios.doc(user.uid).update(<String, dynamic>{
      'debeCambiarPassword': false,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza el nombre, rol, estado y permisos de un perfil.
  Future<void> actualizarPersonal(Usuario usuario) async {
    final admin = await _exigirAdministrador();
    if (usuario.uid == admin.uid &&
        (usuario.rol != RolUsuario.administrador || !usuario.activo)) {
      throw StateError(
        'No puedes quitarte a ti mismo el rol de administrador ni '
        'desactivar tu propia cuenta.',
      );
    }

    final rol = usuario.rol == RolUsuario.administrador
        ? RolUsuario.administrador
        : RolUsuario.personal;
    final permisos = rol == RolUsuario.administrador
        ? PermisosUsuario.administrador
        : usuario.permisos;

    await _usuarios.doc(usuario.uid).update(<String, dynamic>{
      'nombre': usuario.nombre.trim(),
      'telefono': usuario.telefono.trim(),
      'rol': rol,
      'activo': usuario.activo,
      'permisos': permisos.toMap(),
      'actualizadoEn': FieldValue.serverTimestamp(),
      'actualizadoPor': admin.uid,
    });
  }

  Future<void> cambiarEstadoPersonal(String uid, bool activo) async {
    final admin = await _exigirAdministrador();
    if (uid == admin.uid && !activo) {
      throw StateError('No puedes desactivar tu propia cuenta.');
    }
    await _usuarios.doc(uid).update(<String, dynamic>{
      'activo': activo,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'actualizadoPor': admin.uid,
    });
  }

  /// Elimina el perfil del cotizador de una persona agregada por el
  /// administrador.
  ///
  /// La cuenta de Firebase Authentication no se puede borrar desde el cliente,
  /// así que el perfil se mueve a `usuarios_eliminados`. Sin el perfil, la
  /// persona pierde el acceso de inmediato. Si el administrador vuelve a
  /// agregar el mismo correo, [crearPersonal] restaura el perfil y envía un
  /// enlace para restablecer la contraseña.
  Future<void> eliminarPersonal(Usuario usuario) async {
    final admin = await _exigirAdministrador();
    if (usuario.uid == admin.uid) {
      throw StateError('No puedes eliminar tu propia cuenta.');
    }

    final doc = await _usuarios.doc(usuario.uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      throw StateError('El perfil ya no existe o no tienes acceso a él.');
    }

    final perfil = Usuario.fromMap(
      usuario.uid,
      data,
      emailFallback: usuario.email,
    );

    try {
      await _usuariosEliminados.doc(perfil.uid).set(<String, dynamic>{
        ...perfil.toMap(),
        'creadoEn': perfil.creadoEn != null
            ? Timestamp.fromDate(perfil.creadoEn!)
            : FieldValue.serverTimestamp(),
        'eliminadoEn': FieldValue.serverTimestamp(),
        'eliminadoPor': admin.uid,
      });
      await _usuarios.doc(perfil.uid).delete();
    } catch (error) {
      // Si el perfil no se pudo borrar, retiramos el registro de eliminación
      // para que la persona siga teniendo un estado coherente.
      try {
        await _usuariosEliminados.doc(perfil.uid).delete();
      } catch (_) {
        // No hay nada más que revertir.
      }
      rethrow;
    }
  }

  Future<Usuario> _exigirAdministrador() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesión como administrador.');
    }
    final doc = await _usuarios.doc(user.uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      throw StateError('Tu cuenta no tiene un perfil autorizado.');
    }
    final perfil = Usuario.fromMap(
      user.uid,
      data,
      emailFallback: user.email ?? '',
    );
    if (!perfil.esAdministrador || !perfil.activo) {
      throw StateError('Solo un administrador puede realizar esta acción.');
    }
    return perfil;
  }
}
