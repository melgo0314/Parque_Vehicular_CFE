import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mantenimiento_model.dart';

class MantenimientoRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Comprueba que haya una sesión de administrador y obtiene su RPE.
  Future<String> _obtenerRpeAdministrador() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para continuar.');
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    if (!documentoUsuario.exists) {
      throw StateError('No se encontró el perfil del usuario.');
    }

    final datosUsuario = documentoUsuario.data();
    final rol = datosUsuario?['rol']?.toString().trim().toLowerCase() ?? '';

    if (rol != 'administrador' && rol != 'superusuario') {
      throw StateError(
        'Solo un administrador puede gestionar mantenimientos.',
      );
    }

    final rpe = datosUsuario?['rpe']?.toString().trim() ?? '';

    if (rpe.isEmpty) {
      throw StateError('No se encontró el RPE del administrador.');
    }

    return rpe;
  }

  // Registra un mantenimiento y guarda el RPE del administrador.
  Future<void> registrarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    final rpeAdministrador = await _obtenerRpeAdministrador();

    final datos = mantenimiento.toMap();
    datos['rpeUsuario'] = rpeAdministrador;

    await _db.collection('mantenimiento').add(datos);
  }

  // Consulta mantenimientos. Puede filtrar por vehículo y módulo.
  Stream<List<MantenimientoModel>> obtenerMantenimientos({
    String? vehiculoUid,
    String? modulo,
  }) {
    Query<Map<String, dynamic>> consulta =
        _db.collection('mantenimiento');

    if (vehiculoUid != null && vehiculoUid.trim().isNotEmpty) {
      consulta = consulta.where(
        'vehiculoUid',
        isEqualTo: vehiculoUid.trim(),
      );
    }

    if (modulo != null && modulo.trim().isNotEmpty) {
      consulta = consulta.where(
        'modulo',
        isEqualTo: modulo.trim(),
      );
    }

    return consulta.snapshots().map((resultado) {
      final mantenimientos = resultado.docs.map((documento) {
        return MantenimientoModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();

      mantenimientos.sort(
        (a, b) => b.fechaRealizado.compareTo(a.fechaRealizado),
      );

      return mantenimientos;
    });
  }

  // Actualiza un mantenimiento existente.
  Future<void> actualizarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    await _obtenerRpeAdministrador();

    if (mantenimiento.uid.trim().isEmpty) {
      throw ArgumentError(
        'El mantenimiento no tiene un identificador válido.',
      );
    }

    final datos = mantenimiento.toMap();

    // Se conserva quién creó originalmente el registro.
    datos['rpeUsuario'] = mantenimiento.rpeUsuario;

    await _db
        .collection('mantenimiento')
        .doc(mantenimiento.uid)
        .update(datos);
  }

  // Elimina un mantenimiento existente.
  Future<void> eliminarMantenimiento(String uid) async {
    await _obtenerRpeAdministrador();

    if (uid.trim().isEmpty) {
      throw ArgumentError(
        'El mantenimiento no tiene un identificador válido.',
      );
    }

    await _db.collection('mantenimiento').doc(uid).delete();
  }
}