import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../repositories/mantenimiento_repositorie.dart';
import '../repositories/vehiculo_repositorie.dart';

class MantenimientoViewModel extends ChangeNotifier {
  final MantenimientoRepositorie _repositorio =
      MantenimientoRepositorie();
  final VehiculoRepositorie _vehiculoRepositorio =
      VehiculoRepositorie();

  bool _cargando = false;
  String? _mensajeError;
  String? _mensajeExito;

  bool get cargando => _cargando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _vehiculoRepositorio.obtenerVehiculos();
  }

  Stream<List<MantenimientoModel>> obtenerMantenimientos({
    String? vehiculoUid,
    String? modulo,
  }) {
    return _repositorio.obtenerMantenimientos(
      vehiculoUid: vehiculoUid,
      modulo: modulo,
    );
  }

  Future<bool> registrarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    final error = _validar(mantenimiento);

    if (error != null) {
      _mensajeError = error;
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.registrarMantenimiento(mantenimiento);
      _mensajeExito = 'El mantenimiento se registró correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  Future<bool> actualizarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    final error = _validar(mantenimiento);

    if (error != null) {
      _mensajeError = error;
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    if (mantenimiento.uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador del mantenimiento.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.actualizarMantenimiento(mantenimiento);
      _mensajeExito = 'El mantenimiento se actualizó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  Future<bool> eliminarMantenimiento(String uid) async {
    if (uid.trim().isEmpty) {
      _mensajeError = 'No se encontró el identificador del mantenimiento.';
      _mensajeExito = null;
      notifyListeners();
      return false;
    }

    _iniciarCarga();

    try {
      await _repositorio.eliminarMantenimiento(uid);
      _mensajeExito = 'El mantenimiento se eliminó correctamente.';
      return true;
    } catch (error) {
      _mensajeError = _mensajeAmigable(error);
      return false;
    } finally {
      _terminarCarga();
    }
  }

  String? _validar(MantenimientoModel mantenimiento) {
    if (mantenimiento.vehiculoUid.trim().isEmpty) {
      return 'Selecciona un vehículo.';
    }

    if (mantenimiento.modulo.trim().isEmpty) {
      return 'Selecciona el módulo del mantenimiento.';
    }

    if (mantenimiento.tipoMantenimiento.trim().isEmpty) {
      return 'Selecciona el tipo de mantenimiento.';
    }

    if (mantenimiento.trabajoRealizado.trim().isEmpty) {
      return 'Describe el trabajo realizado.';
    }

    if (mantenimiento.costo < 0) {
      return 'El costo no puede ser negativo.';
    }

    if (mantenimiento.kilometraje != null &&
        mantenimiento.kilometraje! < 0) {
      return 'El kilometraje no puede ser negativo.';
    }

    if (mantenimiento.horometroHoras != null &&
        mantenimiento.horometroHoras! < 0) {
      return 'Las horas del horómetro no pueden ser negativas.';
    }

    if (mantenimiento.fechaRealizado.isAfter(DateTime.now())) {
      return 'La fecha realizada no puede ser posterior a hoy.';
    }

    // Los mantenimientos preventivos mecánicos requieren kilometraje.
    if (mantenimiento.modulo == 'mecanico' &&
        mantenimiento.tipoMantenimiento == 'preventivo' &&
        mantenimiento.kilometraje == null) {
      return 'Ingresa el kilometraje del mantenimiento preventivo.';
    }

    // Los preventivos hidráulicos requieren kilometraje y horómetro.
    if (mantenimiento.modulo == 'hidraulico' &&
        mantenimiento.tipoMantenimiento == 'preventivo') {
      if (mantenimiento.kilometraje == null) {
        return 'Ingresa el kilometraje del mantenimiento hidráulico.';
      }

      if (mantenimiento.horometroHoras == null) {
        return 'Ingresa las horas del horómetro.';
      }
    }

    // Las pruebas PEMP requieren una categoría asignada.
    if (mantenimiento.modulo == 'laboratorio_pemp' &&
        mantenimiento.categoriaPemp.trim().isEmpty) {
      return 'Selecciona la categoría de la prueba PEMP.';
    }

    // Si se capturan datos de llantas, deben estar completos.
    final tieneDatosDeLlanta =
        mantenimiento.fechaCaducidadLlanta != null ||
        mantenimiento.vidaUtilLlantaKm != null ||
        mantenimiento.desgasteLlantaPorcentaje != null;

    if (tieneDatosDeLlanta) {
      if (mantenimiento.modulo != 'mecanico') {
        return 'El control de llantas corresponde al módulo mecánico.';
      }

      if (mantenimiento.fechaCaducidadLlanta == null) {
        return 'Ingresa la fecha de caducidad de la llanta.';
      }

      if (mantenimiento.vidaUtilLlantaKm == null ||
          mantenimiento.vidaUtilLlantaKm! <= 0) {
        return 'La vida útil de la llanta debe ser mayor que cero.';
      }

      final desgaste = mantenimiento.desgasteLlantaPorcentaje;
      if (desgaste == null || desgaste < 0 || desgaste > 100) {
        return 'El desgaste debe estar entre 0 y 100%.';
      }
    }

    return null;
  }

  String _mensajeAmigable(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Revisa los datos ingresados.';
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