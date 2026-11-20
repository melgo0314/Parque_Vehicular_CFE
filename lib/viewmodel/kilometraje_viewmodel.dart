import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/repositories/vehiculo_repositorie.dart';
import '../models/kilometraje_model.dart';
import '../repositories/kilometraje_repositorie.dart';

// Coordina las operaciones de kilometraje entre la interfaz y los repositorios.
class KilometrajeViewModel extends ChangeNotifier {
  final KilometrajeRepositorie _repositorio;
  final VehiculoRepositorie _vehiculoRepositorio;

  KilometrajeViewModel({
    KilometrajeRepositorie? repositorio,
    VehiculoRepositorie? vehiculoRepositorio,
  })  : _repositorio = repositorio ?? KilometrajeRepositorie(),
        _vehiculoRepositorio =
            vehiculoRepositorio ?? VehiculoRepositorie();

  bool _cargando = false;
  String? _mensajeError;
  String? _mensajeExito;

  bool get cargando => _cargando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  // Obtiene los vehículos disponibles.
  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _vehiculoRepositorio.obtenerVehiculos();
  }

  // Obtiene registros de kilometraje.
  Stream<List<KilometrajeModel>> obtenerRegistros({
    String? vehiculoUid,
  }) {
    return _repositorio.obtenerRegistros(vehiculoUid: vehiculoUid);
  }

  // Valida y registra el inicio de una jornada.
  Future<bool> registrarKilometraje(KilometrajeModel registro) async {
    final error = _validarInicio(registro);

    if (error != null) {
      _mensajeError = error;
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.registrarKilometraje(registro);
      _mensajeExito = 'El kilometraje se registró correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Valida y finaliza una jornada pendiente.
  Future<bool> finalizarKilometraje({
    required String uid,
    required int kilometrajeFinal,
    String observaciones = '',
  }) async {
    if (uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador de la jornada.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    if (kilometrajeFinal < 0) {
      _mensajeError = 'Ingresa un kilometraje final válido.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.finalizarKilometraje(
        uid: uid,
        kilometrajeFinal: kilometrajeFinal,
        observaciones: observaciones,
      );

      _mensajeExito = 'El kilometraje se finalizó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Actualiza un registro finalizado.
  Future<bool> actualizarKilometraje(KilometrajeModel registro) async {
    final error = _validarRegistroFinalizado(registro);

    if (error != null) {
      _mensajeError = error;
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    if (registro.uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador del registro.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.actualizarKilometraje(registro);
      _mensajeExito = 'El registro se actualizó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Elimina una jornada.
  Future<bool> eliminarKilometraje(String uid) async {
    if (uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador del registro.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.eliminarKilometraje(uid);
      _mensajeExito = 'El registro se eliminó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Valida los datos necesarios para iniciar una jornada.
  String? _validarInicio(KilometrajeModel registro) {
    if (registro.vehiculoUid.trim().isEmpty) {
      return 'Selecciona un vehículo.';
    }

    if (registro.kilometrajeIni < 0) {
      return 'El kilometraje inicial no puede ser negativo.';
    }

    if (registro.fecha.isAfter(DateTime.now())) {
      return 'La fecha no puede ser posterior al día de hoy.';
    }

    return null;
  }

  // Valida los datos de una jornada finalizada.
  String? _validarRegistroFinalizado(KilometrajeModel registro) {
    if (registro.vehiculoUid.trim().isEmpty) {
      return 'Selecciona un vehículo.';
    }

    if (registro.kilometrajeFinal == null ||
        registro.kilometrajeFinal! <= registro.kilometrajeIni) {
      return 'El kilometraje final debe ser mayor que el inicial.';
    }

    return null;
  }

  // Convierte una excepción en un mensaje comprensible.
  String _mensajeAmigable(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Revisa los datos del registro.';
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'No tienes permiso para realizar esta acción.';
      }

      if (error.code == 'unauthenticated') {
        return 'Tu sesión venció. Inicia sesión nuevamente.';
      }

      if (error.code == 'unavailable') {
        return 'No hay conexión con el servicio. Inténtalo de nuevo.';
      }
    }

    return 'Ocurrió un error. Verifica tu conexión e inténtalo nuevamente.';
  }

  // Limpia los mensajes actuales.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Activa el estado de carga.
  void _iniciarCarga() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Desactiva el estado de carga.
  void _terminarCarga() {
    _cargando = false;
    notifyListeners();
  }
}
