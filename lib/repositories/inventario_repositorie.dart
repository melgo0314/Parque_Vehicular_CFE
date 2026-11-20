import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';

class InventarioRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Consultar el rol del usuario que inició sesión.
  Future<String> obtenerRolUsuarioActual() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    if (!documentoUsuario.exists) {
      throw StateError('No se encontró el perfil del usuario.');
    }

    final datos = documentoUsuario.data();
    return datos?['rol']?.toString().trim().toLowerCase() ?? '';
  }

  // Administradores ven todos los vehículos.
  // Operadores solo ven los vehículos que tienen asignados.
  Stream<List<VehiculoModel>> obtenerVehiculosPermitidos() {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      return Stream.value(<VehiculoModel>[]);
    }

    return _db
        .collection('usuario')
        .doc(usuarioActual.uid)
        .snapshots()
        .asyncExpand((documentoUsuario) {
      final datosUsuario = documentoUsuario.data();
      final rol = datosUsuario?['rol']?.toString().trim().toLowerCase() ?? '';

      if (rol == 'administrador' || rol == 'superusuario') {
        return _leerVehiculos(_db.collection('vehiculo'));
      }

      if (rol == 'operador') {
        final consulta = _db
            .collection('vehiculo')
            .where('operadorUidActual', isEqualTo: usuarioActual.uid);

        return _leerVehiculos(consulta);
      }

      return Stream.value(<VehiculoModel>[]);
    });
  }

  // Convertir los documentos de vehículos a modelos.
  Stream<List<VehiculoModel>> _leerVehiculos(
    Query<Map<String, dynamic>> consulta,
  ) {
    return consulta.snapshots().map((resultado) {
      return resultado.docs.map((documento) {
        return VehiculoModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();
    });
  }

  // Leer el catálogo de artículos activos.
  Stream<List<ArticuloModel>> obtenerArticulos() {
    return _db.collection('articulo').snapshots().map((resultado) {
      final articulos = resultado.docs.map((documento) {
        return ArticuloModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();

      return articulos.where((articulo) => articulo.activo).toList();
    });
  }

  // Consultar el checklist de un vehículo.
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

  // Crear un artículo para el catálogo.
  Future<void> registrarArticulo(ArticuloModel articulo) async {
    await _db.collection('articulo').add(articulo.toMap());
  }

  // Actualizar un artículo del catálogo.
  Future<void> actualizarArticulo(ArticuloModel articulo) async {
    if (articulo.uid.trim().isEmpty) {
      throw ArgumentError('El artículo no tiene un identificador válido.');
    }

    await _db
        .collection('articulo')
        .doc(articulo.uid)
        .update(articulo.toMap());
  }

  // Guardar o actualizar un artículo en el checklist del vehículo.
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

  // Retirar un artículo del inventario de un vehículo.
  Future<void> eliminarRegistro({
    required String vehiculoUid,
    required String articuloUid,
  }) async {
    if (vehiculoUid.trim().isEmpty || articuloUid.trim().isEmpty) {
      throw ArgumentError('El vehículo o el artículo no son válidos.');
    }

    final idDocumento =
        '${vehiculoUid.trim()}_${articuloUid.trim()}';

    await _db
        .collection('inventario')
        .doc(idDocumento)
        .delete();
  }
}