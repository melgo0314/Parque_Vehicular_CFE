import 'package:cloud_firestore/cloud_firestore.dart';

class MantenimientoModel {
  final String uid;
  final String vehiculoUid;
  final String rpeUsuario;

  // Valores esperados:
  // tipoMantenimiento: preventivo, correctivo o prueba
  // modulo: mecanico, hidraulico o laboratorio_pemp
  final String tipoMantenimiento;
  final String modulo;

  final DateTime? fechaProgramada;
  final DateTime fechaRealizado;

  final int? kilometraje;
  final int? kilometrajeProgramado;
  final double? horometroHoras;

  final String trabajoRealizado;
  final String piezasUtilizadas;
  final double costo;
  final String proveedor;
  final String observaciones;

  // Datos opcionales para control de llantas.
  final DateTime? fechaCaducidadLlanta;
  final int? vidaUtilLlantaKm;
  final double? desgasteLlantaPorcentaje;

  // Dato opcional para pruebas PEMP.
  final String categoriaPemp;

  const MantenimientoModel({
    required this.uid,
    required this.vehiculoUid,
    required this.rpeUsuario,
    required this.tipoMantenimiento,
    required this.modulo,
    required this.fechaRealizado,
    required this.trabajoRealizado,
    this.fechaProgramada,
    this.kilometraje,
    this.kilometrajeProgramado,
    this.horometroHoras,
    this.piezasUtilizadas = '',
    this.costo = 0,
    this.proveedor = '',
    this.observaciones = '',
    this.fechaCaducidadLlanta,
    this.vidaUtilLlantaKm,
    this.desgasteLlantaPorcentaje,
    this.categoriaPemp = '',
  });

  // Convierte un documento de Firestore en un objeto del modelo.
  factory MantenimientoModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return MantenimientoModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
      tipoMantenimiento: _texto(map['tipoMantenimiento']),
      modulo: _texto(map['modulo']),
      fechaProgramada: _convertirFecha(map['fechaProgramada']),
      fechaRealizado:
          _convertirFecha(map['fechaRealizado']) ?? DateTime.now(),
      kilometraje: _convertirEnteroOpcional(map['kilometraje']),
      kilometrajeProgramado:
          _convertirEnteroOpcional(map['kilometrajeProgramado']),
      horometroHoras: _convertirDecimalOpcional(map['horometroHoras']),
      trabajoRealizado: _texto(map['trabajoRealizado']),
      piezasUtilizadas: _texto(map['piezasUtilizadas']),
      costo: _convertirDecimal(map['costo']),
      proveedor: _texto(map['proveedor']),
      observaciones: _texto(map['observaciones']),
      fechaCaducidadLlanta:
          _convertirFecha(map['fechaCaducidadLlanta']),
      vidaUtilLlantaKm:
          _convertirEnteroOpcional(map['vidaUtilLlantaKm']),
      desgasteLlantaPorcentaje:
          _convertirDecimalOpcional(map['desgasteLlantaPorcentaje']),
      categoriaPemp: _texto(map['categoriaPemp']),
    );
  }

  // Prepara los datos para guardarlos en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'rpeUsuario': rpeUsuario.trim(),
      'tipoMantenimiento': tipoMantenimiento.trim(),
      'modulo': modulo.trim(),
      'fechaProgramada': fechaProgramada == null
          ? null
          : Timestamp.fromDate(fechaProgramada!),
      'fechaRealizado': Timestamp.fromDate(fechaRealizado),
      'kilometraje': kilometraje,
      'kilometrajeProgramado': kilometrajeProgramado,
      'horometroHoras': horometroHoras,
      'trabajoRealizado': trabajoRealizado.trim(),
      'piezasUtilizadas': piezasUtilizadas.trim(),
      'costo': costo,
      'proveedor': proveedor.trim(),
      'observaciones': observaciones.trim(),
      'fechaCaducidadLlanta': fechaCaducidadLlanta == null
          ? null
          : Timestamp.fromDate(fechaCaducidadLlanta!),
      'vidaUtilLlantaKm': vidaUtilLlantaKm,
      'desgasteLlantaPorcentaje': desgasteLlantaPorcentaje,
      'categoriaPemp': categoriaPemp.trim(),
    };
  }

  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  static int? _convertirEnteroOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor.toString());
  }

  static double _convertirDecimal(dynamic valor) {
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static double? _convertirDecimalOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor.toString());
  }

  static DateTime? _convertirFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    if (valor is String) {
      return DateTime.tryParse(valor);
    }

    return null;
  }
}