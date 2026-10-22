import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:p_vehicular/models/combustible_model.dart';

class CombustibleRepositorie {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CombustibleRepositorie({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _cargas =>
      _db.collection('combustible');

  // Registra la carga y obtiene el RPE del usuario autenticado
  Future<String> registrarCarga(CombustibleModel carga) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para registrar una carga.');
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();
    final datosUsuario = documentoUsuario.data();
    final rpe = datosUsuario?['rpe']?.toString().trim() ?? '';

    if (!documentoUsuario.exists || rpe.isEmpty) {
      throw StateError('No se encontró el RPE del usuario que inició sesión.');
    }

    final cargaConRpe = carga.copyWith(rpeUsuario: rpe);
    final documentoCreado = await _cargas.add(cargaConRpe.toMap());

    return documentoCreado.id;
  }

  // Escucha el historial completo o el de un vehículo específico.
  Stream<List<CombustibleModel>> obtenerCargas({String? vehiculoUid}) {
    Query<Map<String, dynamic>> consulta = _cargas;

    if (vehiculoUid != null && vehiculoUid.trim().isNotEmpty) {
      consulta = consulta.where(
        'vehiculoUid',
        isEqualTo: vehiculoUid.trim(),
      );
    }

    return consulta.snapshots().map((resultado) {
      final cargas = resultado.docs
          .map((documento) => CombustibleModel.fromMap(
                documento.data(),
                documento.id,
              ))
          .toList();

      cargas.sort((a, b) => b.fechaCarga.compareTo(a.fechaCarga));
      return cargas;
    });
  }

  // Actualiza una carga existente
  Future<void> actualizarCarga(CombustibleModel carga) async {
    if (carga.uid.trim().isEmpty) {
      throw ArgumentError('La carga no tiene un identificador válido.');
    }

    await _cargas.doc(carga.uid).update(carga.toMap());
  }

  // Elimina una carga. La pantalla debe pedir confirmación antes de llamar a este método.
  Future<void> eliminarCarga(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('La carga no tiene un identificador válido.');
    }

    await _cargas.doc(uid).delete();
  }
}