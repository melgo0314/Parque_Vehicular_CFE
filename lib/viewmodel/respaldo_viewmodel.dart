
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/respaldo_model.dart';
import '../repositories/respaldo_repositorie.dart';

class RespaldoViewmodel extends ChangeNotifier {
  final RespaldoRepositorie _repositorio =
      RespaldoRepositorie();

  // Lista de respaldos registrados.
  List<RespaldoModel> _respaldos = [];

  List<RespaldoModel> get respaldos => _respaldos;

  // Estados de carga.
  bool _cargando = false;
  bool get cargando => _cargando;

  bool _generandoRespaldo = false;
  bool get generandoRespaldo => _generandoRespaldo;

  String? _error;
  String? get error => _error;

  String? _mensaje;
  String? get mensaje => _mensaje;

  // Consulta el historial de respaldos.
  Future<void> obtenerRespaldos() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _respaldos = await _repositorio.obtenerRespaldos();

      // Ordena los respaldos del más reciente al más antiguo.
      _respaldos.sort((a, b) {
        final fechaA = a.fechaInicio;
        final fechaB = b.fechaInicio;

        if (fechaA == null && fechaB == null) return 0;
        if (fechaA == null) return 1;
        if (fechaB == null) return -1;

        return fechaB.compareTo(fechaA);
      });
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'No fue posible consultar los respaldos.';
    } catch (e) {
      _error = 'Error al consultar los respaldos: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Solicita generar un nuevo respaldo.
  Future<bool> generarRespaldo() async {
    if (_generandoRespaldo) return false;

    _generandoRespaldo = true;
    _mensaje = null;
    _error = null;
    notifyListeners();

    try {
      await _repositorio.generarRespaldo();

      _mensaje =
          'La solicitud de respaldo se inició correctamente.';

      return true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'No fue posible generar el respaldo.';
      return false;
    } catch (e) {
      _error = 'Error al generar el respaldo: $e';
      return false;
    } finally {
      _generandoRespaldo = false;
      notifyListeners();
    }
  }

  // Solicita restaurar un respaldo específico.
  Future<bool> restaurarRespaldo(String identificador) async {
    if (identificador.trim().isEmpty) {
      _error = 'El identificador del respaldo no es válido.';
      notifyListeners();
      return false;
    }

    _error = null;
    _mensaje = null;
    notifyListeners();

    try {
      await _repositorio.restaurarRespaldo(identificador);

      _mensaje =
          'La solicitud de restauración se inició correctamente.';

      return true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'No fue posible restaurar el respaldo.';
      return false;
    } catch (e) {
      _error = 'Error al restaurar el respaldo: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }

  // Limpia los mensajes mostrados en pantalla.
  void limpiarMensajes() {
    _mensaje = null;
    _error = null;
    notifyListeners();
  }
}
