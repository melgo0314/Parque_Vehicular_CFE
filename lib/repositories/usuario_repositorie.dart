import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_model.dart';

class UsuariosRepositorie {
  UsuariosRepositorie({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuario');

  // Devuelve los usuarios en tiempo real.
  Stream<List<UserModel>> obtenerUsuarios({
    String busqueda = '',
    String? rol,
  }) {
    return _usuarios.snapshots().map((consulta) {
      final texto = busqueda.trim().toLowerCase();
      final rolBuscado = rol?.trim().toLowerCase();

      return consulta.docs
          .map((documento) =>
              UserModel.fromMap(documento.data(), documento.id))
          .where((usuario) {
        final coincideRol =
            rolBuscado == null || rolBuscado.isEmpty || usuario.rol == rolBuscado;

        final datosBusqueda = [
          usuario.nombre,
          usuario.apellidoP,
          usuario.apellidoM,
          usuario.nombreCompleto,
          usuario.correo,
          usuario.rpe,
          usuario.telefono,
          usuario.rol,
        ].join(' ').toLowerCase();

        final coincideTexto = texto.isEmpty || datosBusqueda.contains(texto);

        return coincideRol && coincideTexto;
      }).toList()
        ..sort(
          (a, b) => a.nombreCompleto
              .toLowerCase()
              .compareTo(b.nombreCompleto.toLowerCase()),
        );
    });
  }

  // Registra la cuenta en Authentication y el perfil en Firestore.
  Future<void> registrarUsuario({
    required String nombre,
    required String apellidoP,
    required String apellidoM,
    required String correo,
    required String contrasena,
    required String rol,
    required String rpe,
    required String telefono,
    File? fotoLicencia,
  }) async {
    final nombreLimpio = nombre.trim();
    final apellidoPLimpio = apellidoP.trim();
    final apellidoMLimpio = apellidoM.trim();
    final correoLimpio = correo.trim().toLowerCase();
    final rolLimpio = rol.trim().toLowerCase();

    if (nombreLimpio.isEmpty ||
        apellidoPLimpio.isEmpty ||
        apellidoMLimpio.isEmpty ||
        correoLimpio.isEmpty ||
        contrasena.isEmpty ||
        rpe.trim().isEmpty ||
        telefono.trim().isEmpty) {
      throw ArgumentError('Completa todos los campos obligatorios.');
    }

    const rolesPermitidos = {
      'administrador',
      'operador',
      'superusuario',
    };

    if (!rolesPermitidos.contains(rolLimpio)) {
      throw ArgumentError('Selecciona un rol válido.');
    }

    if (rolLimpio == 'operador' && fotoLicencia == null) {
      throw ArgumentError('La fotografía de licencia es obligatoria para operadores.');
    }

    FirebaseApp? appSecundaria;
    UserCredential? credencial;
    Reference? referenciaLicencia;

    try {
      appSecundaria = await Firebase.initializeApp(
        name: 'RegistroUsuario_${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final authSecundario = FirebaseAuth.instanceFor(app: appSecundaria);

      credencial = await authSecundario.createUserWithEmailAndPassword(
        email: correoLimpio,
        password: contrasena,
      );

      final nuevoUsuario = credencial.user;
      if (nuevoUsuario == null) {
        throw StateError('Firebase no devolvió la cuenta recién creada.');
      }

      var urlLicencia = '';

      if (rolLimpio == 'operador' && fotoLicencia != null) {
        referenciaLicencia =
            _storage.ref().child('licencias/${nuevoUsuario.uid}.jpg');

        await referenciaLicencia.putFile(fotoLicencia);
        urlLicencia = await referenciaLicencia.getDownloadURL();
      }

      final perfil = UserModel(
        uid: nuevoUsuario.uid,
        nombre: nombreLimpio,
        apellidoP: apellidoPLimpio,
        apellidoM: apellidoMLimpio,
        correo: correoLimpio,
        rol: rolLimpio,
        rpe: rpe.trim(),
        telefono: telefono.trim(),
        urlLicencia: urlLicencia,
      );

      await _usuarios.doc(nuevoUsuario.uid).set({
        ...perfil.toMap(),
        'creadoEn': FieldValue.serverTimestamp(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (referenciaLicencia != null) {
        try {
          await referenciaLicencia.delete();
        } catch (_) {
          // Se conserva el error original del registro.
        }
      }

      final usuarioCreado = credencial?.user;
      if (usuarioCreado != null) {
        try {
          await usuarioCreado.delete();
        } catch (_) {
          // Se conserva el error original del registro.
        }
      }

      rethrow;
    } finally {
      if (appSecundaria != null) {
        try {
          await appSecundaria.delete();
        } catch (_) {
        }
      }
    }
  }

  // Actualiza los datos del perfil en Firestore.
  Future<void> actualizarUsuario(UserModel usuario) async {
    final datos = usuario.toMap()
      ..['actualizadoEn'] = FieldValue.serverTimestamp();

    await _usuarios.doc(usuario.uid).update(datos);
  }

  // Un metod de Cloud Function llamada actualizarUsuario
  Future<void> actualizarUsuarioCompleto({
    required UserModel usuario,
    String? nuevaContrasena,
  }) async {
    final callable = _functions.httpsCallable('actualizarUsuario');

    await callable.call<void>({
      'uid': usuario.uid,
      'perfil': usuario.toMap(),
      'nuevaContrasena': nuevaContrasena?.trim().isEmpty == true
          ? null
          : nuevaContrasena?.trim(),
    });
  }

  // Elimina el perfil y la cuenta Auth mediante una función de servidor.
  Future<void> eliminarUsuario(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del usuario.');
    }

    final callable = _functions.httpsCallable('eliminarUsuario');
    await callable.call<void>({'uid': uid});
  }
}