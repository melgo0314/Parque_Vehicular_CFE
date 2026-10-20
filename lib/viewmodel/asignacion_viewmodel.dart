import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/asignacion_model.dart';
import '../models/user_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/asignacion_repositorie.dart';

class AsignacionViewModel extends ChangeNotifier {
  AsignacionViewModel({
    AsignacionRepositorie? repositorio,
  }) : _repositorio = repositorio ?? AsignacionRepositorie();

  final AsignacionRepositorie _repositorio;

  bool _cargando = false;
  bool _disposed = false;
  String? _mensajeError;
  String? _mensajeExito;

  bool get cargando => _cargando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  void _notificarCambios() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Stream<List<AsignacionModel>> obtenerAsignaciones({
    String busqueda = '',
    String estado = 'todas',
  }) {
    return _repositorio.obtenerAsignaciones(
      busqueda: busqueda,
      estado: estado,
    );
  }

  Future<List<UserModel>> obtenerOperadoresDisponibles({
    String? excluirAsignacionUid,
  }) {
    return _repositorio.obtenerOperadoresDisponibles(
      excluirAsignacionUid: excluirAsignacionUid,
    );
  }

  Future<List<VehiculoModel>> obtenerVehiculosDisponibles({
    String? excluirAsignacionUid,
  }) {
    return _repositorio.obtenerVehiculosDisponibles(
      excluirAsignacionUid: excluirAsignacionUid,
    );
  }

  Future<bool> crearAsignacion({
    required String operadorUid,
    required String vehiculoUid,
    required DateTime fechaInicio,
    String tipo = 'permanente',
    DateTime? fechaFin,
    String motivoTemporal = '',
  }) {
    return _ejecutarOperacion(
      exito: 'La asignación se creó correctamente.',
      operacion: () => _repositorio.crearAsignacion(
        operadorUid: operadorUid,
        vehiculoUid: vehiculoUid,
        fechaInicio: fechaInicio,
        tipo: tipo,
        fechaFin: fechaFin,
        motivoTemporal: motivoTemporal,
      ),
    );
  }

  Future<bool> actualizarAsignacion(AsignacionModel asignacion) {
    return _ejecutarOperacion(
      exito: 'La asignación se actualizó correctamente.',
      operacion: () => _repositorio.actualizarAsignacion(asignacion),
    );
  }

  Future<bool> finalizarAsignacion(String uidAsignacion) {
    return _ejecutarOperacion(
      exito: 'La asignación se finalizó correctamente.',
      operacion: () => _repositorio.finalizarAsignacion(uidAsignacion),
    );
  }

  Future<bool> _ejecutarOperacion({
    required String exito,
    required Future<void> Function() operacion,
  }) async {
    if (_cargando) return false;

    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    _notificarCambios();

    try {
      await operacion();
      _mensajeExito = exito;
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _cargando = false;
      _notificarCambios();
    }
  }

  String _mensajeAmigable(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return 'No hay conexión con el servicio. Revisa tu conexión e inténtalo de nuevo.';
        case 'already-exists':
          return 'La asignación ya existe.';
        case 'not-found':
          return 'No se encontró el registro solicitado.';
        default:
          return 'Ocurrió un error al guardar la asignación. Inténtalo nuevamente.';
      }
    }

    return 'Ocurrió un error inesperado. Inténtalo nuevamente.';
  }

  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    _notificarCambios();
  }
}