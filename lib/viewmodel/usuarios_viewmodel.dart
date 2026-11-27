import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/usuario_repositorie.dart';

// Coordina las operaciones de usuarios entre la interfaz y el repositorio.
class UsuariosViewModel extends ChangeNotifier {
  // Crea el ViewModel con el repositorio proporcionado o uno predeterminado.
  // Entrada: repositorio opcional para consultar y modificar usuarios.
  // Salida: una instancia de UsuariosViewModel configurada.
  UsuariosViewModel({UsuariosRepositorie? repositorio})
      : _repositorio = repositorio ?? UsuariosRepositorie();

  // Repositorio encargado de comunicarse con Firebase.
  final UsuariosRepositorie _repositorio;

  // Indica si hay una operación en curso.
  bool _cargando = false;

  // Devuelve el estado actual de carga.
  bool get cargando => _cargando;

  // Contiene el mensaje de error actual, si existe.
  String? _mensajeError;

  // Devuelve el mensaje de error actual.
  String? get mensajeError => _mensajeError;

  // Contiene el mensaje de éxito actual, si existe.
  String? _mensajeExito;

  // Devuelve el mensaje de éxito actual.
  String? get mensajeExito => _mensajeExito;

  // Obtiene usuarios en tiempo real, opcionalmente filtrados por texto y rol.
  // Entradas: busqueda opcional y rol opcional para filtrar resultados.
  // Salida: un flujo con la lista de usuarios.
  Stream<List<UserModel>> obtenerUsuarios({
    String busqueda = '',
    String? rol,
  }) {
    return _repositorio.obtenerUsuarios(
      busqueda: busqueda,
      rol: rol,
    );
  }

