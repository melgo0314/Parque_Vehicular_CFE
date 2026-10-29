class VehiculoModel {
  final String uid;
  final String placas;
  final String numeroEconomico;
  final String marca;
  final String modelo;
  final int anio;
  final String estado;
  final String estadoOperativo;
  final int kilometrajeActual;
  final int intervaloPreventivoKm;
  final String operadorUidActual;

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
    this.intervaloPreventivoKm = 5000,
    this.operadorUidActual = '',
  });

  bool get estaActivo => estado.trim().toLowerCase() == 'activo';

  bool get tieneOperadorAsignado => operadorUidActual.trim().isNotEmpty;

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
      intervaloPreventivoKm: _entero(
        map['intervaloPreventivoKm'],
        valorPredeterminado: 5000,
      ),
      operadorUidActual: _texto(
        map['operadorUidActual'] ?? map['operadorUid'],
      ),
    );
  }

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
      'intervaloPreventivoKm': intervaloPreventivoKm,
    };
  }

  VehiculoModel copyWith({
    String? placas,
    String? numeroEconomico,
    String? marca,
    String? modelo,
    int? anio,
    String? estado,
    String? estadoOperativo,
    int? kilometrajeActual,
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
      intervaloPreventivoKm:
          intervaloPreventivoKm ?? this.intervaloPreventivoKm,
      operadorUidActual: operadorUidActual ?? this.operadorUidActual,
    );
  }

  static String _texto(
    dynamic valor, {
    String valorPredeterminado = '',
  }) {
    if (valor == null) return valorPredeterminado;
    return valor.toString().trim();
  }

  static int _entero(
    dynamic valor, {
    int valorPredeterminado = 0,
  }) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ?? valorPredeterminado;
  }
}