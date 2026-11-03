import 'package:cloud_firestore/cloud_firestore.dart';

class CombustibleModel {
  // Identificador único del documento de la carga.
  final String uid;

  // Identificador del vehículo que recibió la carga.
  final String vehiculoUid;

  // RPE del usuario que registró la carga.
  final String rpeUsuario;

  // Fecha y hora en que se realizó la carga.
  final DateTime fechaCarga;

  // Cantidad de combustible cargada, expresada en litros.
  final double litros;

  // Tipo de combustible utilizado.
  final String tipoCombustible;

  // Kilometraje del vehículo al momento de la carga.
  final int kilometraje;

  // Importe pagado por la carga.
  final double importe;

  // Observaciones adicionales de la carga.
  final String observaciones;

  // Crea un modelo con los datos de una carga de combustible.
  // Entradas: identificadores, fecha, litros, tipo, kilometraje e importe;
  // observaciones es opcional y por defecto es una cadena vacía.
  // Salida: una instancia inmutable de CombustibleModel.
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

  // Crea un modelo a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de CombustibleModel con los valores convertidos.
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

  // Convierte el modelo en un mapa compatible con Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los campos de la carga y la fecha como Timestamp.
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

  // Crea una copia del modelo y reemplaza solo los valores proporcionados.
  // Entradas: campos opcionales que se desean modificar.
  // Salida: una nueva instancia de CombustibleModel con los cambios aplicados.
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

  // Convierte un valor dinámico en texto sin espacios al inicio o al final.
  // Entrada: valor recibido desde el mapa de Firestore.
  // Salida: texto limpio o una cadena vacía si el valor es nulo.
  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  // Convierte un valor dinámico en número decimal.
  // Entrada: valor numérico o texto que represente un decimal.
  // Salida: valor convertido a double; devuelve 0 si no se puede convertir.
  static double _decimal(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte un valor dinámico en número entero.
  // Entrada: valor numérico o texto que represente un entero.
  // Salida: valor convertido a int; devuelve 0 si no se puede convertir.
  static int _entero(dynamic valor) {
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte un valor admitido en una fecha.
  // Entrada: valor Timestamp, DateTime o texto con formato de fecha válido.
  // Salida: fecha convertida; usa la fecha y hora actuales si falla la conversión.
  static DateTime _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor?.toString() ?? '') ?? DateTime.now();
  }
}