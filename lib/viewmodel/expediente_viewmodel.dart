import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/documento_model.dart';
import '../models/expediente_model.dart';
import '../repositories/expediente_repositorie.dart';

// Coordina las operaciones entre la interfaz y el repositorio de expedientes.
class ExpedienteViewModel extends ChangeNotifier {
  // Crea el ViewModel con el repositorio proporcionado o uno predeterminado.
  ExpedienteViewModel({ExpedienteRepositorie? repositorio})
    : _repositorio = repositorio ?? ExpedienteRepositorie();

  // Repositorio encargado de comunicarse con Firebase.
  final ExpedienteRepositorie _repositorio;

  // Indica si hay una operación en curso.
  bool _cargando = false;

  // Guarda el mensaje de error actual.
  String? _mensajeError;

  // Guarda el mensaje de éxito actual.
  String? _mensajeExito;

  // Devuelve el estado de carga.
  bool get cargando => _cargando;

  // Devuelve el mensaje de error.
  String? get mensajeError => _mensajeError;

  // Devuelve el mensaje de éxito.
  String? get mensajeExito => _mensajeExito;

  // Inicializa el catálogo de documentos.
  Future<bool> inicializarCatalogo() async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.inicializarCatalogo();
      _mensajeExito = 'El catálogo de documentos está disponible.';
      return true;
    } on FirebaseException catch (error) {
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      debugPrint('Error al inicializar catálogo: $error');
      _mensajeError = 'No se pudo inicializar el catálogo de documentos.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  // Obtiene los tipos de documentos disponibles.
  Stream<List<DocumentoModel>> obtenerDocumentos() {
    return _repositorio.obtenerDocumentos();
  }

  // Obtiene los expedientes registrados para un vehículo.
  Stream<List<ExpedienteModel>> obtenerExpedientes(String vehiculoUid) {
    return _repositorio.obtenerExpedientes(vehiculoUid);
  }

  // Obtiene los bytes de un documento para previsualizarlo en la aplicación.
  Future<Uint8List> descargarArchivo(ExpedienteModel expediente) async {
    try {
      return await _repositorio.descargarArchivo(expediente);
    } on FirebaseException catch (error) {
      throw StateError(_mensajeFirebase(error));
    }
  }

  // Recupera una URL vigente para previsualizar en Flutter Web.
  Future<String> obtenerUrlVisualizacion(ExpedienteModel expediente) async {
    try {
      return await _repositorio.obtenerUrlArchivo(expediente);
    } on FirebaseException catch (error) {
      throw StateError(_mensajeFirebase(error));
    }
  }

  // Registra un expediente y su archivo.
  Future<bool> registrarExpediente({
    required ExpedienteModel expediente,
    required Uint8List archivoBytes,
  }) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.registrarExpediente(
        expediente: expediente,
        archivoBytes: archivoBytes,
      );

      _mensajeExito = 'El documento se registró correctamente.';
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
      debugPrint('Error al registrar expediente: $error');
      _mensajeError = 'No se pudo registrar el documento.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  // Actualiza la información de un expediente.
  Future<bool> actualizarExpediente({
    required ExpedienteModel expediente,
    Uint8List? archivoBytes,
  }) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.actualizarExpediente(
        expediente: expediente,
        archivoBytes: archivoBytes,
      );

      _mensajeExito = 'El documento se actualizó correctamente.';
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
      debugPrint('Error al actualizar expediente: $error');
      _mensajeError = 'No se pudo actualizar el documento.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  // Elimina un expediente y su archivo.
  Future<bool> eliminarExpediente(String uid) async {
    if (_cargando) return false;

    _iniciarOperacion();

    try {
      await _repositorio.eliminarExpediente(uid);
      _mensajeExito = 'El documento se eliminó correctamente.';
      return true;
    } on ArgumentError catch (error) {
      _mensajeError =
          error.message?.toString() ?? 'No se recibió el expediente.';
      return false;
    } on StateError catch (error) {
      _mensajeError = error.message;
      return false;
    } on FirebaseException catch (error) {
      _mensajeError = _mensajeFirebase(error);
      return false;
    } catch (error) {
      debugPrint('Error al eliminar expediente: $error');
      _mensajeError = 'No se pudo eliminar el documento.';
      return false;
    } finally {
      _finalizarOperacion();
    }
  }

  // Limpia los mensajes actuales.
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Inicia una operación y limpia los mensajes anteriores.
  void _iniciarOperacion() {
    _cargando = true;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  // Finaliza una operación.
  void _finalizarOperacion() {
    _cargando = false;
    notifyListeners();
  }

  // Convierte errores de Firebase en mensajes comprensibles.
  String _mensajeFirebase(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
        return 'Firebase no está disponible. Revisa tu conexión.';
      case 'object-not-found':
        return 'No se encontró el archivo solicitado.';
      case 'unauthorized':
      case 'permission-denied':
        return 'Firebase Storage no permite leer este archivo. Revisa las reglas '
            'de acceso del bucket.';
      case 'canceled':
        return 'La descarga del documento se canceló.';
      default:
        debugPrint('Error Firebase ${error.code}: ${error.message}');
        return 'Firebase Storage (${error.code}): '
            '${error.message ?? 'sin detalle adicional'}';
    }
  }
}
