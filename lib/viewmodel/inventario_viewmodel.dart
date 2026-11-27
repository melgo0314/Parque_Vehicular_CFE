import 'package:flutter/material.dart';

import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/inventario_repositorie.dart';

class InventarioViewModel extends ChangeNotifier {
  final InventarioRepositorie _repositorio = InventarioRepositorie();

  bool _cargando = false;
  String? _mensajeError;
  String? _mensajeExito;

  bool get cargando => _cargando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  // Consultar el rol del usuario que inició sesión.
  Future<String> obtenerRolUsuarioActual() {
    return _repositorio.obtenerRolUsuarioActual();
  }

  // Consultar solamente los vehículos permitidos para el usuario.
  Stream<List<VehiculoModel>> obtenerVehiculosPermitidos() {
    return _repositorio.obtenerVehiculosPermitidos();
  }

  // Consultar el catálogo de artículos activos.
  Stream<List<ArticuloModel>> obtenerArticulos() {
    return _repositorio.obtenerArticulos();
  }

  Stream<List<ArticuloModel>> obtenerTodosArticulos() {
    return _repositorio.obtenerTodosArticulos();
  }

  // Consultar el checklist de un vehículo.
  Stream<List<InventarioModel>> obtenerInventarioVehiculo(
    String vehiculoUid,
  ) {
    return _repositorio.obtenerInventarioVehiculo(vehiculoUid);
  }

  // Agregar un artículo al catálogo.
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

  // Actualizar un artículo del catálogo.
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

  // Guardar o actualizar un artículo en el checklist.
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

  // Retirar un artículo del checklist.
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