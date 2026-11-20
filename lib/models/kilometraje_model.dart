
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo que organiza los datos de una jornada de kilometraje.
class KilometrajeModel {
  final String uid;
  final String vehiculoUid;
  final String rpeUsuario;

  // Fecha y hora de inicio de la jornada.
  final DateTime fecha;

  // Fecha y hora de finalización.
  final DateTime? fechaFin;

  // Lectura inicial del kilometraje.
  final int kilometrajeIni;

  // Lectura final. Es null mientras la jornada esté pendiente.
  final int? kilometrajeFinal;

  final String observaciones;

  const KilometrajeModel({
    required this.uid,
    required this.vehiculoUid,
    required this.rpeUsuario,
    required this.fecha,
    required this.kilometrajeIni,
    this.kilometrajeFinal,
    this.fechaFin,
    this.observaciones = '',
  });

  // Indica si la jornada todavía no ha finalizado.
  bool get estaPendiente => kilometrajeFinal == null;

  // Calcula los kilómetros recorridos.
  int get distanciaRecorrida {
    if (kilometrajeFinal == null) return 0;
    return kilometrajeFinal! - kilometrajeIni;
  }

  factory KilometrajeModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return KilometrajeModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
      fecha: _convertirFecha(map['fecha']),
      fechaFin: map['fechaFin'] == null
          ? null
          : _convertirFecha(map['fechaFin']),
      kilometrajeIni: _convertirEntero(map['kilometrajeIni']),
      kilometrajeFinal: _convertirEnteroNullable(
        map['kilometrajeFinal'],
      ),
      observaciones: _texto(map['observaciones']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'rpeUsuario': rpeUsuario.trim(),
      'fecha': Timestamp.fromDate(fecha),
      'fechaFin': fechaFin == null
          ? null
          : Timestamp.fromDate(fechaFin!),
      'kilometrajeIni': kilometrajeIni,
      'kilometrajeFinal': kilometrajeFinal,
      'observaciones': observaciones.trim(),
    };
  }

  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  static int _convertirEntero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static int? _convertirEnteroNullable(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor.toString());
  }

  static DateTime _convertirFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor?.toString() ?? '') ?? DateTime.now();
  }
}
