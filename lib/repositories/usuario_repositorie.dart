import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/user_model.dart';

// Se comunica con Firebase para administrar usuarios y sus documentos.
// Permite consultar usuarios, registrar cuentas y perfiles, guardar licencias
// y realizar actualizaciones o eliminaciones.
class UsuariosRepositorie {
  // Crea el repositorio con las conexiones de Firebase disponibles.
  // Entradas: [firestore], [storage] y [functions] son opcionales; si no se
  // proporcionan, se usan las instancias predeterminadas de Firebase.
  // Salida: una instancia configurada de [UsuariosRepositorie].
  UsuariosRepositorie({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // Conexión a Cloud Firestore.
  final FirebaseFirestore _db;
  // Conexión a Firebase Storage.
  final FirebaseStorage _storage;
  // Conexión a Cloud Functions.
  final FirebaseFunctions _functions;
  // Referencia a la colección donde se guardan los usuarios.
  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuario');
  // Obtiene usuarios en tiempo real y filtra por texto y rol.
  // Entradas: [busqueda] es el texto que se buscará en los datos del usuario;
  // [rol] es el rol opcional por el que se filtrará.
  // Salida: un flujo de usuarios ordenados por nombre completo.
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

  // Registra una cuenta de autenticación, su perfil y, para operadores,
  // el documento de licencia.
  // Entradas: datos personales, credenciales, rol y contacto del usuario.
  // [archivoLicencia] y [nombreArchivoLicencia] se usan para operadores.
  // Salida: un [Future] que termina cuando el registro se guarda. Lanza una
  // excepción si faltan datos, el rol no es válido o Firebase falla.
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
    } on FirebaseException {
      rethrow;
    } catch (_) {
      if (referenciaLicencia != null) {
        try {
          await referenciaLicencia.delete();
        } catch (_) {}
      }

      final usuarioCreado = credencial?.user;

      if (usuarioCreado != null) {
        try {
          await usuarioCreado.delete();
        } catch (_) {}
      }

      rethrow;
    } finally {
      if (appSecundaria != null) {
        try {
          await appSecundaria.delete();
        } catch (_) {}
      }
    }
  }

  // Obtiene y valida la extensión de un archivo de licencia.
  // Entrada: [nombreArchivo], nombre del archivo seleccionado.
  // Salida: extensión válida (`pdf`, `jpg` o `png`); convierte `jpeg` a `jpg`.
  // Lanza [ArgumentError] si el archivo no tiene una extensión admitida.
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

  // Determina el tipo extensión de un archivo a partir de su extensión.
  // Entrada: [extension] del archivo.
  // Salida: tipo extensión para PDF, PNG o JPEG.
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

  // Actualiza los datos de un usuario en Firestore.
  // Entrada: [usuario], con los datos y el identificador del usuario.
  // Salida: un [Future] que termina cuando Firestore confirma la actualización.
  Future<void> actualizarUsuario(UserModel usuario) async {
    final datos = usuario.toMap()
      ..['actualizadoEn'] = FieldValue.serverTimestamp();

    await _usuarios.doc(usuario.uid).update(datos);
  }

  // Actualiza el perfil y, opcionalmente, la contraseña mediante Cloud Functions.
  // Entradas: [usuario] con los datos del perfil y [nuevaContrasena] opcional.
  // Salida: un [Future] que termina cuando la función procesa la actualización.
  Future<void> actualizarUsuarioCompleto({
  required UserModel usuario,
  String? nuevaContrasena,
  Uint8List? archivoLicencia,
  String? nombreArchivoLicencia,
}) async {
  var usuarioActualizado = usuario;
  String? urlLicenciaNueva;

  if (usuario.rol.trim().toLowerCase() == 'operador' &&
      archivoLicencia != null) {
    final extension = _obtenerExtension(nombreArchivoLicencia ?? '');
    final tipoContenido = _obtenerTipoContenido(extension);
    final nombreUnico = DateTime.now().microsecondsSinceEpoch;

    final referencia = _storage
        .ref()
        .child('licencias/${usuario.uid}/${nombreUnico}.$extension');

    await referencia
        .putData(
          archivoLicencia,
          SettableMetadata(contentType: tipoContenido),
        )
        .timeout(const Duration(seconds: 45));

    urlLicenciaNueva = await referencia.getDownloadURL();

    usuarioActualizado = usuario.copyWith(
      urlLicencia: urlLicenciaNueva,
    );
  }

  if (usuarioActualizado.rol.trim().toLowerCase() == 'operador' &&
      usuarioActualizado.urlLicencia.trim().isEmpty) {
    throw ArgumentError(
      'Un operador debe tener un documento de licencia.',
    );
  }

  final callable = _functions.httpsCallable('actualizarUsuario');

  await callable.call<void>({
    'uid': usuarioActualizado.uid,
    'perfil': usuarioActualizado.toMap(),
    'nuevaContrasena': nuevaContrasena?.trim().isEmpty == true
        ? null
        : nuevaContrasena?.trim(),
  });

  final urlAnterior = usuario.urlLicencia.trim();

  if (urlLicenciaNueva != null &&
      urlAnterior.isNotEmpty &&
      urlAnterior != urlLicenciaNueva) {
    try {
      await _storage.refFromURL(urlAnterior).delete();
    } catch (error) {
      // El perfil ya se actualizó. Si falla esta limpieza, la licencia nueva
      // permanece guardada y la anterior puede eliminarse después.
      debugPrint('No se pudo borrar la licencia anterior: $error');
    }
  }
}

  // Elimina una cuenta de usuario mediante Cloud Functions.
  // Entrada: [uid], identificador del usuario que se eliminará.
  // Salida: un [Future] que termina cuando la función procesa la eliminación.
  // Lanza [ArgumentError] si el identificador está vacío.
  Future<void> eliminarUsuario(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del usuario.');
    }
    final callable = _functions.httpsCallable('eliminarUsuario');
    await callable.call<void>({'uid': uid});
  }
}