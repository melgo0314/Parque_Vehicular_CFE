import 'package:cloud_firestore/cloud_firestore.dart';

class AsignacionModel {
  /// Identificador único del documento de asignación.
  final String uid;
  // Identificador único del vehículo asignado.
  final String vehiculoUid;
  // Identificador único del operador asignado.
  final String operadorUid;
  // Identificador único del administrador que creó la asignación.
  final String administradorUid;
  // Nombre visible del operador.
  final String operadorNombre;
  // Placas del vehículo.
  final String vehiculoPlacas;
  // Número económico del vehículo.
  final String vehiculoNumeroEconomico;
  // Tipo o categoría del vehículo.
  final String vehiculoTipo;
  // Fecha en que inicia la asignación.
  final DateTime fechaInicio;
  // Fecha de término; es nula si la asignación no tiene fecha de cierre.
  final DateTime? fechaFin;
  // Tipo de asignación: permanente o temporal.
  final String tipo;
  // Motivo de la asignación temporal, si aplica.
  final String motivoTemporal;
  // Estado actual de la asignación.
  final String estado;

  // Crea una asignación con sus datos obligatorios y valores predeterminados
  // Entradas: identificadores, datos del operador y vehículo, fecha de inicio
  // y, fecha de fin, tipo, motivo y estado.
  // Salida: una instancia de AsignacionModel.
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

  // Indica si la asignación todavía no está finalizada.
  // Entrada: ninguna; consulta el campo [estado] de esta instancia.
  // Salida: `true` si el estado no es `finalizada`; de lo contrario `false`.
  bool get estaActiva => estado.trim().toLowerCase() != 'finalizada';

  // Indica si el tipo de asignación es temporal.
  // Entrada: ninguna; consulta el campo [tipo] de esta instancia.
  // Salida: `true` cuando el tipo normalizado es `temporal`.
  bool get esTemporal => tipo.trim().toLowerCase() == 'temporal';

  // Construye una asignación con los datos de un documento de Firestore.
  // Entradas: [map], mapa de campos del documento, y [documentId], su ID.
  // Salida: una instancia con fechas, tipo y estado convertidos y normalizados.
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

  // Convierte la asignación en campos compatibles con Firestore.
  // Entrada: ninguna; usa los valores de esta instancia.
  // Salida: mapa con fechas como [Timestamp] y textos normalizados.
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

  // Crea una copia con los cambios indicados y conserva los demás valores.
  // Entradas: campos opcionales que se desean actualizar; [limpiarFechaFin]
  // permite borrar explícitamente la fecha de fin.
  // Salida: una nueva instancia de [AsignacionModel] con los cambios aplicados.
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

  // Convierte un valor dinámico en texto sin espacios al inicio o al final.
  // Entrada: [valor], cualquier valor recibido desde el mapa de Firestore.
  // Salida: el valor como texto limpio, o una cadena vacía si es nulo.
  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  // Convierte un valor admitido en una fecha.
  // Entrada: [valor], que puede ser [Timestamp], [DateTime] o texto parseable.
  // Salida: la fecha convertida, o `null` si el valor no es válido.
  static DateTime? _convertirFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  // Normaliza el estado usando el estado recibido y la fecha de fin.
  // Entradas: [valor] estado guardado, [tipo] de asignación opcional y
  // [fechaFin] convertida. Salida: `finalizada`, `temporal` o `vigente`.
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

  // Normaliza el tipo de asignación.
  // Entradas: [valor] tipo guardado y [estado] ya normalizado.
  // Salida: `temporal` si alguno indica temporalidad; en otro caso `permanente`.
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