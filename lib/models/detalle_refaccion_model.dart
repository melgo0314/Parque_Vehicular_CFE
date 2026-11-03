class DetalleRefaccionModel {
  // Identificador único del detalle de refacción.
  final String uid;

  // Identificador del mantenimiento al que pertenece la refacción.
  final String mantenimientoUid;

  // Nombre de la refacción.
  final String nombre;

  // Cantidad de unidades utilizadas.
  final int cantidad;

  // Crea un detalle de refacción con los datos indicados.
  // Entradas: uid y mantenimientoUid opcionales; nombre y cantidad obligatorios.
  // Salida: una instancia inmutable de DetalleRefaccionModel.
  const DetalleRefaccionModel({
    this.uid = '',
    this.mantenimientoUid = '',
    required this.nombre,
    required this.cantidad,
  });

  // Devuelve el nombre de la refacción usando el alias del diagrama y Firestore.
  // Entrada: ninguna; utiliza el campo nombre de esta instancia.
  // Salida: el nombre de la refacción.
  String get nombreRefaccion => nombre;

  // Crea un modelo a partir de los datos de un mapa.
  // Entradas: map con los campos de la refacción y uid opcional del documento.
  // Salida: una instancia de DetalleRefaccionModel con los valores convertidos.
  factory DetalleRefaccionModel.fromMap(
    Map<String, dynamic> map, {
    String uid = '',
  }) {
    return DetalleRefaccionModel(
      uid: map['uid']?.toString() ?? uid,
      mantenimientoUid: map['mantenimientoUid']?.toString() ?? '',
      nombre: (map['nombreRefaccion'] ?? map['nombre'] ?? '')
          .toString()
          .trim(),
      cantidad: _convertirEntero(map['cantidad']),
    );
  }

  // Convierte el modelo en un mapa con los nombres de campo usados en Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los datos del mantenimiento, la refacción y su cantidad.
  Map<String, dynamic> toMap() {
    return {
      'mantenimientoUid': mantenimientoUid,
      'nombreRefaccion': nombre.trim(),
      'cantidad': cantidad,
    };
  }

  // Convierte un valor dinámico en número entero.
  // Entrada: valor numérico o texto que represente un entero.
  // Salida: valor convertido a int; devuelve 0 si no se puede convertir.
  static int _convertirEntero(dynamic valor) {
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }
}