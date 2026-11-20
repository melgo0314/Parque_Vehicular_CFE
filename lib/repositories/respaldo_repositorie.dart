
import 'package:cloud_functions/cloud_functions.dart';

import '../models/respaldo_model.dart';

class RespaldoRepositorie {
  // Instancia de Firebase Cloud Functions.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  // Consulta el historial de respaldos.
  Future<List<RespaldoModel>> obtenerRespaldos() async {
    try {
      final resultado = await _functions
          .httpsCallable('obtenerRespaldos')
          .call();

      final datos = resultado.data;

      List<dynamic> listaRespaldos = [];

      if (datos is List) {
        listaRespaldos = datos;
      } else if (datos is Map) {
        listaRespaldos = datos['respaldos'] ?? [];
      }

      return listaRespaldos.map((elemento) {
        final datosRespaldo =
            Map<String, dynamic>.from(elemento as Map);

        final identificador =
            datosRespaldo['identificador']?.toString() ?? '';

        return RespaldoModel.fromMap(
          identificador,
          datosRespaldo,
        );
      }).where((respaldo) {
        return respaldo.identificador.isNotEmpty;
      }).toList();
    } on FirebaseFunctionsException {
      rethrow;
    } catch (e) {
      throw Exception(
        'No fue posible consultar los respaldos: $e',
      );
    }
  }

  // Solicita la generación de un nuevo respaldo.
  Future<Map<String, dynamic>> generarRespaldo() async {
    try {
      final resultado = await _functions
          .httpsCallable('generarRespaldo')
          .call();

      if (resultado.data is Map) {
        return Map<String, dynamic>.from(resultado.data);
      }

      return {};
    } on FirebaseFunctionsException {
      rethrow;
    } catch (e) {
      throw Exception(
        'No fue posible iniciar la generación del respaldo: $e',
      );
    }
  }

  // Solicita restaurar el respaldo seleccionado.
  Future<Map<String, dynamic>> restaurarRespaldo(
    String identificador,
  ) async {
    try {
      final resultado = await _functions
          .httpsCallable('restaurarRespaldo')
          .call({
        'identificador': identificador,
        'confirmar': true,
      });

      if (resultado.data is Map) {
        return Map<String, dynamic>.from(resultado.data);
      }

      return {};
    } on FirebaseFunctionsException {
      rethrow;
    } catch (e) {
      throw Exception(
        'No fue posible iniciar la restauración: $e',
      );
    }
  }
}
