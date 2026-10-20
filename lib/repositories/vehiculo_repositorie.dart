import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vehiculos_model.dart';

class VehiculoRepositorie {
  VehiculoRepositorie({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _vehiculos => _db.collection('vehiculo');

  Stream<List<VehiculoModel>> obtenerVehiculos({
    String busqueda = '',
    bool incluirBaja = false,
  }) {
    return _vehiculos.snapshots().map((consulta) {
      final texto = busqueda.trim().toLowerCase();

      final vehiculos = consulta.docs
          .map((documento) =>
              VehiculoModel.fromMap(documento.data(), documento.id))
          .where((vehiculo) {
            final estaDeBaja = vehiculo.estado.toLowerCase() == 'baja';
            if (!incluirBaja && estaDeBaja) return false;

            if (texto.isEmpty) return true;

            final datos = [
              vehiculo.placas,
              vehiculo.numeroEconomico,
              vehiculo.marca,
              vehiculo.modelo,
              vehiculo.anio.toString(),
            ].join(' ').toLowerCase();

            return datos.contains(texto);
          })
          .toList();

      vehiculos.sort(
        (a, b) => a.placas.toLowerCase().compareTo(b.placas.toLowerCase()),
      );

      return vehiculos;
    });
  }

  /// Registra un vehículo con estado activo.
  Future<void> registrarVehiculo(VehiculoModel vehiculo) async {
    _validarDatos(vehiculo);

    final placasNormalizadas = _normalizar(vehiculo.placas);
    final numeroNormalizado = _normalizar(vehiculo.numeroEconomico);

    await _validarUnicidad(
      placas: placasNormalizadas,
      numeroEconomico: numeroNormalizado,
    );

    final referencia = _vehiculos.doc();

    await referencia.set({
      ...vehiculo.toMap(),
      'estado': 'activo',
      'placasNormalizadas': placasNormalizadas,
      'numeroEconomicoNormalizado': numeroNormalizado,
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza los datos generales del vehículo.
  Future<void> actualizarVehiculo(VehiculoModel vehiculo) async {
    if (vehiculo.uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    _validarDatos(vehiculo);

    final referencia = _vehiculos.doc(vehiculo.uid);
    final existente = await referencia.get();

    if (!existente.exists) {
      throw StateError('No se encontró el vehículo que deseas actualizar.');
    }

    final placasNormalizadas = _normalizar(vehiculo.placas);
    final numeroNormalizado = _normalizar(vehiculo.numeroEconomico);

    await _validarUnicidad(
      placas: placasNormalizadas,
      numeroEconomico: numeroNormalizado,
      uidExcluir: vehiculo.uid,
    );

    await referencia.update({
      ...vehiculo.toMap(),
      'placasNormalizadas': placasNormalizadas,
      'numeroEconomicoNormalizado': numeroNormalizado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Da de baja el vehículo sin borrar el documento ni su historial.
  Future<void> darDeBaja(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    final referencia = _vehiculos.doc(uid);
    final documento = await referencia.get();

    if (!documento.exists) {
      throw StateError('No se encontró el vehículo que deseas dar de baja.');
    }

    await referencia.update({
      'estado': 'baja',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Permite reactivar un vehículo que estaba dado de baja.
  Future<void> reactivarVehiculo(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    final referencia = _vehiculos.doc(uid);
    final documento = await referencia.get();

    if (!documento.exists) {
      throw StateError('No se encontró el vehículo que deseas reactivar.');
    }

    await referencia.update({
      'estado': 'activo',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  void _validarDatos(VehiculoModel vehiculo) {
    if (vehiculo.placas.trim().isEmpty) {
      throw ArgumentError('Escribe las placas del vehículo.');
    }
    if (vehiculo.numeroEconomico.trim().isEmpty) {
      throw ArgumentError('Escribe el número económico.');
    }
    if (vehiculo.marca.trim().isEmpty) {
      throw ArgumentError('Escribe la marca del vehículo.');
    }
    if (vehiculo.modelo.trim().isEmpty) {
      throw ArgumentError('Escribe el modelo del vehículo.');
    }

    final anioActual = DateTime.now().year;
    if (vehiculo.anio < 1950 || vehiculo.anio > anioActual + 1) {
      throw ArgumentError('Escribe un año válido.');
    }
  }

  Future<void> _validarUnicidad({
    required String placas,
    required String numeroEconomico,
    String? uidExcluir,
  }) async {
   
    final consulta = await _vehiculos.get();

    for (final documento in consulta.docs) {
      if (documento.id == uidExcluir) continue;

      final datos = documento.data();
      final placasExistentes = _normalizar(
        (datos['placasNormalizadas'] ?? datos['placas'] ?? '').toString(),
      );
      final numeroExistente = _normalizar(
        (datos['numeroEconomicoNormalizado'] ??
                datos['numeroEconomico'] ??
                datos['numeco'] ??
                '')
            .toString(),
      );

      if (placasExistentes == placas) {
        throw ArgumentError('Ya existe un vehículo registrado con esas placas.');
      }

      if (numeroExistente == numeroEconomico) {
        throw ArgumentError(
          'Ya existe un vehículo con ese número económico.',
        );
      }
    }
  }

  String _normalizar(String valor) {
    return valor.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }
}