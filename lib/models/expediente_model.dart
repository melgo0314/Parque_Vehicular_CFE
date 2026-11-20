import 'package:cloud_firestore/cloud_firestore.dart';

class ExpedienteModel {
  final String uid;
  final String vehiculoUid;
  final String documentoUid;
  final String nombreArchivo;
  final String archivoUrl;
  final String rutaStorage;
  final String tipoMime;
  final DateTime fechaCarga;
  final DateTime? fechaVencimiento;
  final String observaciones;
  final String usuarioUid;
  final String rpeUsuario;

  const ExpedienteModel({
    required this.uid,
    required this.vehiculoUid,
    required this.documentoUid,
    required this.nombreArchivo,
    required this.archivoUrl,
    required this.rutaStorage,
    required this.tipoMime,
    required this.fechaCarga,
    this.fechaVencimiento,
    this.observaciones = '',
    required this.usuarioUid,
    required this.rpeUsuario,
  });

  factory ExpedienteModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ExpedienteModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      documentoUid: _texto(map['documentoUid']),
      nombreArchivo: _texto(map['nombreArchivo']),
      archivoUrl: _texto(map['archivoUrl']),
      rutaStorage: _texto(map['rutaStorage']),
      tipoMime: _texto(map['tipoMime']),
      fechaCarga: _fecha(map['fechaCarga']) ?? DateTime.now(),
      fechaVencimiento: _fecha(map['fechaVencimiento']),
      observaciones: _texto(map['observaciones']),
      usuarioUid: _texto(map['usuarioUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid.trim(),
      'documentoUid': documentoUid.trim(),
      'nombreArchivo': nombreArchivo.trim(),
      'archivoUrl': archivoUrl.trim(),
      'rutaStorage': rutaStorage.trim(),
      'tipoMime': tipoMime.trim(),
      'fechaCarga': Timestamp.fromDate(fechaCarga),
      'fechaVencimiento': fechaVencimiento == null
          ? null
          : Timestamp.fromDate(fechaVencimiento!),
      'observaciones': observaciones.trim(),
      'usuarioUid': usuarioUid.trim(),
      'rpeUsuario': rpeUsuario.trim(),
    };
  }

  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  static DateTime? _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return null;
  }
}