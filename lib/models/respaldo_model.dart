
class RespaldoModel {
  final String identificador;
  final DateTime? fechaInicio;
  final DateTime? fechaFinalizacion;
  final String estado;
  final String proyecto;
  final String bucket;
  final int cantidadArchivosStorage;
  final int cantidadUsuarios;
  final String error;
  final String tipo;

  RespaldoModel({
    required this.identificador,
    this.fechaInicio,
    this.fechaFinalizacion,
    this.estado = '',
    this.proyecto = '',
    this.bucket = '',
    this.cantidadArchivosStorage = 0,
    this.cantidadUsuarios = 0,
    this.error = '',
    this.tipo = '',
  });

  // Convierte una fecha recibida desde Firebase.
  static DateTime? _convertirFecha(dynamic valor) {
    if (valor == null) return null;

    if (valor is DateTime) {
      return valor;
    }

    if (valor is String) {
      return DateTime.tryParse(valor);
    }

    // Permite recibir fechas como milisegundos.
    if (valor is int) {
      return DateTime.fromMillisecondsSinceEpoch(valor);
    }

    // Permite recibir Timestamp de Cloud Firestore.
    try {
      return valor.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  // Convierte los datos de Firestore al modelo.
  factory RespaldoModel.fromMap(
    String identificador,
    Map<String, dynamic> datos,
  ) {
    return RespaldoModel(
      identificador: identificador,
      fechaInicio: _convertirFecha(datos['fechaInicio']),
      fechaFinalizacion:
          _convertirFecha(datos['fechaFinalizacion']),
      estado: datos['estado']?.toString() ?? '',
      proyecto: datos['proyecto']?.toString() ?? '',
      bucket: datos['bucket']?.toString() ?? '',
      cantidadArchivosStorage:
          (datos['cantidadArchivosStorage'] as num?)?.toInt() ?? 0,
      cantidadUsuarios:
          (datos['cantidadUsuarios'] as num?)?.toInt() ?? 0,
      error: datos['error']?.toString() ?? '',
      tipo: datos['tipo']?.toString() ?? '',
    );
  }

  // Convierte la fecha a un formato legible.
  String get fechaFormateada {
    final fecha = fechaInicio;

    if (fecha == null) {
      return 'Fecha no disponible';
    }

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio - $hora:$minuto';
  }

  // Indica si el respaldo terminó correctamente.
  bool get estaCompletado {
    return estado.toLowerCase() == 'completado';
  }
}
