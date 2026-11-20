
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';

class MantenimientoRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _mantenimientos =>
      _db.collection('mantenimiento');

  CollectionReference<Map<String, dynamic>> get _detalleRefaccion =>
      _db.collection('detalleRefaccion');

  // Obtiene los datos del usuario que inició sesión.
  Future<Map<String, dynamic>> _obtenerDatosUsuario() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para continuar.');
    }

    final documento = await _db
        .collection('usuario')
        .doc(usuarioActual.uid)
        .get();

    if (!documento.exists || documento.data() == null) {
      throw StateError('No se encontró la información de tu usuario.');
    }

    return documento.data()!;
  }

  // Verifica que el usuario tenga acceso al vehículo.
  Future<void> _verificarAccesoVehiculo(String vehiculoUid) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para continuar.');
    }

    final datosUsuario = await _obtenerDatosUsuario();
    final rol = datosUsuario['rol']?.toString().trim().toLowerCase() ?? '';

    if (rol == 'administrador' || rol == 'superusuario') {
      return;
    }

    if (rol != 'operador') {
      throw StateError('Tu cuenta no tiene permiso para esta operación.');
    }

    final documentoVehiculo =
        await _db.collection('vehiculo').doc(vehiculoUid).get();

    if (!documentoVehiculo.exists) {
      throw StateError('No se encontró el vehículo solicitado.');
    }

    final operadorAsignado =
        documentoVehiculo.data()?['operadorUidActual']?.toString() ?? '';

    if (operadorAsignado != usuarioActual.uid) {
      throw StateError(
        'Solo puedes consultar el vehículo que tienes asignado.',
      );
    }
  }

  // Obtiene los vehículos disponibles según el rol del usuario.
  Stream<List<VehiculoModel>> obtenerVehiculos() async* {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para continuar.');
    }

    final datosUsuario = await _obtenerDatosUsuario();
    final rol = datosUsuario['rol']?.toString().trim().toLowerCase() ?? '';

    Query<Map<String, dynamic>> consulta = _db.collection('vehiculo');

    if (rol == 'operador') {
      consulta = consulta.where(
        'operadorUidActual',
        isEqualTo: usuarioActual.uid,
      );
    } else if (rol != 'administrador' && rol != 'superusuario') {
      throw StateError('Tu cuenta no tiene permiso para ver vehículos.');
    }

    await for (final resultado in consulta.snapshots()) {
      yield resultado.docs.map((documento) {
        return VehiculoModel.fromMap(
          documento.data(),
          documento.id,
        );
      }).toList();
    }
  }

  // Obtiene los mantenimientos de un vehículo.
  Stream<List<MantenimientoModel>> obtenerMantenimientos({
    required String vehiculoUid,
  }) async* {
    await _verificarAccesoVehiculo(vehiculoUid);

    await for (final resultado in _mantenimientos
        .where('vehiculoUid', isEqualTo: vehiculoUid)
        .snapshots()) {
      final lista = <MantenimientoModel>[];

      for (final documento in resultado.docs) {
        final datosMantenimiento = documento.data();

        // Recupera las refacciones asociadas al mantenimiento.
        final resultadoRefacciones = await _detalleRefaccion
            .where('mantenimientoUid', isEqualTo: documento.id)
            .get();

        if (resultadoRefacciones.docs.isNotEmpty) {
          datosMantenimiento['detalleRefacciones'] =
              resultadoRefacciones.docs.map((detalle) {
            return {
              ...detalle.data(),
              'uid': detalle.id,
            };
          }).toList();
        }

        lista.add(
          MantenimientoModel.fromMap(
            datosMantenimiento,
            documento.id,
          ),
        );
      }

      // Primero se muestran los programados y pendientes.
      // Después se muestran los realizados.
      lista.sort((a, b) {
        final prioridadA = a.estaRealizado ? 1 : 0;
        final prioridadB = b.estaRealizado ? 1 : 0;

        if (prioridadA != prioridadB) {
          return prioridadA.compareTo(prioridadB);
        }

        // Ordena los programados y pendientes por fecha programada.
        if (!a.estaRealizado && !b.estaRealizado) {
          final fechaA = a.fechaProgramada;
          final fechaB = b.fechaProgramada;

          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;

          return fechaA.compareTo(fechaB);
        }

        // Ordena los realizados por fecha de realización.
        final fechaA = a.fechaRealizado;
        final fechaB = b.fechaRealizado;

        if (fechaA == null && fechaB == null) return 0;
        if (fechaA == null) return 1;
        if (fechaB == null) return -1;

        return fechaB.compareTo(fechaA);
      });

      yield lista;
    }
  }

  // Registra un nuevo mantenimiento.
  Future<void> registrarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    await _verificarAccesoVehiculo(mantenimiento.vehiculoUid);

    final usuarioActual = _auth.currentUser!;
    final datosUsuario = await _obtenerDatosUsuario();

    final documentoMantenimiento = _mantenimientos.doc();
    final lote = _db.batch();

    final datosMantenimiento = mantenimiento.toMap();
    datosMantenimiento['usuarioUid'] = usuarioActual.uid;
    datosMantenimiento['rpeUsuario'] =
        datosUsuario['rpe']?.toString().trim() ?? '';
    datosMantenimiento['creadoEn'] = FieldValue.serverTimestamp();

    lote.set(documentoMantenimiento, datosMantenimiento);

    // Guarda las refacciones del mantenimiento.
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

  // Actualiza un mantenimiento existente.
  Future<void> actualizarMantenimiento(
    MantenimientoModel mantenimiento,
  ) async {
    if (mantenimiento.uid.trim().isEmpty) {
      throw ArgumentError(
        'El mantenimiento no tiene un identificador válido.',
      );
    }

    await _verificarAccesoVehiculo(mantenimiento.vehiculoUid);

    final documentoExistente =
        await _mantenimientos.doc(mantenimiento.uid).get();

    if (!documentoExistente.exists) {
      throw StateError(
        'No se encontró el mantenimiento que deseas actualizar.',
      );
    }

    final vehiculoOriginal =
        documentoExistente.data()?['vehiculoUid']?.toString() ?? '';

    if (vehiculoOriginal != mantenimiento.vehiculoUid) {
      throw StateError(
        'No se puede cambiar el vehículo de este mantenimiento.',
      );
    }

    final refaccionesAnteriores = await _detalleRefaccion
        .where('mantenimientoUid', isEqualTo: mantenimiento.uid)
        .get();

    final lote = _db.batch();

    lote.update(
      _mantenimientos.doc(mantenimiento.uid),
      {
        ...mantenimiento.toMap(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      },
    );

    // Elimina las refacciones anteriores.
    for (final documento in refaccionesAnteriores.docs) {
      lote.delete(documento.reference);
    }

    // Registra nuevamente las refacciones actualizadas.
    for (final refaccion in mantenimiento.detalleRefacciones) {
      if (refaccion.nombre.trim().isEmpty || refaccion.cantidad <= 0) {
        continue;
      }

      final nuevoDetalle = _detalleRefaccion.doc();
      final datosRefaccion = refaccion.toMap();
      datosRefaccion['mantenimientoUid'] = mantenimiento.uid;

      lote.set(nuevoDetalle, datosRefaccion);
    }

    await lote.commit();
  }

  // Elimina un mantenimiento y sus refacciones.
  Future<void> eliminarMantenimiento(String mantenimientoUid) async {
    if (mantenimientoUid.trim().isEmpty) {
      throw ArgumentError(
        'El mantenimiento no tiene un identificador válido.',
      );
    }

    final documentoMantenimiento =
        await _mantenimientos.doc(mantenimientoUid).get();

    if (!documentoMantenimiento.exists) {
      throw StateError(
        'No se encontró el mantenimiento que deseas eliminar.',
      );
    }

    final vehiculoUid =
        documentoMantenimiento.data()?['vehiculoUid']?.toString() ?? '';

    await _verificarAccesoVehiculo(vehiculoUid);

    final refacciones = await _detalleRefaccion
        .where('mantenimientoUid', isEqualTo: mantenimientoUid)
        .get();

    final lote = _db.batch();

    lote.delete(_mantenimientos.doc(mantenimientoUid));

    for (final documento in refacciones.docs) {
      lote.delete(documento.reference);
    }

    await lote.commit();
  }
}
