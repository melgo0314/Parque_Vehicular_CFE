import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';

// Se comunica con Firebase para administrar mantenimientos y sus refacciones.
class MantenimientoRepositorie {
  // Conexión a Cloud Firestore.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Servicio de Firebase Authentication.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Referencia a la colección de mantenimientos.
  CollectionReference<Map<String, dynamic>> get _mantenimientos =>
      _db.collection('mantenimiento');

  // Referencia a la colección de detalles de refacciones.
  CollectionReference<Map<String, dynamic>> get _detalleRefaccion =>
      _db.collection('detalleRefaccion');

  // Verifica la sesión y el rol del usuario autenticado.
  // Entrada: ninguna; consulta la sesión y el perfil actual en Firebase.
  // Salida: datos del usuario autorizado; lanza StateError si no hay sesión,
  // el perfil no existe o el usuario no tiene el rol requerido.
  Future<Map<String, dynamic>> _obtenerAdministrador() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError(
        'Debes iniciar sesión para realizar esta operación.',
      );
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    if (!documentoUsuario.exists || documentoUsuario.data() == null) {
      throw StateError('No se encontró la información de tu usuario.');
    }

    final datosUsuario = documentoUsuario.data()!;
    final rol = datosUsuario['rol']?.toString().trim().toLowerCase() ?? '';

    if (rol != 'administrador' && rol != 'superusuario') {
      throw StateError(
        'Solo un administrador puede gestionar mantenimientos.',
      );
    }

    return datosUsuario;
  }

  // Obtiene en tiempo real los vehículos guardados en Firestore.
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

  // Registra un mantenimiento y guarda sus refacciones relacionadas.
  // Entrada: mantenimiento con los datos del servicio y la lista de refacciones.
  // Salida: un Future que termina cuando Firestore confirma el registro.
  Future<void> registrarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    final datosUsuario = await _obtenerAdministrador();
    final usuarioActual = _auth.currentUser!;

    final documentoMantenimiento = _mantenimientos.doc();
    final lote = _db.batch();

    final datosMantenimiento = mantenimiento.toMap();
    datosMantenimiento['usuarioUid'] = usuarioActual.uid;
    datosMantenimiento['rpeUsuario'] =
        datosUsuario['rpe']?.toString().trim() ?? '';
    datosMantenimiento['creadoEn'] = FieldValue.serverTimestamp();

    lote.set(documentoMantenimiento, datosMantenimiento);

    // Omite refacciones sin nombre o con una cantidad no válida.
    for (final refaccion in mantenimiento.detalleRefacciones) {
      if (refaccion.nombre.trim().isEmpty || refaccion.cantidad <= 0) {
        continue;
      }

      final documentoRefaccion = _detalleRefaccion.doc();
      final datosRefaccion = refaccion.toMap();

      datosRefaccion['mantenimientoUid'] = documentoMantenimiento.id;

      lote.set(documentoRefaccion, datosRefaccion);
    }

    await lote.commit();
  }

  // Obtiene los mantenimientos de un vehículo y sus refacciones.
  // Entrada: vehiculoUid, identificador del vehículo que se consultará.
  // Salida: un flujo de mantenimientos ordenado desde la fecha más reciente.
  Stream<List<MantenimientoModel>> obtenerMantenimientos({
    required String vehiculoUid,
  }) {
    return _mantenimientos
        .where('vehiculoUid', isEqualTo: vehiculoUid)
        .snapshots()
        .asyncMap((resultado) async {
      final lista = <MantenimientoModel>[];

      for (final documento in resultado.docs) {
        final datosMantenimiento = documento.data();

        final resultadoRefacciones = await _detalleRefaccion
            .where(
              'mantenimientoUid',
              isEqualTo: documento.id,
            )
            .get();

        if (resultadoRefacciones.docs.isNotEmpty) {
          datosMantenimiento['detalleRefacciones'] =
              resultadoRefacciones.docs.map((documentoRefaccion) {
            return {
              ...documentoRefaccion.data(),
              'uid': documentoRefaccion.id,
            };
          }).toList();
        }

        // Permite leer registros antiguos que guardaban las refacciones
        // directamente dentro del documento principal.
        lista.add(
          MantenimientoModel.fromMap(
            datosMantenimiento,
            documento.id,
          ),
        );
      }

      lista.sort(
        (a, b) => b.fechaRealizado.compareTo(a.fechaRealizado),
      );

      return lista;
    });
  }

  // Actualiza un mantenimiento y reemplaza sus documentos de refacciones.
  // Entrada: mantenimiento con identificador y datos actualizados.
  // Salida: un Future que termina cuando Firestore confirma los cambios.
  // Lanza ArgumentError si el mantenimiento no tiene un identificador válido.
  Future<void> actualizarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    await _obtenerAdministrador();

    if (mantenimiento.uid.trim().isEmpty) {
      throw ArgumentError(
        'El mantenimiento no tiene un identificador válido.',
      );
    }

    final documentosRefacciones = await _detalleRefaccion
        .where(
          'mantenimientoUid',
          isEqualTo: mantenimiento.uid,
        )
        .get();

    final lote = _db.batch();

    lote.update(
      _mantenimientos.doc(mantenimiento.uid),
      {
        ...mantenimiento.toMap(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      },
    );

    // Elimina los detalles anteriores antes de guardar la lista actualizada.
    for (final documento in documentosRefacciones.docs) {
      lote.delete(documento.reference);
    }

    // Guarda los detalles válidos asociados al mantenimiento actualizado.
    for (final refaccion in mantenimiento.detalleRefacciones) {
      if (refaccion.nombre.trim().isEmpty || refaccion.cantidad <= 0) {
        continue;
      }

      final documentoRefaccion = _detalleRefaccion.doc();
      final datosRefaccion = refaccion.toMap();

      datosRefaccion['mantenimientoUid'] = mantenimiento.uid;

      lote.set(documentoRefaccion, datosRefaccion);
    }

    await lote.commit();
  }

  // Elimina un mantenimiento y todos sus documentos de refacciones.
  // Entrada: mantenimientoUid, identificador del mantenimiento que se eliminará.
  // Salida: un Future que termina cuando Firestore confirma la eliminación.
  // Lanza ArgumentError si el identificador está vacío.
  Future<void> eliminarMantenimiento(String mantenimientoUid) async {
    await _obtenerAdministrador();

    if (mantenimientoUid.trim().isEmpty) {
      throw ArgumentError(
        'El mantenimiento no tiene un identificador válido.',
      );
    }

    final documentosRefacciones = await _detalleRefaccion
        .where(
          'mantenimientoUid',
          isEqualTo: mantenimientoUid,
        )
        .get();

    final lote = _db.batch();

    lote.delete(_mantenimientos.doc(mantenimientoUid));

    for (final documento in documentosRefacciones.docs) {
      lote.delete(documento.reference);
    }

    await lote.commit();
  }
}