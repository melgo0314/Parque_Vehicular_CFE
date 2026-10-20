import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../repositories/usuario_repositorie.dart';

class UsuariosViewModel extends ChangeNotifier {
  UsuariosViewModel({UsuariosRepositorie? repositorio})
      : _repositorio = repositorio ?? UsuariosRepositorie();

  final UsuariosRepositorie _repositorio;

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  String? _mensajeExito;
  String? get mensajeExito => _mensajeExito;

  Stream<List<UserModel>> obtenerUsuarios({
    String busqueda = '',
    String? rol,
  }) {
    return _repositorio.obtenerUsuarios(
      busqueda: busqueda,
      rol: rol,
    );
  }

  Future<bool> registrarUsuario({
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
        fotoLicencia: fotoLicencia,
      );

      _mensajeExito = 'El usuario se registró correctamente.';
      return true;
    } on FirebaseAuthException catch (error) {
      _mensajeError = _mensajeErrorAuth(error.code);
      return false;
    } on FirebaseFunctionsException catch (error) {
      _mensajeError = _mensajeErrorFunctions(error);
      return false;
    } on ArgumentError catch (error) {
      _mensajeError = error.message?.toString() ?? 'Revisa los datos ingresados.';
      return false;
    } catch (error) {
      debugPrint('Error al registrar usuario: $error');
      _mensajeError =
          'No se pudo registrar el usuario. Revisa tu conexión e inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  Future<bool> actualizarUsuario(UserModel usuario) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.actualizarUsuario(usuario);
      _mensajeExito = 'Los datos del usuario se actualizaron correctamente.';
      return true;
    } on FirebaseException catch (error) {
      debugPrint('Error de Firebase al actualizar usuario: ${error.code}');
      _mensajeError = error.code == 'permission-denied'
          ? 'No tienes permiso para actualizar este usuario.'
          : 'No se pudieron guardar los cambios. Inténtalo de nuevo.';
      return false;
    } catch (error) {
      debugPrint('Error al actualizar usuario: $error');
      _mensajeError = 'No se pudieron guardar los cambios. Inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  Future<bool> actualizarUsuarioCompleto({
    required UserModel usuario,
    String? nuevaContrasena,
  }) async {
    if (_cargando) return false;
    _iniciarOperacion();

    try {
      await _repositorio.actualizarUsuarioCompleto(
        usuario: usuario,
        nuevaContrasena: nuevaContrasena,
      );

      _mensajeExito = 'Los datos del usuario se actualizaron correctamente.';
      return true;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Error al actualizar usuario: ${error.code}');
      _mensajeError = _mensajeErrorFunctions(error);
      return false;
    } catch (error) {
      debugPrint('Error al actualizar usuario: $error');
      _mensajeError = 'No se pudieron guardar los cambios. Inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  Future<bool> eliminarUsuario(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.eliminarUsuario(uid);
      _mensajeExito = 'El usuario se eliminó correctamente.';
      return true;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Error de Cloud Function al eliminar usuario: ${error.code}');
      _mensajeError = _mensajeErrorFunctions(error);
      return false;
    } catch (error) {
      debugPrint('Error al eliminar usuario: $error');
      _mensajeError =
          'No se pudo eliminar el usuario. Inténtalo de nuevo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  void _iniciarOperacion() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  void _finalizarOperacion() {
    _cargando = false;
    notifyListeners();
  }

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

  String _mensajeErrorFunctions(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Tu sesión terminó. Inicia sesión nuevamente.';
      case 'not-found':
        return 'No se encontró al usuario que intentas eliminar.';
      case 'failed-precondition':
        return error.message ?? 'No se puede completar esta operación todavía.';
      case 'unavailable':
        return 'El servicio no está disponible. Inténtalo más tarde.';
      default:
        return error.message ?? 'La operación no pudo completarse.';
    }
  }
}