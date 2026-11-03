import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_refaccion_model.dart';

class MantenimientoModel {
  // Identificador único del mantenimiento.
  final String uid;

  // Identificador del vehículo relacionado con el mantenimiento.
  final String vehiculoUid;

  // Identificador del usuario que registró el mantenimiento.
  final String usuarioUid;

  // RPE del usuario que registró el mantenimiento.
  final String rpeUsuario;

  // Tipo de mantenimiento: preventivo, correctivo o prueba.
  final String tipoMantenimiento;

  // Módulo relacionado: mecanico, hidraulico o laboratorio_pemp.
  final String modulo;

  // Fecha programada para el mantenimiento, si existe.
  final DateTime? fechaProgramada;

  // Fecha en que se realizó el servicio o la prueba PEMP.
  final DateTime fechaRealizado;

  // Kilometraje previsto para realizar el mantenimiento, si aplica.
  final int? kilometrajeProgramado;

  // Kilometraje del vehículo cuando se realizó el mantenimiento, si aplica.
  final int? kilometrajeRealizado;

  // Lectura del horómetro, si aplica.
  final double? horometro;

  // Descripción del trabajo realizado.
  final String trabajoRealizado;

  // Refacciones asociadas, usadas en memoria, formularios y vistas.
  // El repositorio guarda cada refacción en la colección detalleRefaccion.
  final List<DetalleRefaccionModel> detalleRefacciones;

  // Costo total del mantenimiento.
  final double costo;

  // Proveedor que realizó el trabajo o servicio.
  final String proveedor;

  // Observaciones generales del mantenimiento.
  final String observaciones;

  // Fecha de caducidad de las llantas, si aplica.
  final DateTime? fechaCaducidadLlantas;

  // Vida útil de las llantas, si aplica.
  final double? vidaUtilLlantas;

  // Nivel de desgaste de las llantas, si aplica.
  final double? nivelDesgasteLlantas;

  // Fecha de la prueba PEMP, si aplica.
  final DateTime? fechaPrueba;

  // Categoría de la prueba PEMP.
  final String categoriaPrueba;

  // Observaciones específicas de la prueba PEMP.
  final String observacionesPrueba;

  // Crea un mantenimiento con sus datos obligatorios y opcionales.
  // Entradas: identificadores, tipo, módulo, fecha realizada, trabajo,
  // refacciones, costo, proveedor y observaciones; los demás campos son opcionales.
  // Salida: una instancia inmutable de MantenimientoModel.
  const MantenimientoModel({
    required this.uid,
    required this.vehiculoUid,
    required this.usuarioUid,
    required this.rpeUsuario,
    required this.tipoMantenimiento,
    required this.modulo,
    required this.fechaRealizado,
    required this.trabajoRealizado,
    required this.detalleRefacciones,
    required this.costo,
    required this.proveedor,
    required this.observaciones,
    this.fechaProgramada,
    this.kilometrajeProgramado,
    this.kilometrajeRealizado,
    this.horometro,
    this.fechaCaducidadLlantas,
    this.vidaUtilLlantas,
    this.nivelDesgasteLlantas,
    this.fechaPrueba,
    this.categoriaPrueba = '',
    this.observacionesPrueba = '',
  });

  // Crea un modelo a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de MantenimientoModel con los valores convertidos.
  factory MantenimientoModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    // El repositorio agrega las refacciones consultadas en la colección correspondiente.
    final lista = map['detalleRefacciones'] as List<dynamic>? ?? [];

