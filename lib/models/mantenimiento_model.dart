
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_refaccion_model.dart';

// Modelo que organiza la información de los mantenimientos de un vehículo.
class MantenimientoModel {
  final String uid;
  final String vehiculoUid;
  final String usuarioUid;
  final String rpeUsuario;

  // Tipo de mantenimiento: preventivo, correctivo o prueba.
  final String tipoMantenimiento;

  // Módulo: mecanico, hidraulico o laboratorio_pemp.
  final String modulo;

  // Estado: programado, pendiente o realizado.
  final String estado;

  // Fecha establecida para realizar el mantenimiento.
  final DateTime? fechaProgramada;

  // Fecha en que realmente se realizó el mantenimiento.
  // Es null mientras el mantenimiento no se haya realizado.
  final DateTime? fechaRealizado;

  // Kilometraje establecido para realizar el mantenimiento.
  final int? kilometrajeProgramado;

  // Kilometraje en el que se realizó el mantenimiento.
  final int? kilometrajeRealizado;

  final double? horometro;
  final String trabajoRealizado;
  final List<DetalleRefaccionModel> detalleRefacciones;
  final double costo;
  final String proveedor;
  final String observaciones;

  // Datos de control de llantas.
  final DateTime? fechaCaducidadLlantas;
  final double? vidaUtilLlantas;
  final double? nivelDesgasteLlantas;

  // Datos de pruebas PEMP.
  final DateTime? fechaPrueba;
  final String categoriaPrueba;
  final String observacionesPrueba;

  const MantenimientoModel({
    required this.uid,
    required this.vehiculoUid,
    required this.usuarioUid,
    required this.rpeUsuario,
    required this.tipoMantenimiento,
    required this.modulo,
    this.estado = 'realizado',
    this.fechaProgramada,
    this.fechaRealizado,
    this.kilometrajeProgramado,
    this.kilometrajeRealizado,
    this.horometro,
    this.trabajoRealizado = '',
    this.detalleRefacciones = const [],
    this.costo = 0,
    this.proveedor = '',
    this.observaciones = '',
    this.fechaCaducidadLlantas,
    this.vidaUtilLlantas,
    this.nivelDesgasteLlantas,
    this.fechaPrueba,
    this.categoriaPrueba = '',
    this.observacionesPrueba = '',
  });

  // Indica si el mantenimiento ya fue realizado.
  bool get estaRealizado => estado == 'realizado';

  // Indica si el mantenimiento está programado.
  bool get estaProgramado => estado == 'programado';

  // Indica si el mantenimiento correctivo está pendiente.
  bool get estaPendiente => estado == 'pendiente';

  // Crea un mantenimiento a partir de un documento de Firestore.
  factory MantenimientoModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final fechaRealizado = _fechaOpcional(map['fechaRealizado']);

    // Los documentos anteriores no tenían campo estado.
    // Se consideran realizados si tienen fecha de realización.
    final estadoGuardado = _texto(map['estado']);

    final estadoFinal = estadoGuardado.isNotEmpty
        ? estadoGuardado
        : fechaRealizado != null
            ? 'realizado'
            : 'programado';

    final lista = map['detalleRefacciones'] as List<dynamic>? ?? [];

    return MantenimientoModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      usuarioUid: _texto(map['usuarioUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
      tipoMantenimiento: _texto(map['tipoMantenimiento']),
      modulo: _texto(map['modulo']),
      estado: estadoFinal,
      fechaProgramada: _fechaOpcional(map['fechaProgramada']),
      fechaRealizado: fechaRealizado,
      kilometrajeProgramado: _enteroOpcional(
        map['kilometrajeProgramado'],
      ),
      kilometrajeRealizado: _enteroOpcional(
        map['kilometrajeRealizado'],
      ),
      horometro: _decimalOpcional(map['horometro']),
      trabajoRealizado: _texto(map['trabajoRealizado']),
      detalleRefacciones: lista.map((elemento) {
        return DetalleRefaccionModel.fromMap(
          Map<String, dynamic>.from(elemento as Map),
        );
      }).toList(),
      costo: _decimal(map['costo']),
      proveedor: _texto(map['proveedor']),
      observaciones: _texto(map['observaciones']),
      fechaCaducidadLlantas: _fechaOpcional(
        map['fechaCaducidadLlantas'],
      ),
      vidaUtilLlantas: _decimalOpcional(map['vidaUtilLlantas']),
      nivelDesgasteLlantas: _decimalOpcional(
        map['nivelDesgasteLlantas'],
      ),
      fechaPrueba: _fechaOpcional(map['fechaPrueba']),
      categoriaPrueba: _texto(map['categoriaPrueba']),
      observacionesPrueba: _texto(map['observacionesPrueba']),
    );
  }

  // Convierte el mantenimiento en un mapa compatible con Firestore.
  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'usuarioUid': usuarioUid,
      'rpeUsuario': rpeUsuario.trim(),
      'tipoMantenimiento': tipoMantenimiento.trim().toLowerCase(),
      'modulo': modulo.trim().toLowerCase(),
      'estado': estado.trim().toLowerCase(),
      'fechaProgramada': _guardarFecha(fechaProgramada),
      'fechaRealizado': _guardarFecha(fechaRealizado),
      'kilometrajeProgramado': kilometrajeProgramado,
      'kilometrajeRealizado': kilometrajeRealizado,
      'horometro': horometro,
      'trabajoRealizado': trabajoRealizado.trim(),
      'costo': costo,
      'proveedor': proveedor.trim(),
      'observaciones': observaciones.trim(),
      'fechaCaducidadLlantas': _guardarFecha(
        fechaCaducidadLlantas,
      ),
      'vidaUtilLlantas': vidaUtilLlantas,
      'nivelDesgasteLlantas': nivelDesgasteLlantas,
      'fechaPrueba': _guardarFecha(fechaPrueba),
      'categoriaPrueba': categoriaPrueba.trim(),
      'observacionesPrueba': observacionesPrueba.trim(),

      // Las refacciones se guardan en su colección independiente.
    };
  }

  // Convierte un valor dinámico en texto.
  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  // Convierte un valor dinámico en entero opcional.
  static int? _enteroOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor.toString());
  }

  // Convierte un valor dinámico en decimal.
  static double _decimal(dynamic valor) {
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte un valor dinámico en decimal opcional.
  static double? _decimalOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor.toString());
  }

  // Convierte una fecha de Firestore o texto en DateTime.
  static DateTime? _fechaOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor.toString());
  }

  // Convierte una fecha opcional al formato de Firestore.
  static dynamic _guardarFecha(DateTime? fecha) {
    if (fecha == null) return null;

    return Timestamp.fromDate(fecha);
  }
}
