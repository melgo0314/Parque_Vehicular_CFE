import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/vehiculos_model.dart';
import '../repositories/vehiculo_repositorie.dart';

// Coordina las operaciones entre la interfaz y el repositorio de vehículos.
class VehiculosViewModel extends ChangeNotifier {
  // Crea el ViewModel con el repositorio proporcionado o uno predeterminado.
  // Entrada: repositorio opcional para consultar y modificar vehículos.
  // Salida: una instancia de VehiculosViewModel configurada.
  VehiculosViewModel({VehiculoRepositorie? repositorio})
      : _repositorio = repositorio ?? VehiculoRepositorie();

  // Repositorio encargado de comunicarse con la fuente de datos.
  final VehiculoRepositorie _repositorio;

  // Indica si hay una operación en curso.
  bool _cargando = false;

  // Guarda el mensaje de error actual, si existe.
  String? _mensajeError;

  // Guarda el mensaje de éxito actual, si existe.
  String? _mensajeExito;

  // Devuelve el estado de carga actual.
  bool get cargando => _cargando;

  // Devuelve el mensaje de error actual.
  String? get mensajeError => _mensajeError;

  // Devuelve el mensaje de éxito actual.
  String? get mensajeExito => _mensajeExito;

  // Obtiene en tiempo real los vehículos que coinciden con los filtros.
  // Entradas: busqueda opcional y bandera para incluir vehículos dados de baja.
  // Salida: un flujo con la lista de vehículos.
  Stream<List<VehiculoModel>> obtenerVehiculos({
    String busqueda = '',
    bool incluirBaja = false,
  }) {
    return _repositorio.obtenerVehiculos(
      busqueda: busqueda,
      incluirBaja: incluirBaja,
    );
  }

  // Registra un vehículo y actualiza los mensajes de estado.
  // Entrada: vehiculo con la información que se desea guardar.
  // Salida: true si el registro se completa; false si ocurre un error
  // o ya hay otra operación en curso.
  Future<bool> registrarVehiculo(VehiculoModel vehiculo) async {
    if (_cargando) return false;

    // Inicia la operación y limpia los mensajes anteriores.
    _iniciarOperacion();

    try {
      // Envía el vehículo al repositorio para guardarlo.
      await _repositorio.registrarVehiculo(vehiculo);
      _mensajeExito = 'El vehículo se registró correctamente.';
      return true;
    } on ArgumentError catch (error) {
      // Muestra un mensaje cuando los datos ingresados no son válidos.
      _mensajeError =
          error.message?.toString() ?? 'Revisa los datos ingresados.';
      return false;
    } on FirebaseException catch (error) {
      // Convierte el error de Firebase en un mensaje comprensible.
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      // Registra el error inesperado y muestra un mensaje general.
      debugPrint('Error al registrar vehículo: $error');
      _mensajeError =
          'No se pudo registrar el vehículo. Inténtalo nuevamente.';
      return false;
    } finally {
      // Finaliza la operación tanto si tuvo éxito como si falló.
      _finalizarOperacion();
    }
  }

  // Actualiza la información de un vehículo existente.
  // Entrada: vehiculo con el identificador y los datos actualizados.
  // Salida: true si la actualización se completa; false si ocurre un error
  // o ya hay otra operación en curso.
  Future<bool> actualizarVehiculo(VehiculoModel vehiculo) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.actualizarVehiculo(vehiculo);
      _mensajeExito = 'Los datos del vehículo se actualizaron correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError =
          error.message?.toString() ?? 'Revisa los datos ingresados.';
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

  // Da de baja un vehículo.
  // Entrada: uid del vehículo que se dará de baja.
  // Salida: true si la baja se completa; false si ocurre un error
  // o ya hay otra operación en curso.
  Future<bool> darDeBaja(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.darDeBaja(uid);
      _mensajeExito = 'El vehículo se dio de baja correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError =
          error.message?.toString() ?? 'No se recibió el vehículo.';
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

  // Reactiva un vehículo que estaba dado de baja.
  // Entrada: uid del vehículo que se desea reactivar.
  // Salida: true si la reactivación se completa; false si ocurre un error
  // o ya hay otra operación en curso.
  Future<bool> reactivarVehiculo(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.reactivarVehiculo(uid);
      _mensajeExito = 'El vehículo se reactivó correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError =
          error.message?.toString() ?? 'No se recibió el vehículo.';
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

  // Limpia los mensajes actuales y notifica el cambio a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; los mensajes quedan en null.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Marca el inicio de una operación y limpia los mensajes anteriores.
  // Entrada: ninguna.
  // Salida: ninguna; activa el estado de carga y notifica a la interfaz.
  void _iniciarOperacion() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Marca el final de una operación y notifica a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna; desactiva el estado de carga.
  void _finalizarOperacion() {
    _cargando = false;
    notifyListeners();
  }

  // Convierte un error de Firebase en un mensaje para mostrar en la interfaz.
  // Entrada: error de Firebase que contiene el código y el mensaje.
  // Salida: texto que describe el error de forma comprensible.
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