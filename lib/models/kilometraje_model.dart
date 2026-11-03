import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo que organiza los datos de un registro de kilometraje.
class KilometrajeModel {
  // Identificador único del registro.
  final String uid;

  // Identificador del vehículo al que pertenece el registro.
  final String vehiculoUid;

  // RPE del usuario que registró el kilometraje.
  final String rpeUsuario;

  // Fecha en que se registró el kilometraje.
  final DateTime fecha;

  // Lectura inicial del kilometraje.
  final int kilometrajeIni;

  // Lectura final del kilometraje.
  final int kilometrajeFinal;

  // Observaciones adicionales del registro.
  final String observaciones;

  // Crea un registro con los datos de kilometraje indicados.
  // Entradas: identificadores, fecha y lecturas inicial y final obligatorios;
  // observaciones es opcional y por defecto es una cadena vacía.
  // Salida: una instancia inmutable de KilometrajeModel.
  const KilometrajeModel({
    required this.uid,
    required this.vehiculoUid,
    required this.rpeUsuario,
    required this.fecha,
    required this.kilometrajeIni,
    required this.kilometrajeFinal,
    this.observaciones = '',
  });

  // Crea un modelo a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de KilometrajeModel con los valores convertidos.
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

  // Convierte el modelo en un mapa compatible con Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los datos del registro y la fecha como Timestamp.
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

  // Convierte un valor dinámico en texto sin espacios al inicio o al final.
  // Entrada: valor recibido desde el mapa de Firestore.
  // Salida: texto limpio o una cadena vacía si el valor es nulo.
  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  // Convierte un valor dinámico en número entero.
  // Entrada: valor numérico o texto que represente un entero.
  // Salida: valor convertido a int; devuelve 0 si no se puede convertir.
  static int _convertirEntero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte un valor admitido en una fecha.
  // Entrada: valor Timestamp, DateTime o texto con formato de fecha válido.
  // Salida: fecha convertida; usa la fecha y hora actuales si falla la conversión.
  static DateTime _convertirFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor?.toString() ?? '') ?? DateTime.now();
  }
}