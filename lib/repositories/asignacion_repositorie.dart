import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/asignacion_model.dart';
import '../models/user_model.dart';
import '../models/vehiculos_model.dart';

class AsignacionRepositorie {
  AsignacionRepositorie({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _asignaciones =>
      _db.collection('asignacion');

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuario');

  CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _db.collection('vehiculo');

  Stream<List<AsignacionModel>> obtenerAsignaciones({
    String busqueda = '',
    String estado = 'todas',
  }) {
    return _asignaciones.snapshots().map((consulta) {
      final termino = busqueda.trim().toLowerCase();

      final lista = consulta.docs
          .map(
            (documento) => AsignacionModel.fromMap(
              documento.data(),
              documento.id,
            ),
          )
          .where((asignacion) {
        final coincideEstado = estado == 'todas' ||
            asignacion.estado.toLowerCase() == estado.toLowerCase();

        final texto = [
          asignacion.operadorNombre,
          asignacion.vehiculoPlacas,
          asignacion.vehiculoNumeroEconomico,
          asignacion.vehiculoTipo,
          asignacion.motivoTemporal,
        ].join(' ').toLowerCase();

        return coincideEstado &&
            (termino.isEmpty || texto.contains(termino));
      }).toList();

      lista.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return lista;
    });
  }

  Future<List<UserModel>> obtenerOperadoresDisponibles({
    String? excluirAsignacionUid,
  }) async {
    final usuarios = await _usuarios.get();
    final asignaciones = await _asignaciones.get();

    final operadoresOcupados = <String>{};

    for (final documento in asignaciones.docs) {
      if (documento.id == excluirAsignacionUid) continue;

      final asignacion = AsignacionModel.fromMap(
        documento.data(),
        documento.id,
      );

      if (asignacion.estaActiva) {
        operadoresOcupados.add(asignacion.operadorUid);
      }
    }

    final resultado = usuarios.docs
        .where((documento) {
          final rol =
              (documento.data()['rol'] ?? '').toString().trim().toLowerCase();

          return rol == 'operador' &&
              !operadoresOcupados.contains(documento.id);
        })
        .map(
          (documento) => UserModel.fromMap(
            documento.data(),
            documento.id,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => a.nombreCompleto.toLowerCase().compareTo(
            b.nombreCompleto.toLowerCase(),
          ),
    );

    return resultado;
  }

  Future<List<VehiculoModel>> obtenerVehiculosDisponibles({
    String? excluirAsignacionUid,
  }) async {
    final documentosVehiculos = await _vehiculos.get();
    final documentosAsignaciones = await _asignaciones.get();

    AsignacionModel? asignacionExcluida;

    if (excluirAsignacionUid != null) {
      for (final documento in documentosAsignaciones.docs) {
        if (documento.id == excluirAsignacionUid) {
          asignacionExcluida = AsignacionModel.fromMap(
            documento.data(),
            documento.id,
          );
          break;
        }
      }
    }

    final vehiculosOcupados = <String>{};

    for (final documento in documentosAsignaciones.docs) {
      if (documento.id == excluirAsignacionUid) continue;

      final asignacion = AsignacionModel.fromMap(
        documento.data(),
        documento.id,
      );

      if (asignacion.estaActiva) {
        vehiculosOcupados.add(asignacion.vehiculoUid);
      }
    }

    final resultado = documentosVehiculos.docs
        .map(
          (documento) => VehiculoModel.fromMap(
            documento.data(),
            documento.id,
          ),
        )
        .where((vehiculo) {
          final esElVehiculoActual =
              asignacionExcluida?.vehiculoUid == vehiculo.uid;

          return vehiculo.estaActivo &&
              !vehiculosOcupados.contains(vehiculo.uid) &&
              (!vehiculo.tieneOperadorAsignado || esElVehiculoActual);
        })
        .toList();

    resultado.sort(
      (a, b) => a.placas.toLowerCase().compareTo(b.placas.toLowerCase()),
    );

    return resultado;
  }

  Future<void> crearAsignacion({
    required String operadorUid,
    required String vehiculoUid,
    required DateTime fechaInicio,
    String tipo = 'permanente',
    DateTime? fechaFin,
    String motivoTemporal = '',
  }) async {
    final administradorUid = await _obtenerAdministradorUid();

    await _guardarAsignacion(
      uidAsignacion: null,
      operadorUid: operadorUid,
      vehiculoUid: vehiculoUid,
      administradorUid: administradorUid,
      fechaInicio: fechaInicio,
      tipo: tipo,
      fechaFin: fechaFin,
      motivoTemporal: motivoTemporal,
    );
  }

  Future<void> actualizarAsignacion(AsignacionModel asignacion) async {
    final administradorUid = await _obtenerAdministradorUid();

    await _guardarAsignacion(
      uidAsignacion: asignacion.uid,
      operadorUid: asignacion.operadorUid,
      vehiculoUid: asignacion.vehiculoUid,
      administradorUid: administradorUid,
      fechaInicio: asignacion.fechaInicio,
      tipo: asignacion.tipo,
      fechaFin: asignacion.fechaFin,
      motivoTemporal: asignacion.motivoTemporal,
    );
  }

  Future<void> finalizarAsignacion(String uidAsignacion) async {
    await _obtenerAdministradorUid();

    final referenciaAsignacion = _asignaciones.doc(uidAsignacion.trim());
    final documento = await referenciaAsignacion.get();

    if (!documento.exists || documento.data() == null) {
      throw StateError('La asignación ya no existe.');
    }

    final asignacion = AsignacionModel.fromMap(
      documento.data()!,
      documento.id,
    );

    if (!asignacion.estaActiva) {
      throw StateError('Esta asignación ya está finalizada.');
    }

    final referenciaVehiculo = _vehiculos.doc(asignacion.vehiculoUid);
    final documentoVehiculo = await referenciaVehiculo.get();

    final lote = _db.batch();

    lote.update(referenciaAsignacion, {
      'fechaFin': Timestamp.fromDate(DateTime.now()),
      'estado': 'finalizada',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    // Quita el operador solo si este vehículo todavía lo tiene asignado.
    if (documentoVehiculo.exists) {
      final datosVehiculo = documentoVehiculo.data() ?? {};
      final operadorActual = (datosVehiculo['operadorUidActual'] ??
              datosVehiculo['operadorUid'] ??
              '')
          .toString()
          .trim();

      if (operadorActual == asignacion.operadorUid) {
        lote.update(referenciaVehiculo, {
          'operadorUidActual': FieldValue.delete(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }
    }

    await lote.commit();
  }

  Future<void> _guardarAsignacion({
    required String? uidAsignacion,
    required String operadorUid,
    required String vehiculoUid,
    required String administradorUid,
    required DateTime fechaInicio,
    required String tipo,
    required DateTime? fechaFin,
    required String motivoTemporal,
  }) async {
    final operadorId = operadorUid.trim();
    final vehiculoId = vehiculoUid.trim();
    final tipoNormalizado = tipo.trim().toLowerCase();
    final motivo = motivoTemporal.trim();

    if (operadorId.isEmpty) {
      throw ArgumentError('Selecciona un operador.');
    }

    if (vehiculoId.isEmpty) {
      throw ArgumentError('Selecciona un vehículo.');
    }

    if (tipoNormalizado != 'permanente' &&
        tipoNormalizado != 'temporal') {
      throw ArgumentError('Selecciona el tipo de asignación.');
    }

    if (tipoNormalizado == 'temporal') {
      if (fechaFin == null) {
        throw ArgumentError(
          'Selecciona la fecha de término de la asignación temporal.',
        );
      }

      if (fechaFin.isBefore(fechaInicio)) {
        throw ArgumentError(
          'La fecha de término debe ser posterior a la fecha de inicio.',
        );
      }

      if (motivo.isEmpty) {
        throw ArgumentError('Escribe el motivo de la asignación temporal.');
      }
    }

    final operadorDoc = await _usuarios.doc(operadorId).get();
    final vehiculoDoc = await _vehiculos.doc(vehiculoId).get();
    final asignacionesSnapshot = await _asignaciones.get();

    if (!operadorDoc.exists || operadorDoc.data() == null) {
      throw StateError('El operador seleccionado ya no existe.');
    }

    if (!vehiculoDoc.exists || vehiculoDoc.data() == null) {
      throw StateError('El vehículo seleccionado ya no existe.');
    }

    final operadorDatos = operadorDoc.data()!;
    final rol = (operadorDatos['rol'] ?? '').toString().trim().toLowerCase();

    if (rol != 'operador') {
      throw StateError('La cuenta seleccionada no tiene el rol de operador.');
    }

    final vehiculo = VehiculoModel.fromMap(
      vehiculoDoc.data()!,
      vehiculoDoc.id,
    );

    if (!vehiculo.estaActivo) {
      throw StateError('No se puede asignar un vehículo dado de baja.');
    }

    final referenciaAsignacion = uidAsignacion == null
        ? _asignaciones.doc()
        : _asignaciones.doc(uidAsignacion);

    AsignacionModel? asignacionAnterior;

    if (uidAsignacion != null) {
      final documentoAnterior = await referenciaAsignacion.get();

      if (!documentoAnterior.exists || documentoAnterior.data() == null) {
        throw StateError('La asignación que intentas editar ya no existe.');
      }

      asignacionAnterior = AsignacionModel.fromMap(
        documentoAnterior.data()!,
        documentoAnterior.id,
      );

      if (!asignacionAnterior.estaActiva) {
        throw StateError('No se puede editar una asignación finalizada.');
      }
    }

    for (final documento in asignacionesSnapshot.docs) {
      if (documento.id == uidAsignacion) continue;

      final existente = AsignacionModel.fromMap(
        documento.data(),
        documento.id,
      );

      if (!existente.estaActiva) continue;

      if (existente.operadorUid == operadorId) {
        throw StateError(
          'El operador seleccionado ya tiene un vehículo asignado.',
        );
      }

      if (existente.vehiculoUid == vehiculoId) {
        throw StateError(
          'El vehículo seleccionado ya está asignado a otro operador.',
        );
      }
    }

    final operadorEnVehiculo = (vehiculoDoc.data()?['operadorUidActual'] ??
            vehiculoDoc.data()?['operadorUid'] ??
            '')
        .toString()
        .trim();

    final esMismoVehiculoDeLaEdicion =
        asignacionAnterior?.vehiculoUid == vehiculoId;

    if (operadorEnVehiculo.isNotEmpty &&
        operadorEnVehiculo != operadorId &&
        !esMismoVehiculoDeLaEdicion) {
      throw StateError(
        'El vehículo ya tiene un operador asignado. Finaliza esa asignación primero.',
      );
    }

    final nombreOperador = [
      operadorDatos['nombre'],
      operadorDatos['apellidoP'],
      operadorDatos['apellidoM'],
    ]
        .where((parte) => parte != null && parte.toString().trim().isNotEmpty)
        .map((parte) => parte.toString().trim())
        .join(' ');

    final tipoVehiculo =
        '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}'.trim();

    final asignacion = AsignacionModel(
      uid: referenciaAsignacion.id,
      vehiculoUid: vehiculo.uid,
      operadorUid: operadorId,
      administradorUid: administradorUid,
      operadorNombre: nombreOperador,
      vehiculoPlacas: vehiculo.placas,
      vehiculoNumeroEconomico: vehiculo.numeroEconomico,
      vehiculoTipo: tipoVehiculo,
      fechaInicio: fechaInicio,
      fechaFin: tipoNormalizado == 'temporal' ? fechaFin : null,
      tipo: tipoNormalizado,
      motivoTemporal: tipoNormalizado == 'temporal' ? motivo : '',
      estado: tipoNormalizado == 'temporal' ? 'temporal' : 'vigente',
    );

    final datosAsignacion = asignacion.toMap()
      ..['actualizadoEn'] = FieldValue.serverTimestamp();

    final lote = _db.batch();

    if (uidAsignacion == null) {
      datosAsignacion['creadoEn'] = FieldValue.serverTimestamp();
      lote.set(referenciaAsignacion, datosAsignacion);
    } else {
      lote.update(referenciaAsignacion, datosAsignacion);
    }

    // El módulo Asignaciones es quien actualiza al operador actual del vehículo.
    lote.update(_vehiculos.doc(vehiculoId), {
      'operadorUidActual': operadorId,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    // Si al editar se cambió de vehículo, se libera la unidad anterior.
    if (asignacionAnterior != null &&
        asignacionAnterior.vehiculoUid != vehiculoId) {
      final referenciaVehiculoAnterior =
          _vehiculos.doc(asignacionAnterior.vehiculoUid);
      final documentoAnterior = await referenciaVehiculoAnterior.get();

      final operadorAnterior = (documentoAnterior.data()?['operadorUidActual'] ??
              documentoAnterior.data()?['operadorUid'] ??
              '')
          .toString()
          .trim();

      if (documentoAnterior.exists &&
          operadorAnterior == asignacionAnterior.operadorUid) {
        lote.update(referenciaVehiculoAnterior, {
          'operadorUidActual': FieldValue.delete(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }
    }

    await lote.commit();
  }

  Future<String> _obtenerAdministradorUid() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Inicia sesión para gestionar asignaciones.');
    }

    final documento = await _usuarios.doc(usuarioActual.uid).get();
    final datos = documento.data();
    final rol = (datos?['rol'] ?? '').toString().trim().toLowerCase();

    if (!documento.exists ||
        (rol != 'administrador' && rol != 'superusuario')) {
      throw StateError(
        'Solo un administrador puede gestionar asignaciones.',
      );
    }

    return usuarioActual.uid;
  }
}