import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/asignacion_model.dart';
import '../models/user_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/asignacion_repositorie.dart';

// Coordina las operaciones de asignaciones entre la interfaz y el repositorio.
class AsignacionViewModel extends ChangeNotifier {
  // Crea el ViewModel con el repositorio proporcionado o uno predeterminado.
  // Entrada: repositorio opcional para consultar y modificar asignaciones.
  // Salida: una instancia configurada de AsignacionViewModel.
  AsignacionViewModel({
    AsignacionRepositorie? repositorio,
  }) : _repositorio = repositorio ?? AsignacionRepositorie();

  // Repositorio encargado de consultar y modificar asignaciones.
  final AsignacionRepositorie _repositorio;

  // Indica si hay una operación en curso.
  bool _cargando = false;

  // Indica si el ViewModel ya fue eliminado.
  bool _disposed = false;

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

  // Notifica a los widgets escuchas si el ViewModel sigue activo.
  // Entrada: ninguna.
  // Salida: ninguna; notifica los cambios cuando corresponde.
  void _notificarCambios() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // Marca el ViewModel como eliminado y libera sus recursos.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Obtiene asignaciones filtradas por texto y estado.
  // Entradas: busqueda opcional y estado por el que se filtrarán los resultados.
  // Salida: un flujo con la lista de asignaciones.
  Stream<List<AsignacionModel>> obtenerAsignaciones({
    String busqueda = '',
    String estado = 'todas',
  }) {
    return _repositorio.obtenerAsignaciones(
      busqueda: busqueda,
      estado: estado,
    );
  }

  // Obtiene los operadores disponibles para una asignación.
  // Entrada: excluirAsignacionUid opcional para excluir una asignación existente.
  // Salida: una lista de operadores disponibles.
  Future<List<UserModel>> obtenerOperadoresDisponibles({
    String? excluirAsignacionUid,
  }) {
    return _repositorio.obtenerOperadoresDisponibles(
      excluirAsignacionUid: excluirAsignacionUid,
    );
  }

  // Obtiene los vehículos disponibles para una asignación.
  // Entrada: excluirAsignacionUid opcional para excluir una asignación existente.
  // Salida: una lista de vehículos disponibles.
  Future<List<VehiculoModel>> obtenerVehiculosDisponibles({
    String? excluirAsignacionUid,
  }) {
    return _repositorio.obtenerVehiculosDisponibles(
      excluirAsignacionUid: excluirAsignacionUid,
    );
  }

  // Crea una asignación y actualiza los mensajes de estado.
  // Entradas: identificadores del operador y vehículo, fecha de inicio, tipo,
  // fecha de fin opcional y motivo temporal opcional.
  // Salida: true si la operación termina correctamente; false si falla
  // o ya hay otra operación en curso.
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

  // Actualiza una asignación existente.
  // Entrada: asignacion con el identificador y los datos actualizados.
  // Salida: true si la operación termina correctamente; false si falla
  // o ya hay otra operación en curso.
  Future<bool> actualizarAsignacion(AsignacionModel asignacion) {
    return _ejecutarOperacion(
      exito: 'La asignación se actualizó correctamente.',
      operacion: () => _repositorio.actualizarAsignacion(asignacion),
    );
  }

  // Finaliza una asignación existente.
  // Entrada: uidAsignacion, identificador de la asignación que se finalizará.
  // Salida: true si la operación termina correctamente; false si falla
  // o ya hay otra operación en curso.
  Future<bool> finalizarAsignacion(String uidAsignacion) {
    return _ejecutarOperacion(
      exito: 'La asignación se finalizó correctamente.',
      operacion: () => _repositorio.finalizarAsignacion(uidAsignacion),
    );
  }

  // Ejecuta una operación del repositorio y actualiza los mensajes de estado.
  // Entradas: exito, mensaje para una operación correcta, y operacion, acción
  // asíncrona que se ejecutará.
  // Salida: true si la operación termina correctamente; false si falla
  // o ya hay otra operación en curso.
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

  // Convierte una excepción en un mensaje comprensible para el usuario.
  // Entrada: error recibido durante una operación.
  // Salida: texto que describe el problema o indica que ocurrió un error.
  String _mensajeAmigable(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return 'No hay conexión con el servicio. '
              'Revisa tu conexión e inténtalo de nuevo.';
        case 'already-exists':
          return 'La asignación ya existe.';
        case 'not-found':
          return 'No se encontró el registro solicitado.';
        default:
          return 'Ocurrió un error al guardar la asignación. '
              'Inténtalo nuevamente.';
      }
    }

    return 'Ocurrió un error inesperado. Inténtalo nuevamente.';
  }

  // Limpia los mensajes actuales y notifica a los widgets escuchas.
  // Entrada: ninguna.
  // Salida: ninguna; deja los mensajes en null.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    _notificarCambios();
  }
}