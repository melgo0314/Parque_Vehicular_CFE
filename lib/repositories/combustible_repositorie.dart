import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:p_vehicular/models/combustible_model.dart';

// Se comunica con Firebase para administrar las cargas de combustible.
class CombustibleRepositorie {
  // Conexión a Cloud Firestore.
  final FirebaseFirestore _db;

  // Servicio de Firebase Authentication.
  final FirebaseAuth _auth;

  // Crea el repositorio con las conexiones proporcionadas o las predeterminadas.
  // Entradas: db y auth son dependencias opcionales de Firebase.
  // Salida: una instancia de CombustibleRepositorie configurada.
  CombustibleRepositorie({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Referencia a la colección de cargas de combustible.
  CollectionReference<Map<String, dynamic>> get _cargas =>
      _db.collection('combustible');

  // Registra una carga y agrega el RPE del usuario autenticado.
  // Entrada: carga con los datos que se desean guardar.
  // Salida: identificador del documento creado en Firestore.
  // Lanza StateError si no hay una sesión activa o no se encuentra el RPE.
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

  // Escucha todas las cargas o filtra el historial por vehículo.
  // Entrada: vehiculoUid opcional para limitar la consulta a un vehículo.
  // Salida: un flujo de cargas ordenado desde la fecha más reciente.
  Stream<List<CombustibleModel>> obtenerCargas({
    String? vehiculoUid,
  }) {
    Query<Map<String, dynamic>> consulta = _cargas;

    if (vehiculoUid != null && vehiculoUid.trim().isNotEmpty) {
      consulta = consulta.where(
        'vehiculoUid',
        isEqualTo: vehiculoUid.trim(),
      );
    }

    return consulta.snapshots().map((resultado) {
      final cargas = resultado.docs
          .map(
            (documento) => CombustibleModel.fromMap(
              documento.data(),
              documento.id,
            ),
          )
          .toList();

      cargas.sort((a, b) => b.fechaCarga.compareTo(a.fechaCarga));
      return cargas;
    });
  }

  // Actualiza una carga de combustible existente.
  // Entrada: carga con el identificador y los datos actualizados.
  // Salida: un Future que termina cuando Firestore confirma la actualización.
  // Lanza ArgumentError si la carga no tiene un identificador válido.
  Future<void> actualizarCarga(CombustibleModel carga) async {
    if (carga.uid.trim().isEmpty) {
      throw ArgumentError('La carga no tiene un identificador válido.');
    }

    await _cargas.doc(carga.uid).update(carga.toMap());
  }

  // Elimina una carga de combustible.
  // Entrada: uid, identificador del documento que se eliminará.
  // Salida: un Future que termina cuando Firestore confirma la eliminación.
  // La pantalla debe pedir confirmación antes de llamar a este método.
  // Lanza ArgumentError si el identificador está vacío.
  Future<void> eliminarCarga(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('La carga no tiene un identificador válido.');
    }

    await _cargas.doc(uid).delete();
  }
}