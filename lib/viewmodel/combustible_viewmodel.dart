import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/combustible_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/combustible_repositorie.dart';
import '../repositories/vehiculo_repositorie.dart';

// Coordina las operaciones de combustible entre la interfaz y los repositorios.
class CombustibleViewModel extends ChangeNotifier {
  // Repositorio que consulta y administra cargas de combustible.
  final CombustibleRepositorie _repositorio;

  // Repositorio que consulta vehículos.
  final VehiculoRepositorie _vehiculoRepositorio;

  // Crea el ViewModel con los repositorios proporcionados o los predeterminados.
  // Entradas: repositorio y vehiculoRepositorio son dependencias opcionales.
  // Salida: una instancia de CombustibleViewModel configurada.
  CombustibleViewModel({
    CombustibleRepositorie? repositorio,
    VehiculoRepositorie? vehiculoRepositorio,
  })  : _repositorio = repositorio ?? CombustibleRepositorie(),
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

  // Obtiene las cargas, opcionalmente filtradas por vehículo.
  // Entrada: vehiculoUid opcional para limitar los resultados.
  // Salida: un flujo con la lista de cargas.
  Stream<List<CombustibleModel>> obtenerCargas({
    String? vehiculoUid,
  }) {
    return _repositorio.obtenerCargas(vehiculoUid: vehiculoUid);
  }

  // Valida y registra una carga de combustible.
  // Entrada: carga con los datos que se desean guardar.
  // Salida: true si se registra correctamente; false si la validación falla
  // o si ocurre un error.
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

  // Valida y actualiza una carga de combustible existente.
  // Entrada: carga con el identificador y los datos actualizados.
  // Salida: true si se actualiza correctamente; false si los datos no son
  // válidos o si ocurre un error.
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

  // Elimina una carga de combustible.
  // Entrada: uid, identificador de la carga que se eliminará.
  // Salida: true si se elimina correctamente; false si el identificador no es
  // válido o si ocurre un error.
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

  // Calcula el rendimiento en kilómetros por litro de una carga.
  // Entradas: cargas ordenadas por fecha y indiceActual de la carga evaluada.
  // Salida: rendimiento en km/L o null si no se puede calcular.
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

  // Valida los datos de una carga de combustible.
  // Entrada: carga cuyos campos se van a revisar.
  // Salida: mensaje de error si hay datos inválidos; de lo contrario, null.
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

  // Convierte una excepción en un mensaje comprensible para el usuario.
  // Entrada: error recibido durante una operación.
  // Salida: texto descriptivo del problema.
  String _mensajeAmigable(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthenticated':
          return 'Tu sesión venció. Inicia sesión nuevamente.';
        case 'unavailable':
          return 'No hay conexión con el servicio. Inténtalo de nuevo.';
      }
    }

    return 'Ocurrió un error. Verifica tu conexión e inténtalo nuevamente.';
  }

  // Limpia los mensajes actuales y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; deja los mensajes en null.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Activa el estado de carga, limpia los mensajes anteriores y notifica.
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
}