    return MantenimientoModel(
      uid: documentId,
      vehiculoUid: _texto(map['vehiculoUid']),
      usuarioUid: _texto(map['usuarioUid']),
      rpeUsuario: _texto(map['rpeUsuario']),
      tipoMantenimiento: _texto(map['tipoMantenimiento']),
      modulo: _texto(map['modulo']),
      fechaProgramada: _fechaOpcional(map['fechaProgramada']),
      fechaRealizado: _fecha(map['fechaRealizado']),
      kilometrajeProgramado: _enteroOpcional(map['kilometrajeProgramado']),
      kilometrajeRealizado: _enteroOpcional(map['kilometrajeRealizado']),
      horometro: _decimalOpcional(map['horometro']),
      trabajoRealizado: _texto(map['trabajoRealizado']),
      detalleRefacciones: lista.map((elemento) {
        return DetalleRefaccionModel.fromMap(
          Map<String, dynamic>.from(elemento as Map),
        );
      }).toList(),
      costo: _decimal(map['costo']),
      proveedor: _texto(map['proveedor']),
      observaciones: _texto(map['observaciones']),
      fechaCaducidadLlantas: _fechaOpcional(map['fechaCaducidadLlantas']),
      vidaUtilLlantas: _decimalOpcional(map['vidaUtilLlantas']),
      nivelDesgasteLlantas: _decimalOpcional(map['nivelDesgasteLlantas']),
      fechaPrueba: _fechaOpcional(map['fechaPrueba']),
      categoriaPrueba: _texto(map['categoriaPrueba']),
      observacionesPrueba: _texto(map['observacionesPrueba']),
    );
  }

  // Convierte el modelo en un mapa compatible con Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los datos del mantenimiento y las fechas convertidas.
  Map<String, dynamic> toMap() {
    return {
      'vehiculoUid': vehiculoUid,
      'usuarioUid': usuarioUid,
      'rpeUsuario': rpeUsuario.trim(),
      'tipoMantenimiento': tipoMantenimiento.trim().toLowerCase(),
      'modulo': modulo.trim().toLowerCase(),
      'fechaProgramada': _guardarFecha(fechaProgramada),
      'fechaRealizado': Timestamp.fromDate(fechaRealizado),
      'kilometrajeProgramado': kilometrajeProgramado,
      'kilometrajeRealizado': kilometrajeRealizado,
      'horometro': horometro,
      'trabajoRealizado': trabajoRealizado.trim(),
      'costo': costo,
      'proveedor': proveedor.trim(),
      'observaciones': observaciones.trim(),
      'fechaCaducidadLlantas': _guardarFecha(fechaCaducidadLlantas),
      'vidaUtilLlantas': vidaUtilLlantas,
      'nivelDesgasteLlantas': nivelDesgasteLlantas,
      'fechaPrueba': _guardarFecha(fechaPrueba),
      'categoriaPrueba': categoriaPrueba.trim(),
      'observacionesPrueba': observacionesPrueba.trim(),

      // No se incluyen las refacciones en este mapa.
      // El repositorio guarda cada refacción como un documento independiente.
    };
  }

  // Convierte un valor dinámico en texto sin espacios al inicio o al final.
  // Entrada: valor recibido desde el mapa de Firestore.
  // Salida: texto limpio o una cadena vacía si el valor es nulo.
  static String _texto(dynamic valor) {
    return valor?.toString().trim() ?? '';
  }

  // Convierte un valor dinámico en número entero opcional.
  // Entrada: valor numérico, texto con un entero o null.
  // Salida: entero convertido o null si el valor no se puede convertir.
  static int? _enteroOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }

  // Convierte un valor dinámico en número decimal.
  // Entrada: valor numérico o texto que represente un decimal.
  // Salida: decimal convertido; devuelve 0 si no se puede convertir.
  static double _decimal(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte un valor dinámico en número decimal opcional.
  // Entrada: valor numérico, texto con un decimal o null.
  // Salida: decimal convertido o null si el valor no se puede convertir.
  static double? _decimalOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  // Convierte un valor admitido en una fecha obligatoria.
  // Entrada: valor Timestamp, DateTime o texto con formato de fecha válido.
  // Salida: fecha convertida; usa la fecha y hora actuales si falla la conversión.
  static DateTime _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor?.toString() ?? '') ?? DateTime.now();
  }

  // Convierte un valor admitido en una fecha opcional.
  // Entrada: valor Timestamp, DateTime, texto con fecha válida o null.
  // Salida: fecha convertida o null si no se puede convertir.
  static DateTime? _fechaOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;

    return DateTime.tryParse(valor.toString());
  }

  // Convierte una fecha opcional al formato utilizado por Firestore.
  // Entrada: fecha que puede ser DateTime o null.
  // Salida: Timestamp si hay fecha; de lo contrario, null.
  static dynamic _guardarFecha(DateTime? fecha) {
    if (fecha == null) return null;
    return Timestamp.fromDate(fecha);
  }
}