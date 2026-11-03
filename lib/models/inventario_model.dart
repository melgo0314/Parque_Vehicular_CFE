import 'package:cloud_firestore/cloud_firestore.dart';

class InventarioModel {
  // Identificador único del registro de inventario.
  final String uid;

  // Identificador del vehículo asociado al registro.
  final String vehiculoUid;

  // Identificador del artículo registrado.
  final String articuloUid;

  // Cantidad del artículo registrada para el vehículo.
  final int cantidad;

  // Estado actual del artículo.
  final String estado;

  // Observaciones relacionadas con el registro.
  final String observaciones;

  // Identificador del usuario que actualizó el registro.
  final String usuarioUid;

  // RPE del usuario que actualizó el registro.
  final String rpeUsuario;

  // Fecha de la última actualización del registro.
  final DateTime actualizadoEn;

  // Indica si el artículo existe en el inventario del vehículo.
  final bool existe;

  // Crea un registro de inventario con todos sus datos.
  // Entradas: identificadores, cantidad, estado, observaciones, usuario,
  // fecha de actualización y existencia del artículo.
  // Salida: una instancia inmutable de InventarioModel.
  const InventarioModel({
    required this.uid,
    required this.vehiculoUid,
    required this.articuloUid,
    required this.cantidad,
    required this.estado,
    required this.observaciones,
    required this.usuarioUid,
    required this.rpeUsuario,
    required this.actualizadoEn,
    required this.existe,
  });

  // Crea un modelo a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de InventarioModel con los valores convertidos.
  factory InventarioModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return InventarioModel(
      uid: documentId,
      vehiculoUid: map['vehiculoUid']?.toString() ?? '',
      articuloUid: map['articuloUid']?.toString() ?? '',
      cantidad: _entero(map['cantidad']),
      estado: map['estado']?.toString() ?? 'bueno',
      observaciones: map['observaciones']?.toString() ?? '',
      usuarioUid: map['usuarioUid']?.toString() ?? '',
      rpeUsuario: map['rpeUsuario']?.toString() ?? '',
      actualizadoEn: _fecha(map['actualizadoEn']),
      existe: map['existe'] == true,
    );
  }

  // Convierte el modelo en un mapa compatible con Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los datos del registro normalizados.
  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid.trim(),
      'articuloUid': articuloUid.trim(),
      'cantidad': cantidad,
      'estado': estado.trim().toLowerCase(),
      'observaciones': observaciones.trim(),
      'usuarioUid': usuarioUid.trim(),
      'rpeUsuario': rpeUsuario.trim(),
      'actualizadoEn': Timestamp.fromDate(actualizadoEn),
      'existe': existe,
    };
  }

  // Convierte un valor dinámico en número entero.
  // Entrada: valor numérico o texto que represente un entero.
  // Salida: valor convertido a int; devuelve 0 si no se puede convertir.
  static int _entero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte un valor admitido en fecha.
  // Entrada: valor Timestamp o DateTime.
  // Salida: fecha convertida; usa la fecha y hora actuales si no es reconocida.
  static DateTime _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return DateTime.now();
  }
}