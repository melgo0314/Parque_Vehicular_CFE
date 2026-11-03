import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/user_model.dart';
import 'package:p_vehicular/repositories/auth_repositorie.dart';

// Coordina la autenticación y comunica el estado de sesión a la interfaz.
class AuthViewModel extends ChangeNotifier {
  // Repositorio que realiza las operaciones de autenticación y consulta.
  final AuthRepository _repository = AuthRepository();

  // Indica si hay una operación de autenticación en curso.
  bool _isLoading = false;

  // Devuelve el estado actual de carga.
  bool get isLoading => _isLoading;

  // Contiene los datos del usuario autenticado, si existen.
  UserModel? _currentUser;

  // Devuelve el usuario autenticado actual.
  UserModel? get currentUser => _currentUser;

  // Contiene el mensaje del último error de inicio de sesión.
  String? _loginError;

  // Devuelve el mensaje del último error.
  String? get loginError => _loginError;

  // Inicia sesión, consulta el perfil y valida el rol del usuario.
  // Entradas: email y password del usuario.
  // Salida: rol del usuario si el inicio de sesión es correcto; null si falla.
  Future<String?> login(String email, String password) async {
    if (_isLoading) return null;

    _isLoading = true;
    _currentUser = null;
    _loginError = null;
    notifyListeners();

    User? authenticatedUser;

    try {
      final credential = await _repository.loginWithEmail(email, password);
      authenticatedUser = credential.user;

      if (authenticatedUser == null) {
        _loginError = 'Firebase no devolvió una cuenta autenticada.';
        return null;
      }

      final profile = await _repository.getUserData(authenticatedUser.uid);

      if (profile == null) {
        await _signOutSafely();
        _loginError =
            'La contraseña fue aceptada, pero no se encontró el perfil en '
            'la colección de usuarios.';
        debugPrint(
          'Login: Auth succeeded, but usuario/${authenticatedUser.uid} is missing.',
        );
        return null;
      }

      final role = profile.rol.trim().toLowerCase();
      const allowedRoles = {
        'administrador',
        'operador',
        'superusuario',
      };

      if (!allowedRoles.contains(role)) {
        await _signOutSafely();
        _loginError =
            'El perfil existe, pero el campo rol no tiene un valor reconocido.';
        debugPrint('Login: unrecognized role "$role" in the user profile.');
        return null;
      }

      _currentUser = profile;
      return role;
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('Firebase Authentication login error: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      _loginError = _authErrorMessage(error.code);
      return null;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('${error.plugin} login/profile error: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);

      if (authenticatedUser != null) {
        await _signOutSafely();
      }

      _loginError = error.code == 'permission-denied'
          ? 'Firebase autenticó la cuenta, pero Firestore denegó la lectura '
              'del perfil.'
          : 'No se pudo consultar el perfil en Firebase (${error.code}).';

      return null;
    } catch (error, stackTrace) {
      debugPrint('Unexpected login error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (authenticatedUser != null) {
        await _signOutSafely();
      }

      _loginError = 'Ocurrió un error inesperado al iniciar sesión.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Traduce un código de error de Firebase Authentication a un mensaje.
  // Entrada: code, código devuelto por Firebase Authentication.
  // Salida: mensaje comprensible para mostrar al usuario.
  String _authErrorMessage(String code) => switch (code) {
        'invalid-email' => 'El correo no tiene un formato válido.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'El correo o la contraseña no son correctos.',
        'too-many-requests' =>
          'Hubo demasiados intentos. Espera un momento e inténtalo de nuevo.',
        'network-request-failed' =>
          'No se pudo conectar. Revisa tu conexión a internet.',
        _ =>
          'No se pudo autenticar la cuenta '
              '(${code.isEmpty ? 'error' : code}).',
      };

  // Intenta cerrar una sesión que quedó abierta durante un inicio fallido.
  // Entrada: ninguna.
  // Salida: ninguna; registra el error si no se pudo cerrar la sesión.
  Future<void> _signOutSafely() async {
    try {
      await _repository.logout();
    } catch (error) {
      debugPrint('Could not clear the partially opened session: $error');
    }
  }

  // Solicita a Firebase el envío de un enlace para restablecer la contraseña.
  // Entrada: email al que se enviará el enlace.
  // Salida: true si Firebase acepta la solicitud; false si ocurre un error.
  Future<bool> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );
      return true;
    } on FirebaseAuthException catch (error) {
      debugPrint('Password reset error: ${error.code}');
      return false;
    }
  }

  // Cierra la sesión y limpia los datos del usuario actual.
  // Entrada: ninguna.
  // Salida: ninguna; elimina el usuario actual y notifica a la interfaz.
  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }
}