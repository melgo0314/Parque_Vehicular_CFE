
class VehiculoModel {
  // Identificador único del vehículo.
  final String uid;

  // Placas del vehículo.
  final String placas;

  // Número económico asignado al vehículo.
  final String numeroEconomico;

  // Marca del vehículo.
  final String marca;

  // Modelo del vehículo.
  final String modelo;

  // Año de fabricación del vehículo.
  final int anio;

  // Estado administrativo del vehículo, por ejemplo, activo o inactivo.
  final String estado;

  // Estado operativo del vehículo, por ejemplo, operativo o en taller.
  final String estadoOperativo;

  // Kilometraje actual del vehículo.
  final int kilometrajeActual;

  // Kilometraje base para calcular el primer preventivo cuando no hay historial.
  // Se inicializa una sola vez al comenzar a registrar kilometrajes.
  final int? kilometrajeBasePreventivo;

  // Kilometraje entre servicios preventivos.
  final int intervaloPreventivo;

  // Identificador del operador asignado actualmente.
  final String operadorUidActual;

  // Crea un vehículo con sus datos requeridos y valores predeterminados.
  // Entradas: uid, placas, número económico, marca, modelo y año;
  // los estados, kilometraje, intervalo y operador son opcionales.
  // Salida: una instancia inmutable de VehiculoModel.
  const VehiculoModel({
    required this.uid,
    required this.placas,
    required this.numeroEconomico,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.estado = 'activo',
    this.estadoOperativo = 'operativo',
    this.kilometrajeActual = 0,
    this.kilometrajeBasePreventivo,
    int intervaloPreventivo = 10000,
    int? intervaloPreventivoKm,
    this.operadorUidActual = '',
  }) : intervaloPreventivo =
            intervaloPreventivoKm ?? intervaloPreventivo;

  // Proporciona un alias para mantener compatibilidad con código existente.
  // Entrada: ninguna; consulta el intervalo preventivo de esta instancia.
  // Salida: intervalo de kilometraje entre servicios preventivos.
  int get intervaloPreventivoKm => intervaloPreventivo;

  // Indica si el vehículo está activo.
  // Entrada: ninguna; consulta el campo estado de esta instancia.
  // Salida: true si el estado normalizado es activo; de lo contrario, false.
  bool get estaActivo => estado.trim().toLowerCase() == 'activo';

  // Indica si el vehículo tiene un operador asignado.
  // Entrada: ninguna; consulta el campo operadorUidActual.
  // Salida: true si el identificador del operador no está vacío.
  bool get tieneOperadorAsignado =>
      operadorUidActual.trim().isNotEmpty;

  // Crea un vehículo a partir de los datos de un documento de Firestore.
  // Entradas: map con los campos del documento y documentId con su identificador.
  // Salida: una instancia de VehiculoModel con los valores convertidos.
  factory VehiculoModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return VehiculoModel(
      uid: documentId,
      placas: _texto(map['placas']),
      numeroEconomico: _texto(
        map['numeroEconomico'] ?? map['numeco'],
      ),
      marca: _texto(map['marca']),
      modelo: _texto(map['modelo']),
      anio: _entero(map['anio']),
      estado: _texto(
        map['estado'],
        valorPredeterminado: 'activo',
      ),
      estadoOperativo: _texto(
        map['estadoOperativo'],
        valorPredeterminado: 'operativo',
      ),
      kilometrajeActual: _entero(
        map['kilometrajeActual'] ?? map['kilometraje'],
      ),
      kilometrajeBasePreventivo: map['kilometrajeBasePreventivo'] == null
          ? null
          : _entero(map['kilometrajeBasePreventivo']),
      intervaloPreventivo: _entero(
        map['intervaloPreventivo'] ?? map['intervaloPreventivoKm'],
        valorPredeterminado: 10000,
      ),
      operadorUidActual: _texto(
        map['operadorUidActual'] ?? map['operadorUid'],
      ),
    );
  }

  // Convierte el vehículo en un mapa compatible con Firestore.
  // Entrada: ninguna; utiliza los valores de esta instancia.
  // Salida: mapa con los datos del vehículo normalizados.
  Map<String, dynamic> toMap() {
    return {
      'placas': placas.trim().toUpperCase(),
      'numeroEconomico': numeroEconomico.trim(),
      'marca': marca.trim(),
      'modelo': modelo.trim(),
      'anio': anio,
      'estado': estado.trim().toLowerCase(),
      'estadoOperativo': estadoOperativo.trim().toLowerCase(),
      'kilometrajeActual': kilometrajeActual,
      if (kilometrajeBasePreventivo != null)
        'kilometrajeBasePreventivo': kilometrajeBasePreventivo,
      'intervaloPreventivo': intervaloPreventivo,
      'operadorUidActual': operadorUidActual.trim(),
    };
  }

  // Crea una copia del vehículo y reemplaza solo los valores proporcionados.
  // Entradas: campos opcionales que se desean actualizar; se acepta
  // intervaloPreventivoKm como alias de intervaloPreventivo.
  // Salida: una nueva instancia de VehiculoModel con los cambios aplicados.
  VehiculoModel copyWith({
    String? placas,
    String? numeroEconomico,
    String? marca,
    String? modelo,
    int? anio,
    String? estado,
    String? estadoOperativo,
    int? kilometrajeActual,
    int? kilometrajeBasePreventivo,
    int? intervaloPreventivo,
    int? intervaloPreventivoKm,
    String? operadorUidActual,
  }) {
    return VehiculoModel(
      uid: uid,
      placas: placas ?? this.placas,
      numeroEconomico: numeroEconomico ?? this.numeroEconomico,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      anio: anio ?? this.anio,
      estado: estado ?? this.estado,
      estadoOperativo: estadoOperativo ?? this.estadoOperativo,
      kilometrajeActual: kilometrajeActual ?? this.kilometrajeActual,
      kilometrajeBasePreventivo:
          kilometrajeBasePreventivo ?? this.kilometrajeBasePreventivo,
      intervaloPreventivo:
          intervaloPreventivoKm ??
          intervaloPreventivo ??
          this.intervaloPreventivo,
      operadorUidActual: operadorUidActual ?? this.operadorUidActual,
    );
  }

  // Convierte un valor dinámico en texto sin espacios sobrantes.
  // Entradas: valor recibido y valorPredeterminado opcional para valores nulos.
  // Salida: texto limpio o el valor predeterminado si valor es null.
  static String _texto(
    dynamic valor, {
    String valorPredeterminado = '',
  }) {
    if (valor == null) return valorPredeterminado;
    return valor.toString().trim();
  }

  // Convierte un valor dinámico en número entero.
  // Entradas: valor recibido y valorPredeterminado para datos no convertibles.
  // Salida: valor convertido a int o el valor predeterminado.
  static int _entero(
    dynamic valor, {
    int valorPredeterminado = 0,
  }) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ??
        valorPredeterminado;
  }
}
