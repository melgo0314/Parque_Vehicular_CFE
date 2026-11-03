
class UserModel {
  // Identificador único del usuario.
  final String uid;

  // Nombre del usuario.
  final String nombre;

  // Primer apellido del usuario.
  final String apellidoP;

  // Segundo apellido del usuario.
  final String apellidoM;

  // Correo electrónico del usuario.
  final String correo;

  // Rol asignado al usuario en el sistema.
  final String rol;

  // Registro de Personal de la Empresa del usuario.
  final String rpe;

  // Número telefónico del usuario.
  final String telefono;

  // URL del documento de licencia del usuario, si existe.
  final String urlLicencia;

  // Crea un usuario con sus datos personales y de acceso.
  // Entradas: uid, nombre, apellidos, correo, rol, rpe y teléfono;
  // urlLicencia es opcional y por defecto es una cadena vacía.
  // Salida: una instancia inmutable de UserModel.
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

  // Combina el nombre y los apellidos del usuario.
  // Entrada: ninguna; utiliza los campos de esta instancia.
  // Salida: nombre completo sin espacios sobrantes al inicio o al final.
  String get nombreCompleto =>
      '$nombre $apellidoP $apellidoM'.trim();

  // Crea un usuario a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de UserModel con sus valores convertidos.
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

  // Convierte el usuario en un mapa compatible con Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los datos del usuario normalizados.
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

  // Crea una copia del usuario y reemplaza solo los valores proporcionados.
  // Entradas: campos opcionales que se desean actualizar.
  // Salida: una nueva instancia de UserModel con los cambios aplicados.
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

  // Convierte un valor dinámico en texto sin espacios sobrantes.
  // Entradas: value con el valor recibido y fallback opcional para valores nulos.
  // Salida: el valor convertido a texto o el fallback si value es null.
  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;
    return value.toString().trim();
  }
}