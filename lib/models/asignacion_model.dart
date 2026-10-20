import 'package:cloud_firestore/cloud_firestore.dart';

class AsignacionModel {
  final String uid;
  final String vehiculoUid;
  final String operadorUid;
  final String administradorUid;
  final String operadorNombre;
  final String vehiculoPlacas;
  final String vehiculoNumeroEconomico;
  final String vehiculoTipo;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String tipo;
  final String motivoTemporal;
  final String estado;

  const AsignacionModel({
    required this.uid,
    required this.vehiculoUid,
    required this.operadorUid,
    required this.administradorUid,
    required this.operadorNombre,
    required this.vehiculoPlacas,
    required this.vehiculoNumeroEconomico,
    required this.vehiculoTipo,
    required this.fechaInicio,
    this.fechaFin,
    this.tipo = 'permanente',
    this.motivoTemporal = '',
    this.estado = 'vigente',
  });

  bool get estaActiva => estado.trim().toLowerCase() != 'finalizada';

  bool get esTemporal => tipo.trim().toLowerCase() == 'temporal';

  factory AsignacionModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final fechaFin = _convertirFecha(map['fechaFin']);
    final estado = _normalizarEstado(
      map['estado'],
      tipo: map['tipo'],
      fechaFin: fechaFin,
    );
    final tipo = _normalizarTipo(
      map['tipo'],
      estado: estado,
    );

    return AsignacionModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      operadorUid: _texto(map['operadorUid']),
      administradorUid: _texto(map['administradorUid']),
      operadorNombre: _texto(map['operadorNombre']),
      vehiculoPlacas: _texto(map['vehiculoPlacas']).toUpperCase(),
      vehiculoNumeroEconomico: _texto(map['vehiculoNumeroEconomico']),
      vehiculoTipo: _texto(map['vehiculoTipo']),
      fechaInicio: _convertirFecha(map['fechaInicio']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fechaFin: fechaFin,
      tipo: tipo,
      motivoTemporal: _texto(map['motivoTemporal']),
      estado: estado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'operadorUid': operadorUid,
      'administradorUid': administradorUid,
      'operadorNombre': operadorNombre.trim(),
      'vehiculoPlacas': vehiculoPlacas.trim().toUpperCase(),
      'vehiculoNumeroEconomico': vehiculoNumeroEconomico.trim(),
      'vehiculoTipo': vehiculoTipo.trim(),
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': fechaFin == null ? null : Timestamp.fromDate(fechaFin!),
      'tipo': esTemporal ? 'temporal' : 'permanente',
      'motivoTemporal': motivoTemporal.trim(),
      'estado': estado.trim().toLowerCase(),
    };
  }

  AsignacionModel copyWith({
    String? vehiculoUid,
    String? operadorUid,
    String? administradorUid,
    String? operadorNombre,
    String? vehiculoPlacas,
    String? vehiculoNumeroEconomico,
    String? vehiculoTipo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool limpiarFechaFin = false,
    String? tipo,
    String? motivoTemporal,
    String? estado,
  }) {
    final nuevaFechaFin = limpiarFechaFin ? null : fechaFin ?? this.fechaFin;
    final nuevoTipo = tipo ?? this.tipo;
    final nuevoEstado = estado ??
        (nuevaFechaFin == null
            ? (nuevoTipo.toLowerCase() == 'temporal' ? 'temporal' : 'vigente')
            : this.estado);

    return AsignacionModel(
      uid: uid,
      vehiculoUid: vehiculoUid ?? this.vehiculoUid,
      operadorUid: operadorUid ?? this.operadorUid,
      administradorUid: administradorUid ?? this.administradorUid,
      operadorNombre: operadorNombre ?? this.operadorNombre,
      vehiculoPlacas: vehiculoPlacas ?? this.vehiculoPlacas,
      vehiculoNumeroEconomico:
          vehiculoNumeroEconomico ?? this.vehiculoNumeroEconomico,
      vehiculoTipo: vehiculoTipo ?? this.vehiculoTipo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: nuevaFechaFin,
      tipo: nuevoTipo,
      motivoTemporal: motivoTemporal ?? this.motivoTemporal,
      estado: nuevoEstado,
    );
  }

  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  static DateTime? _convertirFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  static String _normalizarEstado(
    dynamic valor, {
    dynamic tipo,
    required DateTime? fechaFin,
  }) {
    final estado = _texto(valor).toLowerCase();
    final tipoNormalizado = _texto(tipo).toLowerCase();

    if (estado == 'finalizada' ||
        estado == 'finalizado' ||
        (fechaFin != null && estado != 'temporal')) {
      return 'finalizada';
    }

    if (estado == 'temporal' || tipoNormalizado == 'temporal') {
      return 'temporal';
    }
    return 'vigente';
  }

  static String _normalizarTipo(
    dynamic valor, {
    required String estado,
  }) {
    final tipo = _texto(valor).toLowerCase();

    if (tipo == 'temporal' || estado == 'temporal') {
      return 'temporal';
    }

    return 'permanente';
  }
}