class ArticuloModel {
  // Identificador único del artículo.
  final String uid;

  // Nombre descriptivo del artículo.
  final String nombre;

  // Categoría a la que pertenece el artículo.
  final String categoria;

  // Indica si el artículo está activo en el inventario.
  final bool activo;

  // Crea un artículo con sus datos requeridos y su estado.
  // Entradas: uid, nombre y categoria obligatorios; activo es opcional
  // y por defecto tiene el valor true.
  // Salida: una instancia inmutable de ArticuloModel.
  const ArticuloModel({
    required this.uid,
    required this.nombre,
    required this.categoria,
    this.activo = true,
  });

  // Crea un artículo a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de ArticuloModel con los valores del mapa.
  factory ArticuloModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ArticuloModel(
      uid: documentId,
      nombre: map['nombre']?.toString() ?? '',
      categoria: map['categoria']?.toString() ?? '',
      activo: map['activo'] ?? true,
    );
  }

  // Convierte el artículo en un mapa para guardarlo en Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con el nombre, la categoría y el estado del artículo.
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre.trim(),
      'categoria': categoria.trim(),
      'activo': activo,
    };
  }
}