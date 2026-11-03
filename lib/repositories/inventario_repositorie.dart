import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';

// Repositorio que conecta el módulo de inventario con Firebase.
class InventarioRepositorie {
  // Conexión a Cloud Firestore.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Servicio de Firebase Authentication.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lee en tiempo real los vehículos registrados.
  // Entrada: ninguna.
  // Salida: un flujo con la lista de vehículos.
  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _db.collection('vehiculo').snapshots().map((resultado) {
      return resultado.docs.map((documento) {
        return VehiculoModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();
    });
  }

  // Lee en tiempo real el catálogo de artículos activos.
  // Entrada: ninguna.
  // Salida: un flujo con la lista de artículos activos.
  Stream<List<ArticuloModel>> obtenerArticulos() {
    return _db
        .collection('articulo')
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((resultado) {
      return resultado.docs.map((documento) {
        return ArticuloModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();
    });
  }

  // Consulta en tiempo real el checklist de inventario de un vehículo.
  // Entrada: vehiculoUid, identificador del vehículo que se consultará.
  // Salida: un flujo con los registros de inventario asociados al vehículo.
  Stream<List<InventarioModel>> obtenerInventarioVehiculo(
    String vehiculoUid,
  ) {
    return _db
        .collection('inventario')
        .where('vehiculoUid', isEqualTo: vehiculoUid)
        .snapshots()
        .map((resultado) {
      return resultado.docs.map((documento) {
        return InventarioModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();
    });
  }

  // Crea un artículo en el catálogo.
  // Entrada: articulo con los datos que se guardarán.
  // Salida: un Future que termina cuando Firestore confirma el registro.
  Future<void> registrarArticulo(ArticuloModel articulo) async {
    await _db.collection('articulo').add(articulo.toMap());
  }

  // Actualiza los datos de un artículo del catálogo.
  // Entrada: articulo con identificador y datos actualizados.
  // Salida: un Future que termina cuando Firestore confirma la actualización.
  // Lanza ArgumentError si el artículo no tiene un identificador válido.
  Future<void> actualizarArticulo(ArticuloModel articulo) async {
    if (articulo.uid.trim().isEmpty) {
      throw ArgumentError('El artículo no tiene un identificador válido.');
    }

    await _db
        .collection('articulo')
        .doc(articulo.uid)
        .update(articulo.toMap());
  }

  // Guarda o actualiza un artículo en el checklist de un vehículo.
  // Entrada: registro con los datos del vehículo, artículo y estado de inventario.
  // Salida: un Future que termina cuando Firestore confirma el registro.
  // Lanza errores si no hay sesión, faltan identificadores o no se encuentra el RPE.
  Future<void> guardarRegistro(InventarioModel registro) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para guardar el inventario.');
    }

    if (registro.vehiculoUid.trim().isEmpty ||
        registro.articuloUid.trim().isEmpty) {
      throw ArgumentError('Selecciona un vehículo y un artículo.');
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    final datosUsuario = documentoUsuario.data();
    final rpe = datosUsuario?['rpe']?.toString().trim() ?? '';

    if (!documentoUsuario.exists || rpe.isEmpty) {
      throw StateError('No se encontró el RPE del usuario.');
    }

    // El mismo vehículo y artículo siempre utilizan el mismo documento.
    // Así, guardar otra vez actualiza el registro en lugar de duplicarlo.
    final idDocumento =
        '${registro.vehiculoUid}_${registro.articuloUid}';

    final datos = registro.toMap();
    datos['usuarioUid'] = usuarioActual.uid;
    datos['rpeUsuario'] = rpe;
    datos['actualizadoEn'] = FieldValue.serverTimestamp();

    await _db
        .collection('inventario')
        .doc(idDocumento)
        .set(datos);
  }

  // Retira un artículo del inventario de un vehículo.
  // Entradas: vehiculoUid y articuloUid para identificar el registro.
  // Salida: un Future que termina cuando Firestore confirma la eliminación.
  // Lanza ArgumentError si alguno de los identificadores está vacío.
  Future<void> eliminarRegistro({
    required String vehiculoUid,
    required String articuloUid,
  }) async {
    if (vehiculoUid.trim().isEmpty || articuloUid.trim().isEmpty) {
      throw ArgumentError('El vehículo o el artículo no son válidos.');
    }

    final idDocumento = '${vehiculoUid.trim()}_${articuloUid.trim()}';

    await _db
        .collection('inventario')
        .doc(idDocumento)
        .delete();
  }
}