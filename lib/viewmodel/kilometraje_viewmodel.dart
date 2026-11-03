import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/repositories/vehiculo_repositorie.dart';
import '../models/kilometraje_model.dart';
import '../repositories/kilometraje_repositorie.dart';

// Coordina las operaciones de kilometraje entre la interfaz y los repositorios.
class KilometrajeViewModel extends ChangeNotifier {
  // Repositorio para consultar y modificar registros de kilometraje.
  final KilometrajeRepositorie _repositorio;

  // Repositorio para consultar vehículos.
  final VehiculoRepositorie _vehiculoRepositorio;

  // Crea el ViewModel con los repositorios proporcionados o los predeterminados.
  // Entradas: repositorio y vehiculoRepositorio son dependencias opcionales.
  // Salida: una instancia de KilometrajeViewModel configurada.
  KilometrajeViewModel({
    KilometrajeRepositorie? repositorio,
    VehiculoRepositorie? vehiculoRepositorio,
  })  : _repositorio = repositorio ?? KilometrajeRepositorie(),
        _vehiculoRepositorio =
            vehiculoRepositorio ?? VehiculoRepositorie();

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
    return _vehiculoRepositorio.obtenerVehiculos();
  }

  // Obtiene registros de kilometraje, opcionalmente filtrados por vehículo.
  // Entrada: vehiculoUid opcional para filtrar los registros.
  // Salida: un flujo con la lista de registros de kilometraje.
  Stream<List<KilometrajeModel>> obtenerRegistros({
    String? vehiculoUid,
  }) {
    return _repositorio.obtenerRegistros(vehiculoUid: vehiculoUid);
  }

  // Valida y registra un nuevo registro de kilometraje.
  // Entrada: registro con la información que se desea guardar.
  // Salida: true si se registra correctamente; false si los datos no son
  // válidos o ocurre un error.
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

  // Valida y actualiza un registro de kilometraje existente.
  // Entrada: registro con el identificador y los datos actualizados.
  // Salida: true si se actualiza correctamente; false si la validación falla
  // o ocurre un error.
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

  // Elimina un registro de kilometraje.
  // Entrada: uid del registro que se desea eliminar.
  // Salida: true si se elimina correctamente; false si el identificador no
  // es válido o ocurre un error.
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

  // Comprueba que los datos del registro sean válidos.
  // Entrada: registro cuyos campos se van a validar.
  // Salida: mensaje de error si hay datos inválidos; de lo contrario, null.
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

  // Convierte una excepción en un mensaje comprensible para el usuario.
  // Entrada: error recibido durante una operación.
  // Salida: texto que describe el problema y, cuando es posible, cómo resolverlo.
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

  // Limpia los mensajes actuales y notifica el cambio a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; deja los mensajes en null.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Activa el estado de carga, limpia los mensajes y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; establece cargando en true.
  void _iniciarCarga() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Desactiva el estado de carga y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; establece cargando en false.
  void _terminarCarga() {
    _cargando = false;
    notifyListeners();
  }
}