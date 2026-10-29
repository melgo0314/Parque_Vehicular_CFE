import 'dart:typed_data';

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

  Stream<List<UserModel>> obtenerUsuarios({
    String busqueda = '',
    String? rol,
  }) {
    return _usuarios.snapshots().map((consulta) {
      final texto = busqueda.trim().toLowerCase();
      final rolBuscado = rol?.trim().toLowerCase();

      return consulta.docs
          .map(
            (documento) => UserModel.fromMap(
              documento.data(),
              documento.id,
            ),
          )
          .where((usuario) {
        final coincideRol = rolBuscado == null ||
            rolBuscado.isEmpty ||
            usuario.rol == rolBuscado;

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

  // Registra la cuenta, el perfil y, para operadores, su documento de licencia.
  Future<void> registrarUsuario({
    required String nombre,
    required String apellidoP,
    required String apellidoM,
    required String correo,
    required String contrasena,
    required String rol,
    required String rpe,
    required String telefono,
    Uint8List? archivoLicencia,
    String? nombreArchivoLicencia,
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

    if (rolLimpio == 'operador' &&
        (archivoLicencia == null || archivoLicencia.isEmpty)) {
      throw ArgumentError(
        'Selecciona el documento de licencia del operador.',
      );
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

      if (rolLimpio == 'operador' && archivoLicencia != null) {
        final extension = _obtenerExtension(nombreArchivoLicencia ?? '');
        final tipoContenido = _obtenerTipoContenido(extension);

        referenciaLicencia = _storage
            .ref()
            .child('licencias/${nuevoUsuario.uid}.$extension');

        final metadata = SettableMetadata(
          contentType: tipoContenido,
        );

        await referenciaLicencia
            .putData(archivoLicencia, metadata)
            .timeout(const Duration(seconds: 45));

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
    } on FirebaseException{
      // Permite que el ViewModel muestre el código real del error de Storage.
      rethrow;
    } catch (_) {
      if (referenciaLicencia != null) {
        try {
          await referenciaLicencia.delete();
        } catch (_) {
          // Conserva el error original del registro.
        }
      }

      final usuarioCreado = credencial?.user;

      if (usuarioCreado != null) {
        try {
          await usuarioCreado.delete();
        } catch (_) {
          // Conserva el error original del registro.
        }
      }

      rethrow;
    } finally {
      if (appSecundaria != null) {
        try {
          await appSecundaria.delete();
        } catch (_) {
          // No cambia el resultado del registro.
        }
      }
    }
  }

  String _obtenerExtension(String nombreArchivo) {
    final partes = nombreArchivo.toLowerCase().split('.');

    if (partes.length < 2) {
      throw ArgumentError('El archivo no tiene una extensión válida.');
    }

    final extension = partes.last;

    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
      throw ArgumentError('Selecciona un archivo PDF, JPG o PNG.');
    }

    return extension == 'jpeg' ? 'jpg' : extension;
  }

  String _obtenerTipoContenido(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> actualizarUsuario(UserModel usuario) async {
    final datos = usuario.toMap()
      ..['actualizadoEn'] = FieldValue.serverTimestamp();

    await _usuarios.doc(usuario.uid).update(datos);
  }

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

  Future<void> eliminarUsuario(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del usuario.');
    }

    final callable = _functions.httpsCallable('eliminarUsuario');
    await callable.call<void>({'uid': uid});
  }
}