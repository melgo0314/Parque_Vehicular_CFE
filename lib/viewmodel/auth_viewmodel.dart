import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/user_model.dart';
import 'package:p_vehicular/repositories/auth_repositorie.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  String? _loginError;
  String? get loginError => _loginError;

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
            'usuario.';
        debugPrint(
          'Login: Auth succeeded, but usuario/${authenticatedUser.uid} is missing.',
        );
        return null;
      }

      final role = profile.rol.trim().toLowerCase();
      const allowedRoles = {'administrador', 'operador', 'superusuario'};
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
      if (authenticatedUser != null) await _signOutSafely();
      _loginError = error.code == 'permission-denied'
          ? 'Firebase autenticó la cuenta, pero Firestore denegó la lectura '
          : 'No se pudo consultar el perfil en Firebase (${error.code}).';
      return null;
    } catch (error, stackTrace) {
      debugPrint('Unexpected login error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (authenticatedUser != null) await _signOutSafely();
      _loginError = 'Ocurrió un error inesperado al iniciar sesión.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
          'No se pudo autenticar la cuenta (${code.isEmpty ? 'error' : code}).',
      };

  Future<void> _signOutSafely() async {
    try {
      await _repository.logout();
    } catch (error) {
      debugPrint('Could not clear the partially opened session: $error');
    }
  }

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

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }
}