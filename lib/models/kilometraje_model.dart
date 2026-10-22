import 'package:cloud_firestore/cloud_firestore.dart';

class KilometrajeModel {
  final String uid;
  final String vehiculoUid;
  final String rpeUsuario;
  final DateTime fecha;
  final int kilometrajeIni;
  final int kilometrajeFinal;
  final String observaciones;

  const KilometrajeModel({
    required this.uid,
    required this.vehiculoUid,
    required this.rpeUsuario,
    required this.fecha,
    required this.kilometrajeIni,
    required this.kilometrajeFinal,
    this.observaciones = '',
  });

  // Convierte un documento de Firestore en un objeto KilometrajeModel.
  factory KilometrajeModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return KilometrajeModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
      fecha: _convertirFecha(map['fecha']),
      kilometrajeIni: _convertirEntero(map['kilometrajeIni']),
      kilometrajeFinal: _convertirEntero(map['kilometrajeFinal']),
      observaciones: _texto(map['observaciones']),
    );
  }

  // Prepara los datos para guardarlos en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'rpeUsuario': rpeUsuario.trim(),
      'fecha': Timestamp.fromDate(fecha),
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

  static DateTime _convertirFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor?.toString() ?? '') ?? DateTime.now();
  }
}