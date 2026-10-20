import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/vehiculos_model.dart';
import '../repositories/vehiculo_repositorie.dart';

class VehiculosViewModel extends ChangeNotifier {
  VehiculosViewModel({VehiculoRepositorie? repositorio})
      : _repositorio = repositorio ?? VehiculoRepositorie();

  final VehiculoRepositorie _repositorio;

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  String? _mensajeExito;
  String? get mensajeExito => _mensajeExito;

  Stream<List<VehiculoModel>> obtenerVehiculos({
    String busqueda = '',
    bool incluirBaja = false,
  }) {
    return _repositorio.obtenerVehiculos(
      busqueda: busqueda,
      incluirBaja: incluirBaja,
    );
  }

  Future<bool> registrarVehiculo(VehiculoModel vehiculo) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.registrarVehiculo(vehiculo);
      _mensajeExito = 'El vehículo se registró correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError = error.message?.toString() ?? 'Revisa los datos ingresados.';
      return false;
    } on FirebaseException catch (error) {
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      debugPrint('Error al registrar vehículo: $error');
      _mensajeError =
          'No se pudo registrar el vehículo. Inténtalo nuevamente.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  Future<bool> actualizarVehiculo(VehiculoModel vehiculo) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.actualizarVehiculo(vehiculo);
      _mensajeExito = 'Los datos del vehículo se actualizaron correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError = error.message?.toString() ?? 'Revisa los datos ingresados.';
      return false;
    } on StateError catch (error) {
      _mensajeError = error.message;
      return false;
    } on FirebaseException catch (error) {
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      debugPrint('Error al actualizar vehículo: $error');
      _mensajeError =
          'No se pudieron guardar los cambios. Inténtalo nuevamente.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  Future<bool> darDeBaja(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.darDeBaja(uid);
      _mensajeExito = 'El vehículo se dio de baja correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError = error.message?.toString() ?? 'No se recibió el vehículo.';
      return false;
    } on StateError catch (error) {
      _mensajeError = error.message;
      return false;
    } on FirebaseException catch (error) {
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      debugPrint('Error al dar de baja el vehículo: $error');
      _mensajeError = 'No se pudo dar de baja el vehículo.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  Future<bool> reactivarVehiculo(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.reactivarVehiculo(uid);
      _mensajeExito = 'El vehículo se reactivó correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError = error.message?.toString() ?? 'No se recibió el vehículo.';
      return false;
    } on StateError catch (error) {
      _mensajeError = error.message;
      return false;
    } on FirebaseException catch (error) {
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      debugPrint('Error al reactivar el vehículo: $error');
      _mensajeError = 'No se pudo reactivar el vehículo.';
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

  String _mensajeFirebase(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'No tienes permiso para realizar esta operación.';
      case 'unavailable':
        return 'Firebase no está disponible. Revisa tu conexión.';
      case 'already-exists':
        return error.message ?? 'Ya existe un vehículo con esos datos.';
      default:
        debugPrint('Error Firebase ${error.code}: ${error.message}');
        return 'Firebase no pudo completar la operación.';
    }
  }
}