  // Registra un usuario y, si aplica, su documento de licencia.
  // Entradas: datos personales, credenciales, rol y contacto; archivoLicencia
  // y nombreArchivoLicencia son opcionales.
  // Salida: true si el registro termina correctamente; false si ocurre un error
  // o ya hay otra operación en curso.
  Future<bool> registrarUsuario({
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
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.registrarUsuario(
        nombre: nombre,
        apellidoP: apellidoP,
        apellidoM: apellidoM,
        correo: correo,
        contrasena: contrasena,
        rol: rol,
        rpe: rpe,
        telefono: telefono,
        archivoLicencia: archivoLicencia,
        nombreArchivoLicencia: nombreArchivoLicencia,
      );

      _mensajeExito = 'El usuario se registró correctamente.';
      return true;
    } on FirebaseAuthException catch (error) {
      _mensajeError = _mensajeErrorAuth(error.code);
      return false;
    } on FirebaseFunctionsException catch (error) {
      _mensajeError = _mensajeErrorFunctions(error);
      return false;
    } on FirebaseException catch (error) {
      debugPrint(
        'Error de Firebase al subir la licencia: '
        '${error.code} - ${error.message}',
      );
      _mensajeError = _mensajeErrorStorage(error.code);
      return false;
    } on ArgumentError catch (error) {
      _mensajeError =
          error.message?.toString() ?? 'Revisa los datos ingresados.';
      return false;
    } on TimeoutException {
      _mensajeError =
          'La carga del documento tardó demasiado. '
          'Revisa tu conexión e inténtalo otra vez.';
      return false;
    } catch (error) {
      debugPrint('Error al registrar usuario: $error');
      _mensajeError =
          'No se pudo registrar el usuario. '
          'Revisa tu conexión e inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }
  
  // Actualiza el perfil de un usuario y, opcionalmente, su contraseña.
  // Entradas: usuario con los datos del perfil y nuevaContrasena opcional.
  // Salida: true si la actualización termina correctamente; false si ocurre
  // un error o ya hay otra operación en curso.
  Future<bool> actualizarUsuarioCompleto({
    required UserModel usuario,
    String? nuevaContrasena,
    Uint8List? archivoLicencia,
    String? nombreArchivoLicencia,
  }) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.actualizarUsuarioCompleto(
        usuario: usuario,
        nuevaContrasena: nuevaContrasena,
        archivoLicencia: archivoLicencia,
        nombreArchivoLicencia: nombreArchivoLicencia,
      );

      _mensajeExito = 'Los datos del usuario se actualizaron correctamente.';
      return true;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Error al actualizar usuario en Cloud Functions: $error');
      _mensajeError = _mensajeErrorFunctions(error);
      return false;
    } on FirebaseException catch (error) {
      debugPrint(
        'Error de Firebase al actualizar usuario: '
        '${error.code} - ${error.message}',
      );
      _mensajeError = _mensajeErrorStorage(error.code);
      return false;
    } on ArgumentError catch (error) {
      _mensajeError =
          error.message?.toString() ?? 'Revisa los datos ingresados.';
      return false;
    } on TimeoutException {
      _mensajeError =
          'La carga del documento tardó demasiado. '
          'Revisa tu conexión e inténtalo otra vez.';
      return false;
    } catch (error) {
      debugPrint('Error al actualizar usuario: $error');
      _mensajeError =
          'No se pudieron guardar los cambios. Inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  // Elimina un usuario mediante el repositorio.
  // Entrada: uid, identificador del usuario que se eliminará.
  // Salida: true si se elimina correctamente; false si ocurre un error
  // o ya hay otra operación en curso.
  Future<bool> eliminarUsuario(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.eliminarUsuario(uid);
      _mensajeExito = 'El usuario se eliminó correctamente.';
      return true;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Error al eliminar usuario: ${error.code}');
      _mensajeError = _mensajeErrorFunctions(error);
      return false;
    } catch (error) {
      debugPrint('Error al eliminar usuario: $error');
      _mensajeError = 'No se pudo eliminar el usuario. Inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  // Limpia los mensajes actuales y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; deja los mensajes en null.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Activa el estado de carga, limpia los mensajes y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; establece cargando en true.
  void _iniciarOperacion() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Desactiva el estado de carga y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; establece cargando en false.
  void _finalizarOperacion() {
    _cargando = false;
    notifyListeners();
  }

  // Convierte un código de error de Firebase Authentication en un mensaje.
  // Entrada: code, código devuelto por Firebase Authentication.
  // Salida: mensaje comprensible para el usuario.
  String _mensajeErrorAuth(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo.';
      case 'invalid-email':
        return 'Escribe un correo electrónico válido.';
      case 'network-request-failed':
        return 'No hay conexión. Revisa tu internet e inténtalo de nuevo.';
      default:
        return 'Firebase no pudo crear la cuenta ($code).';
    }
  }

  // Convierte un código de error de Firebase Storage en un mensaje.
  // Entrada: code, código devuelto durante la carga del archivo.
  // Salida: mensaje comprensible para el usuario.
  String _mensajeErrorStorage(String code) {
    switch (code) {
      case 'unauthorized':
      case 'storage/unauthorized':
        return 'Firebase Storage rechazó el archivo. Revisa las reglas de acceso.';
      case 'canceled':
      case 'storage/canceled':
        return 'La carga del documento fue cancelada.';
      case 'retry-limit-exceeded':
      case 'storage/retry-limit-exceeded':
        return 'Se agotó el tiempo para subir el documento. Revisa tu conexión.';
      case 'object-not-found':
      case 'storage/object-not-found':
        return 'No se encontró el archivo en Firebase Storage.';
      default:
        return 'No se pudo subir el documento a Firebase Storage ($code).';
    }
  }

  // Convierte una excepción de Cloud Functions en un mensaje.
  // Entrada: error devuelto por Firebase Cloud Functions.
  // Salida: mensaje comprensible para el usuario.
  String _mensajeErrorFunctions(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Tu sesión terminó. Inicia sesión nuevamente.';
      case 'not-found':
        return 'No se encontró al usuario que intentas modificar.';
      case 'failed-precondition':
        return error.message ??
            'No se puede completar esta operación todavía.';
      case 'unavailable':
        return 'El servicio no está disponible. Inténtalo más tarde.';
      default:
        return error.message ?? 'La operación no pudo completarse.';
    }
  }
}