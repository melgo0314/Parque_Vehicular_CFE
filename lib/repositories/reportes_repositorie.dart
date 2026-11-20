import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:p_vehicular/models/reporte_model.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/models/kilometraje_model.dart';
import 'package:p_vehicular/models/combustible_model.dart';
import 'package:p_vehicular/models/mantenimiento_model.dart';

class ReportesRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Verifica que el usuario tenga el rol de administrador.
  Future<void> _verificarAdministrador() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw Exception('No hay una sesión iniciada.');
    }

    final documento = await _db
        .collection('usuario')
        .doc(usuarioActual.uid)
        .get();

    if (!documento.exists) {
      throw Exception('No se encontró la información del usuario.');
    }

    final rol = documento.data()?['rol']?.toString().toLowerCase();

    if (rol != 'administrador') {
      throw Exception('No tienes permisos para generar reportes.');
    }
  }

  // Consulta la información necesaria para generar los reportes.
  Future<ReporteModel> obtenerDatosReporte({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<String> vehiculosUid,
  }) async {
    await _verificarAdministrador();

    if (vehiculosUid.isEmpty) {
      throw Exception('Debes seleccionar al menos un vehículo.');
    }

    if (fechaInicio.isAfter(fechaFin)) {
      throw Exception('La fecha inicial no puede ser posterior a la fecha final.');
    }

    // Se agrega un día para incluir todos los registros de la fecha final.
    final inicio = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );

    final finExclusivo = DateTime(
      fechaFin.year,
      fechaFin.month,
      fechaFin.day,
    ).add(const Duration(days: 1));

    final List<VehiculoModel> vehiculos = [];
    final List<KilometrajeModel> registrosKilometraje = [];
    final List<CombustibleModel> cargasCombustible = [];
    final List<CombustibleModel> cargasCombustibleAnteriores = [];
    final List<MantenimientoModel> mantenimientos = [];

    // Consulta la información de cada vehículo seleccionado.
    for (String vehiculoUid in vehiculosUid) {
      final documentoVehiculo = await _db
          .collection('vehiculo')
          .doc(vehiculoUid)
          .get();

      if (!documentoVehiculo.exists) {
        continue;
      }

      final datosVehiculo = documentoVehiculo.data();

      if (datosVehiculo == null) {
        continue;
      }

      vehiculos.add(
        VehiculoModel.fromMap(datosVehiculo, documentoVehiculo.id),
      );

      // Consulta los registros de kilometraje del vehículo.
      final consultaKilometraje = await _db
          .collection('kilometraje')
          .where('vehiculoUid', isEqualTo: vehiculoUid)
          .get();

      for (final documento in consultaKilometraje.docs) {
        final registro = KilometrajeModel.fromMap(
          documento.data(),
          documento.id,
        );

        if (!registro.fecha.isBefore(inicio) &&
            registro.fecha.isBefore(finExclusivo)) {
          registrosKilometraje.add(registro);
        }
      }

      // Consulta las cargas de combustible del vehículo.
      final consultaCombustible = await _db
          .collection('combustible')
          .where('vehiculoUid', isEqualTo: vehiculoUid)
          .get();

      final List<CombustibleModel> cargasVehiculo = [];

      for (final documento in consultaCombustible.docs) {
        cargasVehiculo.add(
          CombustibleModel.fromMap(
            documento.data(),
            documento.id,
          ),
        );
      }

      // Ordena las cargas de la más reciente a la más antigua.
      cargasVehiculo.sort(
        (a, b) => b.fechaCarga.compareTo(a.fechaCarga),
      );

      // Agrega las cargas que pertenecen al periodo seleccionado.
      for (final carga in cargasVehiculo) {
        if (!carga.fechaCarga.isBefore(inicio) &&
            carga.fechaCarga.isBefore(finExclusivo)) {
          cargasCombustible.add(carga);
        }
      }

      // Recupera la última carga anterior al periodo.
      // Se utiliza para calcular el rendimiento de la primera carga del periodo.
      final cargasAnteriores = cargasVehiculo.where((carga) {
        return carga.fechaCarga.isBefore(inicio);
      }).toList();

      if (cargasAnteriores.isNotEmpty) {
        cargasAnteriores.sort(
          (a, b) => b.fechaCarga.compareTo(a.fechaCarga),
        );

        cargasCombustibleAnteriores.add(cargasAnteriores.first);
      }

      // Consulta los mantenimientos del vehículo.
      final consultaMantenimientos = await _db
          .collection('mantenimiento')
          .where('vehiculoUid', isEqualTo: vehiculoUid)
          .get();

      for (final documento in consultaMantenimientos.docs) {
        final datosMantenimiento = documento.data();

        final fechaRealizado = datosMantenimiento['fechaRealizado'];

        DateTime fecha;

        if (fechaRealizado is Timestamp) {
          fecha = fechaRealizado.toDate();
        } else if (fechaRealizado is DateTime) {
          fecha = fechaRealizado;
        } else {
          continue;
        }

        // Solo se incluyen los mantenimientos del periodo seleccionado.
        if (fecha.isBefore(inicio) || !fecha.isBefore(finExclusivo)) {
          continue;
        }

        // Consulta las refacciones relacionadas con el mantenimiento.
        final consultaRefacciones = await _db
            .collection('detalleRefaccion')
            .where(
              'mantenimientoUid',
              isEqualTo: documento.id,
            )
            .get();

        final List<Map<String, dynamic>> refacciones = [];

        for (final refaccion in consultaRefacciones.docs) {
          refacciones.add(refaccion.data());
        }

        // Se agregan las refacciones al mapa para construir el modelo.
        final mantenimiento = MantenimientoModel.fromMap(
          {
            ...datosMantenimiento,
            'detalleRefacciones': refacciones,
          },
          documento.id,
        );

        mantenimientos.add(mantenimiento);
      }
    }

    // Ordena los registros por fecha, del más reciente al más antiguo.
    registrosKilometraje.sort(
      (a, b) => b.fecha.compareTo(a.fecha),
    );

    cargasCombustible.sort(
      (a, b) => b.fechaCarga.compareTo(a.fechaCarga),
    );

    mantenimientos.sort((a, b) {
      final fechaA = a.fechaRealizado ?? DateTime.fromMillisecondsSinceEpoch(0);
      final fechaB = b.fechaRealizado ?? DateTime.fromMillisecondsSinceEpoch(0);
      return fechaB.compareTo(fechaA);
    });

    return ReporteModel(
      fechaInicio: inicio,
      fechaFin: fechaFin,
      vehiculos: vehiculos,
      registrosKilometraje: registrosKilometraje,
      cargasCombustible: cargasCombustible,
      cargasCombustibleAnteriores: cargasCombustibleAnteriores,
      mantenimientos: mantenimientos,
    );
  }
}