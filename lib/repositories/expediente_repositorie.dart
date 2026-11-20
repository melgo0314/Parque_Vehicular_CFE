
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/documento_model.dart';
import '../models/expediente_model.dart';

// Se comunica con Firebase para administrar los expedientes de los vehículos.
class ExpedienteRepositorie {
  // Crea el repositorio con las conexiones proporcionadas o predeterminadas.
  ExpedienteRepositorie({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // Conexión a Cloud Firestore.
  final FirebaseFirestore _db;

  // Conexión a Firebase Storage.
  final FirebaseStorage _storage;

  // Referencia al catálogo de documentos.
  CollectionReference<Map<String, dynamic>> get _documentos =>
      _db.collection('documentos');

  // Referencia a los expedientes.
  CollectionReference<Map<String, dynamic>> get _expedientes =>
      _db.collection('expedientes');

  // Inicializa el catálogo de tipos de documentos.
  // Solo registra los documentos que todavía no existen.
  Future<void> inicializarCatalogo() async {
    final catalogo = [
      DocumentoModel(
        uid: 'poliza_seguro',
        nombre: 'Póliza de seguro',
        descripcion: 'Documento que acredita el seguro del vehículo.',
      ),
      DocumentoModel(
        uid: 'tarjeta_circulacion',
        nombre: 'Tarjeta de circulación',
        descripcion: 'Documento que acredita el registro del vehículo.',
      ),
      DocumentoModel(
        uid: 'verificacion',
        nombre: 'Verificación vehicular',
        descripcion: 'Comprobante de verificación del vehículo.',
      ),
      DocumentoModel(
        uid: 'tenencia',
        nombre: 'Tenencia',
        descripcion: 'Comprobante de pago de tenencia.',
      ),
      DocumentoModel(
        uid: 'otros',
        nombre: 'Otros documentos',
        descripcion: 'Documentación adicional del vehículo.',
      ),
    ];

    for (final documento in catalogo) {
      final referencia = _documentos.doc(documento.uid);
      final existente = await referencia.get();

      if (!existente.exists) {
        await referencia.set(documento.toMap());
      }
    }
  }

  // Obtiene los tipos de documentos activos en tiempo real.
  Stream<List<DocumentoModel>> obtenerDocumentos() {
    return _documentos.snapshots().map((consulta) {
      final documentos = consulta.docs
          .map(
            (documento) => DocumentoModel.fromMap(
              documento.data(),
              documento.id,
            ),
          )
          .where((documento) => documento.activo)
          .toList();

      documentos.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(
              b.nombre.toLowerCase(),
            ),
      );

      return documentos;
    });
  }

  // Obtiene los expedientes correspondientes a un vehículo.
  Stream<List<ExpedienteModel>> obtenerExpedientes(
    String vehiculoUid,
  ) {
    if (vehiculoUid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del vehículo.');
    }

    return _expedientes
        .where('vehiculoUid', isEqualTo: vehiculoUid)
        .snapshots()
        .map((consulta) {
      final expedientes = consulta.docs
          .map(
            (documento) => ExpedienteModel.fromMap(
              documento.data(),
              documento.id,
            ),
          )
          .toList();

      expedientes.sort(
        (a, b) => b.fechaCarga.compareTo(a.fechaCarga),
      );

      return expedientes;
    });
  }

  // Registra un expediente y almacena su archivo en Firebase Storage.
  Future<void> registrarExpediente({
    required ExpedienteModel expediente,
    required Uint8List archivoBytes,
  }) async {
    _validarExpediente(expediente, archivoBytes);

    // Verifica que el vehículo exista.
    final vehiculo = await _db
        .collection('vehiculo')
        .doc(expediente.vehiculoUid)
        .get();

    if (!vehiculo.exists) {
      throw StateError('No se encontró el vehículo seleccionado.');
    }

    // Evita registrar dos veces el mismo tipo de documento para un vehículo.
    final existente = await _expedientes
        .where('vehiculoUid', isEqualTo: expediente.vehiculoUid)
        .where('documentoUid', isEqualTo: expediente.documentoUid)
        .get();

    if (existente.docs.isNotEmpty) {
      throw ArgumentError(
        'Este vehículo ya tiene registrado ese tipo de documento.',
      );
    }

    // Genera una referencia para el nuevo expediente.
    final referencia = _expedientes.doc();

    // Genera la ruta donde se guardará el archivo.
    final ruta = _generarRuta(expediente);

    final archivo = _storage.ref().child(ruta);

    try {
      // Sube el archivo a Firebase Storage.
      await archivo.putData(
        archivoBytes,
        SettableMetadata(
          contentType: expediente.tipoMime,
        ),
      );

      // Obtiene la URL de descarga.
      final url = await archivo.getDownloadURL();

      // Completa los datos del expediente.
      final datos = expediente.toMap();

      datos['archivoUrl'] = url;
      datos['rutaStorage'] = ruta;
      datos['nombreArchivo'] = expediente.nombreArchivo.trim();
      datos['fechaCarga'] = Timestamp.fromDate(DateTime.now());

      // Guarda la información en Firestore.
      await referencia.set({
        ...datos,
        'creadoEn': FieldValue.serverTimestamp(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      // Si ocurre un error, intenta eliminar el archivo que se subió.
      try {
        await archivo.delete();
      } catch (_) {}

      rethrow;
    }
  }

  // Actualiza la información de un expediente.
  // Si recibe un archivo nuevo, también sustituye el archivo almacenado.
  Future<void> actualizarExpediente({
    required ExpedienteModel expediente,
    Uint8List? archivoBytes,
  }) async {
    if (expediente.uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del expediente.');
    }

    final referencia = _expedientes.doc(expediente.uid);
    final existente = await referencia.get();

    if (!existente.exists) {
      throw StateError('No se encontró el expediente que deseas actualizar.');
    }

    if (archivoBytes != null && archivoBytes.isEmpty) {
      throw ArgumentError('El archivo seleccionado está vacío.');
    }

    final datos = expediente.toMap();

    String? nuevaRuta;

    try {
      // Si se seleccionó un archivo nuevo, lo sube a Storage.
      if (archivoBytes != null) {
        final rutaAnterior = expediente.rutaStorage;
        nuevaRuta = _generarRuta(expediente);

        final archivo = _storage.ref().child(nuevaRuta);

        await archivo.putData(
          archivoBytes,
          SettableMetadata(
            contentType: expediente.tipoMime,
          ),
        );

        final url = await archivo.getDownloadURL();

        datos['archivoUrl'] = url;
        datos['rutaStorage'] = nuevaRuta;
        datos['nombreArchivo'] = expediente.nombreArchivo.trim();

        // Actualiza Firestore con la nueva información.
        await referencia.update({
          ...datos,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });

        // Elimina el archivo anterior después de actualizar Firestore.
        if (rutaAnterior.trim().isNotEmpty) {
          try {
            await _storage.ref().child(rutaAnterior).delete();
          } catch (_) {
            // El expediente ya fue actualizado.
          }
        }
      } else {
        // Actualiza únicamente los datos del expediente.
        await referencia.update({
          ...datos,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      // Si falla la actualización, intenta eliminar el archivo nuevo.
      if (nuevaRuta != null) {
        try {
          await _storage.ref().child(nuevaRuta).delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  // Elimina un expediente y su archivo almacenado.
  Future<void> eliminarExpediente(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('No se recibió el identificador del expediente.');
    }

    final referencia = _expedientes.doc(uid);
    final documento = await referencia.get();

    if (!documento.exists) {
      throw StateError('No se encontró el expediente que deseas eliminar.');
    }

    final datos = documento.data()!;
    final rutaStorage = datos['rutaStorage']?.toString() ?? '';

    // Elimina primero el registro de Firestore.
    await referencia.delete();

    // Después intenta eliminar el archivo de Storage.
    if (rutaStorage.trim().isNotEmpty) {
      try {
        await _storage.ref().child(rutaStorage).delete();
      } catch (error) {
        // El registro ya fue eliminado de Firestore.
        // Se informa del error para identificar el archivo pendiente.
        throw StateError(
          'El expediente se eliminó, pero no se pudo eliminar '
          'su archivo de Firebase Storage: $error',
        );
      }
    }
  }

  // Genera la ruta del archivo dentro de Firebase Storage.
  String _generarRuta(ExpedienteModel expediente) {
    final nombre = expediente.nombreArchivo
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    return 'expedientes/'
        '${expediente.vehiculoUid}/'
        '${expediente.documentoUid}/'
        '${DateTime.now().microsecondsSinceEpoch}_$nombre';
  }

  // Valida los datos necesarios para registrar un expediente.
  void _validarExpediente(
    ExpedienteModel expediente,
    Uint8List archivoBytes,
  ) {
    if (expediente.vehiculoUid.trim().isEmpty) {
      throw ArgumentError('No se recibió el vehículo.');
    }

    if (expediente.documentoUid.trim().isEmpty) {
      throw ArgumentError('Selecciona un tipo de documento.');
    }

    if (expediente.nombreArchivo.trim().isEmpty) {
      throw ArgumentError('Selecciona un archivo.');
    }

    if (archivoBytes.isEmpty) {
      throw ArgumentError('El archivo seleccionado está vacío.');
    }

    if (expediente.tipoMime != 'application/pdf' &&
        !expediente.tipoMime.startsWith('image/')) {
      throw ArgumentError(
        'Solo se permiten documentos PDF e imágenes.',
      );
    }
  }
}
