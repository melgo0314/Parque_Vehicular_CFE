import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/kilometraje_model.dart';

class KilometrajeRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Registra un recorrido y obtiene el RPE de la sesión activa.
  Future<void> registrarKilometraje(KilometrajeModel registro) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para registrar el kilometraje.');
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

    final registroConRpe = KilometrajeModel(
      uid: '',
      vehiculoUid: registro.vehiculoUid,
      rpeUsuario: rpe,
      fecha: registro.fecha,
      kilometrajeIni: registro.kilometrajeIni,
      kilometrajeFinal: registro.kilometrajeFinal,
      observaciones: registro.observaciones,
    );

    await _db
        .collection('kilometraje')
        .add(registroConRpe.toMap());
  }

  // Obtiene todos los registros o filtra los de un vehículo.
  Stream<List<KilometrajeModel>> obtenerRegistros({
    String? vehiculoUid,
  }) {
    Query<Map<String, dynamic>> consulta =
        _db.collection('kilometraje');

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

  // Actualiza un registro existente.
  Future<void> actualizarKilometraje(KilometrajeModel registro) async {
    if (registro.uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
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
  }

  // Elimina un registro existente.
  Future<void> eliminarKilometraje(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
    }

    await _db.collection('kilometraje').doc(uid).delete();
  }
}