import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/models/kilometraje_model.dart';
import 'package:p_vehicular/models/combustible_model.dart';
import 'package:p_vehicular/models/mantenimiento_model.dart';

// Almacena la información consultada para generar los reportes.
class ReporteModel {
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final List<VehiculoModel> vehiculos;
  final List<KilometrajeModel> registrosKilometraje;
  final List<CombustibleModel> cargasCombustible;
  final List<CombustibleModel> cargasCombustibleAnteriores;
  final List<MantenimientoModel> mantenimientos;

  const ReporteModel({
    required this.fechaInicio,
    required this.fechaFin,
    required this.vehiculos,
    required this.registrosKilometraje,
    required this.cargasCombustible,
    required this.cargasCombustibleAnteriores,
    required this.mantenimientos,
  });
}