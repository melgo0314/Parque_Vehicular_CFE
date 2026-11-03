import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehiculos_model.dart';

// Se comunica con Firebase para administrar vehículos.
class VehiculoRepositorie {
  // Crea el repositorio con Firestore o con la instancia predeterminada.
  // Entrada: firestore opcional para proporcionar una conexión personalizada.
  // Salida: una instancia de VehiculoRepositorie configurada.
  VehiculoRepositorie({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // Conexión a Cloud Firestore.
  final FirebaseFirestore _db;

  // Referencia a la colección de vehículos.
  CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _db.collection('vehiculo');

  // Obtiene vehículos en tiempo real y filtra por texto y estado de baja.
  // Entradas: busqueda opcional e incluirBaja para incluir vehículos dados de baja.
  // Salida: un flujo con la lista de vehículos ordenada por placas.
  Stream<List<VehiculoModel>> obtenerVehiculos({
    String busqueda = '',
    bool incluirBaja = false,
  }) {
    return _vehiculos.snapshots().map((consulta) {
      final texto = busqueda.trim().toLowerCase();

      final vehiculos = consulta.docs
          .map(
            (documento) => VehiculoModel.fromMap(
              documento.data(),
              documento.id,
            ),
          )
          .where((vehiculo) {
        final estaDeBaja = vehiculo.estado.toLowerCase() == 'baja';

        if (!incluirBaja && estaDeBaja) {
          return false;
        }

        if (texto.isEmpty) {
          return true;
        }

        final datos = [
          vehiculo.placas,
          vehiculo.numeroEconomico,
          vehiculo.marca,
          vehiculo.modelo,
          vehiculo.anio.toString(),
        ].join(' ').toLowerCase();

        return datos.contains(texto);
      }).toList();

      vehiculos.sort(
        (a, b) => a.placas.toLowerCase().compareTo(b.placas.toLowerCase()),
      );

      return vehiculos;
    });
  }

  // Valida y registra un vehículo con estado activo.
  // Entrada: vehiculo con los datos que se guardarán.
  // Salida: un Future que termina cuando Firestore confirma el registro.
  // Lanza ArgumentError si los datos no son válidos o no son únicos.
  Future<void> registrarVehiculo(VehiculoModel vehiculo) async {
    _validarDatos(vehiculo);

    final placasNormalizadas = _normalizar(vehiculo.placas);
    final numeroNormalizado = _normalizar(vehiculo.numeroEconomico);

    await _validarUnicidad(
      placas: placasNormalizadas,
      numeroEconomico: numeroNormalizado,
    );

    final referencia = _vehiculos.doc();

    await referencia.set({
      ...vehiculo.toMap(),
      'estado': 'activo',
      'placasNormalizadas': placasNormalizadas,
      'numeroEconomicoNormalizado': numeroNormalizado,
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // Actualiza los datos del vehículo y conserva los campos de otros módulos.
  // Entrada: vehiculo con identificador y datos actualizados.
  // Salida: un Future que termina cuando Firestore confirma la actualización.
  // Lanza errores si falta el identificador, el vehículo o hay datos duplicados.
  Future<void> actualizarVehiculo(VehiculoModel vehiculo) async {
    if (vehiculo.uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    _validarDatos(vehiculo);

    final referencia = _vehiculos.doc(vehiculo.uid);
    final existente = await referencia.get();

    if (!existente.exists) {
      throw StateError('No se encontró el vehículo que deseas actualizar.');
    }

    final placasNormalizadas = _normalizar(vehiculo.placas);
    final numeroNormalizado = _normalizar(vehiculo.numeroEconomico);

    await _validarUnicidad(
      placas: placasNormalizadas,
      numeroEconomico: numeroNormalizado,
      uidExcluir: vehiculo.uid,
    );

    // Usa update para conservar campos administrados por otros módulos,
    // como operadorUidActual.
    await referencia.update({
      ...vehiculo.toMap(),
      'placasNormalizadas': placasNormalizadas,
      'numeroEconomicoNormalizado': numeroNormalizado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // Da de baja un vehículo sin eliminar su documento ni su historial.
  // Entrada: uid, identificador del vehículo que se dará de baja.
  // Salida: un Future que termina cuando Firestore confirma el cambio.
  // Lanza errores si el identificador está vacío o el vehículo no existe.
  Future<void> darDeBaja(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    final referencia = _vehiculos.doc(uid);
    final documento = await referencia.get();

    if (!documento.exists) {
      throw StateError('No se encontró el vehículo que deseas dar de baja.');
    }

    await referencia.update({
      'estado': 'baja',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // Reactiva un vehículo que se encontraba dado de baja.
  // Entrada: uid, identificador del vehículo que se reactivará.
  // Salida: un Future que termina cuando Firestore confirma el cambio.
  // Lanza errores si el identificador está vacío o el vehículo no existe.
  Future<void> reactivarVehiculo(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    final referencia = _vehiculos.doc(uid);
    final documento = await referencia.get();

    if (!documento.exists) {
      throw StateError('No se encontró el vehículo que deseas reactivar.');
    }

    await referencia.update({
      'estado': 'activo',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // Valida los campos obligatorios y el año e intervalo preventivo del vehículo.
  // Entrada: vehiculo cuyos datos se revisarán.
  // Salida: ninguna si los datos son válidos; lanza ArgumentError si no lo son.
  void _validarDatos(VehiculoModel vehiculo) {
    if (vehiculo.placas.trim().isEmpty) {
      throw ArgumentError('Escribe las placas del vehículo.');
    }

    if (vehiculo.numeroEconomico.trim().isEmpty) {
      throw ArgumentError('Escribe el número económico.');
    }

    if (vehiculo.marca.trim().isEmpty) {
      throw ArgumentError('Escribe la marca del vehículo.');
    }

    if (vehiculo.modelo.trim().isEmpty) {
      throw ArgumentError('Escribe el modelo del vehículo.');
    }

    final anioActual = DateTime.now().year;

    if (vehiculo.anio < 1950 || vehiculo.anio > anioActual + 1) {
      throw ArgumentError('Escribe un año válido.');
    }

    if (vehiculo.intervaloPreventivoKm <= 0) {
      throw ArgumentError(
        'El intervalo preventivo debe ser mayor que cero.',
      );
    }
  }

  // Comprueba que las placas y el número económico no estén registrados.
  // Entradas: placas y numeroEconomico normalizados; uidExcluir opcional para
  // omitir el vehículo que se está actualizando.
  // Salida: un Future que termina si ambos valores son únicos; lanza
  // ArgumentError cuando encuentra un duplicado.
  Future<void> _validarUnicidad({
    required String placas,
    required String numeroEconomico,
    String? uidExcluir,
  }) async {
    final consulta = await _vehiculos.get();

    for (final documento in consulta.docs) {
      if (documento.id == uidExcluir) {
        continue;
      }

      final datos = documento.data();

      final placasExistentes = _normalizar(
        (datos['placasNormalizadas'] ?? datos['placas'] ?? '').toString(),
      );

      final numeroExistente = _normalizar(
        (datos['numeroEconomicoNormalizado'] ??
                datos['numeroEconomico'] ??
                datos['numeco'] ??
                '')
            .toString(),
      );

      if (placasExistentes == placas) {
        throw ArgumentError(
          'Ya existe un vehículo registrado con esas placas.',
        );
      }

      if (numeroExistente == numeroEconomico) {
        throw ArgumentError(
          'Ya existe un vehículo con ese número económico.',
        );
      }
    }
  }

  // Normaliza un texto para comparar placas o números económicos.
  // Entrada: valor original que se desea normalizar.
  // Salida: texto en mayúsculas, sin espacios al inicio, al final o intermedios.
  String _normalizar(String valor) {
    return valor.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }
}