import 'package:cloud_firestore/cloud_firestore.dart';

class CombustibleModel {
  final String uid;
  final String vehiculoUid;
  final String rpeUsuario;
  final DateTime fechaCarga;
  final double litros;
  final String tipoCombustible;
  final int kilometraje;
  final double importe;
  final String observaciones;

  const CombustibleModel({
    required this.uid,
    required this.vehiculoUid,
    required this.rpeUsuario,
    required this.fechaCarga,
    required this.litros,
    required this.tipoCombustible,
    required this.kilometraje,
    required this.importe,
    this.observaciones = '',
  });

  factory CombustibleModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return CombustibleModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
      fechaCarga: _fecha(map['fechaCarga']),
      litros: _decimal(map['litros']),
      tipoCombustible: _texto(map['tipoCombustible']),
      kilometraje: _entero(map['kilometraje']),
      importe: _decimal(map['importe']),
      observaciones: _texto(map['observaciones']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'rpeUsuario': rpeUsuario.trim(),
      'fechaCarga': Timestamp.fromDate(fechaCarga),
      'litros': litros,
      'tipoCombustible': tipoCombustible.trim(),
      'kilometraje': kilometraje,
      'importe': importe,
      'observaciones': observaciones.trim(),
    };
  }

  CombustibleModel copyWith({
    String? vehiculoUid,
    String? rpeUsuario,
    DateTime? fechaCarga,
    double? litros,
    String? tipoCombustible,
    int? kilometraje,
    double? importe,
    String? observaciones,
  }) {
    return CombustibleModel(
      uid: uid,
      vehiculoUid: vehiculoUid ?? this.vehiculoUid,
      rpeUsuario: rpeUsuario ?? this.rpeUsuario,
      fechaCarga: fechaCarga ?? this.fechaCarga,
      litros: litros ?? this.litros,
      tipoCombustible: tipoCombustible ?? this.tipoCombustible,
      kilometraje: kilometraje ?? this.kilometraje,
      importe: importe ?? this.importe,
      observaciones: observaciones ?? this.observaciones,
    );
  }

  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  static double _decimal(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static int _entero(dynamic valor) {
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static DateTime _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor?.toString() ?? '') ?? DateTime.now();
  }
}