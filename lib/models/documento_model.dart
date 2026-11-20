class DocumentoModel {
  final String uid;
  final String nombre;
  final String descripcion;
  final bool activo;

  const DocumentoModel({
    required this.uid,
    required this.nombre,
    required this.descripcion,
    this.activo = true,
  });

  factory DocumentoModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return DocumentoModel(
      uid: documentId,
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      activo: map['activo'] is bool ? map['activo'] as bool : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'activo': activo,
    };
  }
}