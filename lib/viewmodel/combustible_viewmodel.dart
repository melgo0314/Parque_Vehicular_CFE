import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/combustible_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/combustible_repositorie.dart';
import '../repositories/vehiculo_repositorie.dart';

class CombustibleViewModel extends ChangeNotifier {
  final CombustibleRepositorie _repositorio;
  final VehiculoRepositorie _vehiculoRepositorio;

  CombustibleViewModel({
    CombustibleRepositorie? repositorio,
    VehiculoRepositorie? vehiculoRepositorio,
  }) : _repositorio = repositorio ?? CombustibleRepositorie(),
       _vehiculoRepositorio = vehiculoRepositorio ?? VehiculoRepositorie();

  bool _cargando = false;
  String? _mensajeError;
  String? _mensajeExito;

  bool get cargando => _cargando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _vehiculoRepositorio.obtenerVehiculos();
  }

  Stream<List<CombustibleModel>> obtenerCargas({String? vehiculoUid}) {
    return _repositorio.obtenerCargas(vehiculoUid: vehiculoUid);
  }

  Future<bool> registrarCarga(CombustibleModel carga) async {
    final errorValidacion = _validar(carga);

    if (errorValidacion != null) {
      _mensajeError = errorValidacion;
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarOperacion();

    try {
      await _repositorio.registrarCarga(carga);
      _mensajeExito = 'La carga de combustible se registró correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarOperacion();
    }
  }

  Future<bool> actualizarCarga(CombustibleModel carga) async {
    final errorValidacion = _validar(carga);

    if (errorValidacion != null) {
      _mensajeError = errorValidacion;
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    if (carga.uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador de la carga.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarOperacion();

    try {
      await _repositorio.actualizarCarga(carga);
      _mensajeExito = 'La carga de combustible se actualizó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarOperacion();
    }
  }

  Future<bool> eliminarCarga(String uid) async {
    if (uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador de la carga.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarOperacion();

    try {
      await _repositorio.eliminarCarga(uid);
      _mensajeExito = 'La carga se eliminó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarOperacion();
    }
  }

  /// La lista debe estar ordenada de la carga más reciente a la más antigua.
  double? calcularRendimientoKmL(
    List<CombustibleModel> cargas,
    int indiceActual,
  ) {
    if (indiceActual < 0 ||
        indiceActual >= cargas.length ||
        indiceActual + 1 >= cargas.length) {
      return null;
    }

    final cargaActual = cargas[indiceActual];
    final cargaAnterior = cargas[indiceActual + 1];

    if (cargaActual.vehiculoUid != cargaAnterior.vehiculoUid ||
        cargaActual.litros <= 0) {
      return null;
    }

    final kilometrosRecorridos =
        cargaActual.kilometraje - cargaAnterior.kilometraje;

    if (kilometrosRecorridos <= 0) {
      return null;
    }

    return kilometrosRecorridos / cargaActual.litros;
  }

  String? _validar(CombustibleModel carga) {
    if (carga.vehiculoUid.trim().isEmpty) {
      return 'Selecciona un vehículo.';
    }

    if (carga.litros <= 0) {
      return 'Los litros deben ser mayores que cero.';
    }

    if (carga.tipoCombustible.trim().isEmpty) {
      return 'Selecciona el tipo de combustible.';
    }

    if (carga.kilometraje < 0) {
      return 'El kilometraje no puede ser negativo.';
    }

    if (carga.importe <= 0) {
      return 'El importe debe ser mayor que cero.';
    }

    return null;
  }

  String _mensajeAmigable(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No tienes permiso para realizar esta acción.';
        case 'unauthenticated':
          return 'Tu sesión venció. Inicia sesión nuevamente.';
        case 'unavailable':
          return 'No hay conexión con el servicio. Inténtalo de nuevo.';
      }
    }

    return 'Ocurrió un error. Verifica tu conexión e inténtalo nuevamente.';
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

  void _terminarOperacion() {
    _cargando = false;
    notifyListeners();
  }
}