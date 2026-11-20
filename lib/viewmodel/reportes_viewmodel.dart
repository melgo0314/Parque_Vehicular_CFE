
import 'package:flutter/material.dart';

import 'package:p_vehicular/models/reporte_model.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/repositories/reportes_repositorie.dart';
import 'package:p_vehicular/repositories/vehiculo_repositorie.dart';

import 'package:p_vehicular/services/reportes/pdf_reporte_service.dart';
import 'package:p_vehicular/services/reportes/excel_reporte_service.dart';
import 'package:p_vehicular/services/reportes/guardar_reporte_service.dart';

class ReportesViewmodel extends ChangeNotifier {
  final ReportesRepositorie _repositorio = ReportesRepositorie();
  final VehiculoRepositorie _vehiculoRepositorio = VehiculoRepositorie();

  final PdfReporteService _pdfService = PdfReporteService();
  final ExcelReporteService _excelService = ExcelReporteService();
  final GuardarReporteService _guardarService = GuardarReporteService();

  bool _cargando = false;
  String _mensaje = '';

  bool get cargando => _cargando;
  String get mensaje => _mensaje;

  // Obtiene los vehículos activos para mostrarlos en la vista.
  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _vehiculoRepositorio.obtenerVehiculos();
  }

  // Consulta la información necesaria para los reportes.
  Future<ReporteModel?> generarReporte({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<String> vehiculosUid,
  }) async {
    _cargando = true;
    _mensaje = '';
    notifyListeners();

    try {
      final reporte = await _repositorio.obtenerDatosReporte(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        vehiculosUid: vehiculosUid,
      );

      _mensaje = 'La información del reporte se consultó correctamente.';

      return reporte;
    } catch (e) {
      _mensaje = e.toString().replaceFirst('Exception: ', '');

      return null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Genera y guarda el archivo según el tipo de reporte seleccionado.
  Future<bool> exportarReporte({
    required String tipoReporte,
    required ReporteModel reporte,
  }) async {
    _cargando = true;
    _mensaje = '';
    notifyListeners();

    try {
      if (tipoReporte == 'kilometraje') {
        final bytes = await _pdfService.generarKilometraje(reporte);

        final resultado = await _guardarService.guardarPDF(
          nombre: 'reporte_kilometraje',
          bytes: bytes,
        );

        if (resultado == null) {
          _mensaje = 'Se canceló el guardado del archivo.';
          return false;
        }
      } else if (tipoReporte == 'rendimiento') {
        final bytes = await _pdfService.generarRendimiento(reporte);

        final resultado = await _guardarService.guardarPDF(
          nombre: 'reporte_rendimiento_combustible',
          bytes: bytes,
        );

        if (resultado == null) {
          _mensaje = 'Se canceló el guardado del archivo.';
          return false;
        }
      } else if (tipoReporte == 'mantenimientos') {
        final bytes = await _pdfService.generarMantenimientos(reporte);

        final resultado = await _guardarService.guardarPDF(
          nombre: 'reporte_mantenimientos',
          bytes: bytes,
        );

        if (resultado == null) {
          _mensaje = 'Se canceló el guardado del archivo.';
          return false;
        }
      } else if (tipoReporte == 'reparaciones') {
        final bytes = await _pdfService.generarReparaciones(reporte);

        final resultado = await _guardarService.guardarPDF(
          nombre: 'reporte_reparaciones',
          bytes: bytes,
        );

        if (resultado == null) {
          _mensaje = 'Se canceló el guardado del archivo.';
          return false;
        }
      } else if (tipoReporte == 'cargas') {
        final bytes = await _excelService.generarCargasCombustible(reporte);

        final resultado = await _guardarService.guardarExcel(
          nombre: 'reporte_cargas_combustible',
          bytes: bytes,
        );

        if (resultado == null) {
          _mensaje = 'Se canceló el guardado del archivo.';
          return false;
        }
      } else {
        _mensaje = 'El tipo de reporte seleccionado no es válido.';
        return false;
      }

      _mensaje = 'El reporte se generó y guardó correctamente.';
      return true;
    } catch (e) {
      _mensaje = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Limpia el mensaje mostrado en la vista.
  void limpiarMensaje() {
    _mensaje = '';
    notifyListeners();
  }
}
