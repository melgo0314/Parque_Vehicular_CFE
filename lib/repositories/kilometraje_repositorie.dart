
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/kilometraje_model.dart';

// Se comunica con Firebase para administrar jornadas de kilometraje.
class KilometrajeRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Registra el inicio de una jornada.
  Future<void> registrarKilometraje(KilometrajeModel registro) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para registrar el kilometraje.');
    }

    if (registro.vehiculoUid.trim().isEmpty) {
      throw ArgumentError('Selecciona un vehículo.');
    }

    if (registro.kilometrajeIni < 0) {
      throw ArgumentError('El kilometraje inicial no puede ser negativo.');
    }

    // Obtiene el RPE del usuario autenticado.
    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    final rpe = documentoUsuario.data()?['rpe']?.toString().trim() ?? '';

    if (!documentoUsuario.exists || rpe.isEmpty) {
      throw StateError('No se encontró el RPE de tu usuario.');
    }

    final vehiculoUid = registro.vehiculoUid.trim();

    final referenciaVehiculo =
        _db.collection('vehiculo').doc(vehiculoUid);

    final referenciaBloqueo =
        _db.collection('jornada_activa').doc(vehiculoUid);

    final referenciaRegistro = _db.collection('kilometraje').doc();

    // Comprueba si ya existe una jornada pendiente.
    final registrosVehiculo = await _db
        .collection('kilometraje')
        .where('vehiculoUid', isEqualTo: vehiculoUid)
        .get();

    for (final documento in registrosVehiculo.docs) {
      if (documento.data()['kilometrajeFinal'] == null) {
        throw StateError(
          'Este vehículo ya tiene una jornada pendiente de finalizar.',
        );
      }
    }

    // La transacción evita iniciar dos jornadas simultáneamente.
    await _db.runTransaction((transaccion) async {
      final documentoBloqueo =
          await transaccion.get(referenciaBloqueo);

      final documentoVehiculo =
          await transaccion.get(referenciaVehiculo);

      if (documentoBloqueo.exists) {
        throw StateError(
          'Este vehículo ya tiene una jornada pendiente de finalizar.',
        );
      }

      if (!documentoVehiculo.exists) {
        throw StateError('No se encontró el vehículo seleccionado.');
      }

      final datosVehiculo = documentoVehiculo.data() ?? {};

      final kilometrajeActual = _convertirNumero(
        datosVehiculo['kilometrajeActual'] ?? datosVehiculo['kilometraje'],
      ).toInt();

      if (registro.kilometrajeIni < kilometrajeActual) {
        throw ArgumentError(
          'El kilometraje inicial no puede ser menor al último registrado '
          '($kilometrajeActual km).',
        );
      }

      final registroConRpe = KilometrajeModel(
        uid: referenciaRegistro.id,
        vehiculoUid: vehiculoUid,
        rpeUsuario: rpe,
        fecha: registro.fecha,
        kilometrajeIni: registro.kilometrajeIni,
        kilometrajeFinal: null,
        observaciones: registro.observaciones,
      );

      transaccion.set(
        referenciaRegistro,
        registroConRpe.toMap(),
      );

      // Guarda el kilometraje base una sola vez para vehículos sin historial.
      // Las siguientes jornadas no desplazan el punto de inicio preventivo.
      if (datosVehiculo['kilometrajeBasePreventivo'] == null) {
        transaccion.update(referenciaVehiculo, {
          'kilometrajeBasePreventivo': registro.kilometrajeIni,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }

      // Bloqueo para impedir otra jornada del mismo vehículo.
      transaccion.set(referenciaBloqueo, {
        'registroUid': referenciaRegistro.id,
        'vehiculoUid': vehiculoUid,
        'fechaInicio': Timestamp.fromDate(registro.fecha),
      });
    });
  }

  // Finaliza una jornada pendiente.
  Future<void> finalizarKilometraje({
    required String uid,
    required int kilometrajeFinal,
    String observaciones = '',
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
    }

    final referenciaRegistro = _db.collection('kilometraje').doc(uid);

    await _db.runTransaction((transaccion) async {
      final documentoRegistro =
          await transaccion.get(referenciaRegistro);

      if (!documentoRegistro.exists) {
        throw StateError('No se encontró la jornada seleccionada.');
      }

      final datos = documentoRegistro.data() ?? {};

      final vehiculoUid = datos['vehiculoUid']?.toString() ?? '';
      final kilometrajeInicial =
          _convertirNumero(datos['kilometrajeIni']).toInt();

      if (datos['kilometrajeFinal'] != null) {
        throw StateError('Esta jornada ya fue finalizada.');
      }

      if (kilometrajeFinal <= kilometrajeInicial) {
        throw ArgumentError(
          'El kilometraje final debe ser mayor al inicial '
          '($kilometrajeInicial km).',
        );
      }

      final referenciaVehiculo =
          _db.collection('vehiculo').doc(vehiculoUid);

      final referenciaBloqueo =
          _db.collection('jornada_activa').doc(vehiculoUid);

      final documentoVehiculo =
          await transaccion.get(referenciaVehiculo);

      final documentoBloqueo =
          await transaccion.get(referenciaBloqueo);

      if (!documentoVehiculo.exists) {
        throw StateError('No se encontró el vehículo de esta jornada.');
      }

      transaccion.update(referenciaRegistro, {
        'kilometrajeFinal': kilometrajeFinal,
        'fechaFin': Timestamp.fromDate(DateTime.now()),
        'observaciones': observaciones.trim(),
      });

      // Actualiza el kilometraje actual del vehículo al finalizar.
      transaccion.update(referenciaVehiculo, {
        'kilometrajeActual': kilometrajeFinal,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      // Libera el vehículo para una nueva jornada.
      if (documentoBloqueo.exists) {
        final datosBloqueo = documentoBloqueo.data() ?? {};

        if (datosBloqueo['registroUid'] == uid) {
          transaccion.delete(referenciaBloqueo);
        }
      }
    });
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

  // Actualiza un registro que ya fue finalizado.
  Future<void> actualizarKilometraje(KilometrajeModel registro) async {
    if (registro.uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
    }

    if (registro.kilometrajeFinal == null ||
        registro.kilometrajeFinal! <= registro.kilometrajeIni) {
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

  // Elimina un registro y libera el vehículo si estaba pendiente.
  Future<void> eliminarKilometraje(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El registro no tiene un identificador válido.');
    }

    final referenciaRegistro = _db.collection('kilometraje').doc(uid);
    final documento = await referenciaRegistro.get();

    if (!documento.exists) {
      throw StateError('El registro de kilometraje ya no existe.');
    }

    final datos = documento.data() ?? {};
    final vehiculoUid = datos['vehiculoUid']?.toString().trim() ?? '';
    final estaPendiente = datos['kilometrajeFinal'] == null;

    await referenciaRegistro.delete();

    if (vehiculoUid.isNotEmpty && estaPendiente) {
      final referenciaBloqueo =
          _db.collection('jornada_activa').doc(vehiculoUid);

      final bloqueo = await referenciaBloqueo.get();

      if (bloqueo.exists &&
          bloqueo.data()?['registroUid'] == uid) {
        await referenciaBloqueo.delete();
      }
    }

    if (vehiculoUid.isNotEmpty && !estaPendiente) {
      await _actualizarKilometrajeDelVehiculo(vehiculoUid);
    }
  }

  // Recalcula el kilometraje actual usando la última jornada finalizada.
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
    }).where((registro) {
      return registro.kilometrajeFinal != null;
    }).toList();

    registros.sort((a, b) {
      final fechaA = a.fechaFin ?? a.fecha;
      final fechaB = b.fechaFin ?? b.fecha;
      return fechaB.compareTo(fechaA);
    });

    final kilometrajeActual = registros.isEmpty
        ? 0
        : registros.first.kilometrajeFinal!;

    await _db.collection('vehiculo').doc(vehiculoUid).update({
      'kilometrajeActual': kilometrajeActual,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // Convierte un valor dinámico en número decimal.
  double _convertirNumero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }
}
