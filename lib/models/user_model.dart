class UserModel {
  final String uid;
  final String nombre;
  final String apellidoP;
  final String apellidoM;
  final String correo;
  final String rol;
  final String rpe;
  final String telefono;
  final String urlLicencia;

  const UserModel({
    required this.uid,
    required this.nombre,
    required this.apellidoP,
    required this.apellidoM,
    required this.correo,
    required this.rol,
    required this.rpe,
    required this.telefono,
    this.urlLicencia = '',
  });

  String get nombreCompleto =>
      '$nombre $apellidoP $apellidoM'.trim();

  factory UserModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return UserModel(
      uid: documentId,
      nombre: _stringValue(map['nombre']),
      apellidoP: _stringValue(map['apellidoP']),
      apellidoM: _stringValue(map['apellidoM']),
      correo: _stringValue(map['correo']),
      rol: _stringValue(map['rol'], fallback: 'operador'),
      rpe: _stringValue(map['rpe']),
      telefono: _stringValue(map['telefono']),
      urlLicencia: _stringValue(map['urlLicencia']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre.trim(),
      'apellidoP': apellidoP.trim(),
      'apellidoM': apellidoM.trim(),
      'correo': correo.trim().toLowerCase(),
      'rol': rol.trim().toLowerCase(),
      'rpe': rpe.trim(),
      'telefono': telefono.trim(),
      'urlLicencia': urlLicencia.trim(),
    };
  }

  UserModel copyWith({
    String? nombre,
    String? apellidoP,
    String? apellidoM,
    String? correo,
    String? rol,
    String? rpe,
    String? telefono,
    String? urlLicencia,
  }) {
    return UserModel(
      uid: uid,
      nombre: nombre ?? this.nombre,
      apellidoP: apellidoP ?? this.apellidoP,
      apellidoM: apellidoM ?? this.apellidoM,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      rpe: rpe ?? this.rpe,
      telefono: telefono ?? this.telefono,
      urlLicencia: urlLicencia ?? this.urlLicencia,
    );
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;
    return value.toString().trim();
  }
}