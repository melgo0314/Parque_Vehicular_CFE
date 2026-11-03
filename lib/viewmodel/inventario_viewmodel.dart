import 'package:flutter/material.dart';
import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/inventario_repositorie.dart';

// ViewModel que conecta la interfaz con el repositorio de inventario
class InventarioViewModel extends ChangeNotifier {
  // Repositorio que consulta y modifica los datos en la fuente de datos.
  final InventarioRepositorie _repositorio = InventarioRepositorie();

  // Indica si hay una operación de escritura en curso.
  bool _cargando = false;

  // Mensaje que informa de un error ocurrido en una operación.
  String? _mensajeError;

  // Mensaje que confirma que una operación terminó correctamente.
  String? _mensajeExito;

  // Indica si el ViewModel está realizando una operación.
  bool get cargando => _cargando;

  // Devuelve el mensaje de error actual, si existe.
  String? get mensajeError => _mensajeError;

  // Devuelve el mensaje de éxito actual, si existe.
  String? get mensajeExito => _mensajeExito;

  // Consulta los vehículos registrados.
  // Entrada: ninguna.
  // Salida: flujo con la lista actualizada de vehículos.
  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _repositorio.obtenerVehiculos();
  }

  // Consulta el catálogo de artículos.
  // Entrada: ninguna.
  // Salida: flujo con la lista actualizada de artículos.
  Stream<List<ArticuloModel>> obtenerArticulos() {
    return _repositorio.obtenerArticulos();
  }

  // Consulta los registros del checklist de un vehículo.
  // Entrada: UID del vehículo cuyo inventario se desea consultar.
  // Salida: flujo con los registros de inventario del vehículo.
  Stream<List<InventarioModel>> obtenerInventarioVehiculo(
    String vehiculoUid,
  ) {
    return _repositorio.obtenerInventarioVehiculo(vehiculoUid);
  }

  // Agrega un artículo al catálogo.
  // Entrada: objeto ArticuloModel con los datos del artículo.
  // Salida: true si se agregó correctamente; false si ocurrió un error.
  Future<bool> registrarArticulo(ArticuloModel articulo) async {
    _iniciarCarga();

    try {
      await _repositorio.registrarArticulo(articulo);
      _mensajeExito = 'Artículo agregado correctamente.';
      return true;
    } catch (error) {
      _mensajeError = 'No se pudo agregar el artículo. Inténtalo de nuevo.';
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Actualiza los datos de un artículo del catálogo.
  // Entrada: objeto ArticuloModel con el artículo y sus datos actualizados.
  // Salida: true si se actualizó correctamente; false si ocurrió un error.
  Future<bool> actualizarArticulo(ArticuloModel articulo) async {
    _iniciarCarga();

    try {
      await _repositorio.actualizarArticulo(articulo);
      _mensajeExito = 'Artículo actualizado correctamente.';
      return true;
    } catch (error) {
      _mensajeError =
          'No se pudo actualizar el artículo. Inténtalo de nuevo.';
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Guarda o actualiza un artículo en el checklist del vehículo.
  // Entrada: objeto InventarioModel con los datos del registro.
  // Salida: true si se guardó correctamente; false si ocurrió un error.
  Future<bool> guardarRegistro(InventarioModel registro) async {
    _iniciarCarga();

    try {
      await _repositorio.guardarRegistro(registro);
      _mensajeExito = 'El inventario del vehículo se guardó correctamente.';
      return true;
    } catch (error) {
      _mensajeError =
          'No se pudo guardar el inventario. Revisa los datos e inténtalo otra vez.';
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Retira un artículo del checklist de un vehículo.
  // Entrada: UID del vehículo y UID del artículo que se retirará.
  // Salida: true si se retiró correctamente; false si ocurrió un error.
  Future<bool> eliminarRegistro({
    required String vehiculoUid,
    required String articuloUid,
  }) async {
    _iniciarCarga();

    try {
      await _repositorio.eliminarRegistro(
        vehiculoUid: vehiculoUid,
        articuloUid: articuloUid,
      );
      _mensajeExito = 'El artículo se retiró del inventario.';
      return true;
    } catch (error) {
      _mensajeError =
          'No se pudo retirar el artículo. Inténtalo de nuevo.';
      return false;
    } finally {
      _terminarCarga();
    }
  }

  // Borra los mensajes actuales y notifica el cambio a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Activa el estado de carga, limpia mensajes anteriores y notifica el cambio.
  // Entrada: ninguna.
  // Salida: ninguna.
  void _iniciarCarga() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Desactiva el estado de carga y notifica el cambio a la interfaz.
  // Entrada: ninguna.
  // Salida: ninguna.
  void _terminarCarga() {
    _cargando = false;
    notifyListeners();
  }
}