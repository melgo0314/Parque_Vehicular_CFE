import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import '../models/mantenimiento_model.dart';
import '../repositories/mantenimiento_repositorie.dart';

// Coordina las operaciones de mantenimiento entre la interfaz y el repositorio.
class MantenimientoViewModel extends ChangeNotifier {
  // Repositorio que consulta y administra los datos de mantenimiento.
  final MantenimientoRepositorie _repositorio = MantenimientoRepositorie();

  // Indica si hay una operación en curso.
  bool _cargando = false;

  // Contiene el mensaje de error actual, si existe.
  String? _mensajeError;

  // Contiene el mensaje de éxito actual, si existe.
  String? _mensajeExito;

  // Devuelve el estado actual de carga.
  bool get cargando => _cargando;

  // Devuelve el mensaje de error actual.
  String? get mensajeError => _mensajeError;

  // Devuelve el mensaje de éxito actual.
  String? get mensajeExito => _mensajeExito;

  // Obtiene los vehículos disponibles.
  // Entrada: ninguna.
  // Salida: un flujo con la lista de vehículos.
  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _repositorio.obtenerVehiculos();
  }

  // Obtiene el historial de mantenimientos de un vehículo.
  // Entrada: vehiculoUid, identificador del vehículo que se consultará.
  // Salida: un flujo con los mantenimientos del vehículo.
  Stream<List<MantenimientoModel>> obtenerMantenimientos({
    required String vehiculoUid,
  }) {
    return _repositorio.obtenerMantenimientos(
      vehiculoUid: vehiculoUid,
    );
  }

  // Registra un mantenimiento y actualiza los mensajes de estado.
  // Entrada: mantenimiento con los datos del servicio y sus refacciones.
  // Salida: true si se registra correctamente; false si ocurre un error.
  Future<bool> registrarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    _iniciarOperacion();

    try {
      await _repositorio.registrarMantenimiento(mantenimiento);
      _mensajeExito = 'Mantenimiento registrado correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarOperacion();
    }
  }

  // Actualiza un mantenimiento existente.
  // Entrada: mantenimiento con el identificador y los datos actualizados.
  // Salida: true si se actualiza correctamente; false si ocurre un error.
  Future<bool> actualizarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    _iniciarOperacion();

    try {
      await _repositorio.actualizarMantenimiento(mantenimiento);
      _mensajeExito = 'Mantenimiento actualizado correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarOperacion();
    }
  }

  // Elimina un mantenimiento y los detalles relacionados.
  // Entrada: mantenimientoUid, identificador del mantenimiento que se eliminará.
  // Salida: true si se elimina correctamente; false si ocurre un error.
  Future<bool> eliminarMantenimiento(String mantenimientoUid) async {
    _iniciarOperacion();

    try {
      await _repositorio.eliminarMantenimiento(mantenimientoUid);
      _mensajeExito = 'Mantenimiento eliminado correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarOperacion();
    }
  }

  // Activa el estado de carga, limpia mensajes anteriores y notifica a la interfaz.
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
  void _terminarOperacion() {
    _cargando = false;
    notifyListeners();
  }

  // Convierte una excepción en un mensaje comprensible para el usuario.
  // Entrada: error recibido durante una operación.
  // Salida: texto que describe el problema o sugiere qué hacer.
  String _mensajeAmigable(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }

    if (error is FirebaseException) {
      if (error.code == 'unavailable') {
        return 'No hay conexión. Revisa tu conexión e inténtalo de nuevo.';
      }

      if (error.code == 'permission-denied') {
        return 'No tienes permiso para realizar esta operación.';
      }

      return 'Ocurrió un error al guardar la información. '
          'Inténtalo nuevamente.';
    }

    return 'Ocurrió un error inesperado. Inténtalo nuevamente.';
  }

  // Limpia los mensajes actuales y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; deja los mensajes en null.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }
}