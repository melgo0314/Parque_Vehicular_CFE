import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/kilometraje_model.dart';
import '../repositories/kilometraje_repositorie.dart';

class KilometrajeViewModel extends ChangeNotifier {
  final KilometrajeRepositorie _repositorio = KilometrajeRepositorie();

  bool _cargando = false;
  String? _mensajeError;
  String? _mensajeExito;

  bool get cargando => _cargando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  // Obtiene los registros. Si se indica un vehículo, filtra por ese vehículo.
  Stream<List<KilometrajeModel>> obtenerRegistros({
    String? vehiculoUid,
  }) {
    return _repositorio.obtenerRegistros(vehiculoUid: vehiculoUid);
  }

  Future<bool> registrarKilometraje(KilometrajeModel registro) async {
    final error = _validar(registro);

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

  Future<bool> actualizarKilometraje(KilometrajeModel registro) async {
    final error = _validar(registro);

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

  String? _validar(KilometrajeModel registro) {
    if (registro.vehiculoUid.trim().isEmpty) {
      return 'Selecciona un vehículo.';
    }

    if (registro.kilometrajeIni < 0) {
      return 'El kilometraje inicial no puede ser negativo.';
    }

    if (registro.kilometrajeFinal <= registro.kilometrajeIni) {
      return 'El kilometraje final debe ser mayor que el inicial.';
    }

    if (registro.fecha.isAfter(DateTime.now())) {
      return 'La fecha no puede ser posterior al día de hoy.';
    }

    return null;
  }

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

  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  void _iniciarCarga() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  void _terminarCarga() {
    _cargando = false;
    notifyListeners();
  }
}