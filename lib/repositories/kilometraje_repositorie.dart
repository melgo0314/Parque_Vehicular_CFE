import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/kilometraje_model.dart';

class KilometrajeRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Registra el recorrido y actualiza el kilometraje actual del vehículo.
  Future<void> registrarKilometraje(KilometrajeModel registro) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para registrar el kilometraje.');
    }

    if (registro.vehiculoUid.trim().isEmpty) {
      throw ArgumentError('Selecciona un vehículo.');
    }

    if (registro.kilometrajeFinal <= registro.kilometrajeIni) {
      throw ArgumentError(
        'El kilometraje final debe ser mayor que el inicial.',
      );
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    final datosUsuario = documentoUsuario.data();
    final rpe = datosUsuario?['rpe']?.toString().trim() ?? '';

    if (!documentoUsuario.exists || rpe.isEmpty) {
      throw StateError('No se encontró el RPE de tu usuario.');
    }

    final referenciaVehiculo =
        _db.collection('vehiculo').doc(registro.vehiculoUid.trim());
    final documentoVehiculo = await referenciaVehiculo.get();

    if (!documentoVehiculo.exists) {
      throw StateError('No se encontró el vehículo seleccionado.');
    }

    final datosVehiculo = documentoVehiculo.data() ?? {};
    final kilometrajeActual = _convertirNumero(
      datosVehiculo['kilometrajeActual'] ?? datosVehiculo['kilometraje'],
    );

    if (registro.kilometrajeFinal <= kilometrajeActual) {
      throw ArgumentError(
        'El kilometraje debe ser mayor al último registrado '
        '(${kilometrajeActual.toInt()} km).',
      );
    }

    final registroConRpe = KilometrajeModel(
      uid: '',
      vehiculoUid: registro.vehiculoUid.trim(),
      rpeUsuario: rpe,
      fecha: registro.fecha,
      kilometrajeIni: registro.kilometrajeIni,
      kilometrajeFinal: registro.kilometrajeFinal,
      observaciones: registro.observaciones,
    );

    final referenciaRegistro = _db.collection('kilometraje').doc();
    final lote = _db.batch();

    lote.set(referenciaRegistro, registroConRpe.toMap());

    lote.update(referenciaVehiculo, {
      'kilometrajeActual': registro.kilometrajeFinal.toInt(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await lote.commit();
  }

  // Obtiene todos los registros o filtra los de un vehículo.
  Stream<List<KilometrajeModel>> obtenerRegistros({
    String? vehiculoUid,
  }) {
    Query<Map<String, dynamic>> consulta = _db.collection('kilometraje');

    if (vehiculoUid != null && vehiculoUid.trim().isNotEmpty) {
      consulta = consulta.where(
        'vehiculoUid',
        isEqualTo: vehiculoUid.trim(),
      );
    }

    return consulta.snapshots().map((resultado) {
      final registros = resultado.docs.map((documento) {
        return KilometrajeModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();

      registros.sort((a, b) => b.fecha.compareTo(a.fecha));
      return registros;
    });
  }

  // Actualiza un registro y vuelve a calcular el kilometraje del vehículo.
  Future<void> actualizarKilometraje(KilometrajeModel registro) async {
    if (registro.uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
    }

    if (registro.vehiculoUid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un vehículo seleccionado.');
    }

    if (registro.kilometrajeFinal <= registro.kilometrajeIni) {
      throw ArgumentError(
        'El kilometraje final debe ser mayor que el inicial.',
      );
    }

    await _db
        .collection('kilometraje')
        .doc(registro.uid)
        .update(registro.toMap());

    await _actualizarKilometrajeDelVehiculo(registro.vehiculoUid);
  }

  // Elimina un registro y recalcula el kilometraje actual del vehículo.
  Future<void> eliminarKilometraje(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
    }

    final referenciaRegistro = _db.collection('kilometraje').doc(uid);
    final documento = await referenciaRegistro.get();

    if (!documento.exists) {
      throw StateError('El registro de kilometraje ya no existe.');
    }

    final vehiculoUid =
        documento.data()?['vehiculoUid']?.toString().trim() ?? '';

    await referenciaRegistro.delete();

    if (vehiculoUid.isNotEmpty) {
      await _actualizarKilometrajeDelVehiculo(vehiculoUid);
    }
  }

  // Toma la lectura del registro más reciente y la guarda en Vehiculo.
  Future<void> _actualizarKilometrajeDelVehiculo(String vehiculoUid) async {
    final consulta = await _db
        .collection('kilometraje')
        .where('vehiculoUid', isEqualTo: vehiculoUid)
        .get();

    final registros = consulta.docs.map((documento) {
      return KilometrajeModel.fromMap(
        documento.data(),
        documento.id,
      );
    }).toList();

    registros.sort((a, b) => b.fecha.compareTo(a.fecha));

    final kilometrajeActual =
        registros.isEmpty ? 0 : registros.first.kilometrajeFinal.toInt();

    await _db.collection('vehiculo').doc(vehiculoUid).update({
      'kilometrajeActual': kilometrajeActual,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  double _convertirNumero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }
}