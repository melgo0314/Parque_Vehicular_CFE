import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';

import 'package:p_vehicular/core/theme/app_theme.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/models/reporte_model.dart';
import 'package:p_vehicular/viewmodel/reportes_viewmodel.dart';

class ReportesView extends StatefulWidget {
  const ReportesView({super.key, required List<dynamic> vehiculos});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  final ReportesViewmodel _viewmodel = ReportesViewmodel();

  String? _tipoReporte;

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  final List<String> _vehiculosSeleccionados = [];

  final List<Map<String, String>> _tiposReporte = [
    {'valor': 'kilometraje', 'nombre': 'Kilometraje'},
    {'valor': 'rendimiento', 'nombre': 'Rendimiento de combustible'},
    {'valor': 'mantenimientos', 'nombre': 'Mantenimientos'},
    {'valor': 'reparaciones', 'nombre': 'Reparaciones'},
    {'valor': 'cargas', 'nombre': 'Cargas de combustible'},
  ];

  @override
  void initState() {
    super.initState();

    final hoy = DateTime.now();

    _fechaInicio = DateTime(hoy.year, hoy.month, 1);
    _fechaFin = DateTime(hoy.year, hoy.month, hoy.day);
  }

  @override
  void dispose() {
    _viewmodel.dispose();
    super.dispose();
  }

  // Muestra el selector de fechas.
  Future<void> _seleccionarFecha(bool esFechaInicio) async {
    final fechaActual = DateTime.now();

    final fechaInicial = esFechaInicio ? _fechaInicio! : _fechaFin!;

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: fechaActual,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme
                .copyWith(primary: AppTheme.cfeGreen),
          ),
          child: child!,
        );
      },
    );

    if (fecha == null) return;

    setState(() {
      if (esFechaInicio) {
        _fechaInicio = fecha;
      } else {
        _fechaFin = fecha;
      }
    });
  }

  // Convierte la fecha a un formato legible.
  String _formatearFecha(DateTime fecha) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    return '${fecha.day.toString().padLeft(2, '0')} '
        '${meses[fecha.month - 1]} ${fecha.year}';
  }

  // Selecciona o deselecciona un vehículo.
  void _cambiarVehiculo(String uid) {
    setState(() {
      if (_vehiculosSeleccionados.contains(uid)) {
        _vehiculosSeleccionados.remove(uid);
      } else {
        _vehiculosSeleccionados.add(uid);
      }
    });
  }

  // Valida los campos, consulta la información y exporta el reporte.
  Future<void> _generarReporte() async {
    if (_tipoReporte == null) {
      _mostrarMensaje('Selecciona el tipo de reporte.', esError: true);
      return;
    }

    if (_fechaInicio == null || _fechaFin == null) {
      _mostrarMensaje('Selecciona el periodo del reporte.', esError: true);
      return;
    }

    if (_fechaInicio!.isAfter(_fechaFin!)) {
      _mostrarMensaje(
        'La fecha inicial no puede ser posterior a la fecha final.',
        esError: true,
      );
      return;
    }

    if (_vehiculosSeleccionados.isEmpty) {
      _mostrarMensaje('Selecciona al menos un vehículo.', esError: true);
      return;
    }

    // Consulta la información del reporte.
    final ReporteModel? reporte = await _viewmodel.generarReporte(
      fechaInicio: _fechaInicio!,
      fechaFin: _fechaFin!,
      vehiculosUid: _vehiculosSeleccionados,
    );

    if (!mounted) return;

    if (reporte == null) {
      _mostrarMensaje(_viewmodel.mensaje, esError: true);
      return;
    }

    // Genera el archivo y permite guardarlo.
    final resultado = await _viewmodel.exportarReporte(
      tipoReporte: _tipoReporte!,
      reporte: reporte,
    );

    if (!mounted) return;

    _mostrarMensaje(
      _viewmodel.mensaje,
      esError:
          !resultado &&
          _viewmodel.mensaje != 'Se canceló el guardado del archivo.',
    );
  }

  // Muestra mensajes de éxito o error.
  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError
              ? Theme.of(context).colorScheme.error
              : AppTheme.cfeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // Construye una opción de tipo de reporte.
  Widget _construirOpcionReporte(Map<String, String> tipo) {
    final seleccionado = _tipoReporte == tipo['valor'];

    return InkWell(
      onTap: () {
        setState(() {
          _tipoReporte = tipo['valor'];
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppTheme.cfeGreen.withValues(alpha: 0.08)
              : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? AppTheme.cfeGreen : Colors.grey.shade300,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              seleccionado
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: seleccionado ? AppTheme.cfeGreen : Colors.grey,
              size: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tipo['nombre']!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF26332B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye un selector de fecha.
  Widget _construirSelectorFecha({
    required String titulo,
    required DateTime fecha,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 51,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatearFecha(fecha),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF607269),
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Construye el botón de selección de cada vehículo.
  Widget _construirOpcionVehiculo(VehiculoModel vehiculo) {
    final seleccionado = _vehiculosSeleccionados.contains(vehiculo.uid);

    return InkWell(
      onTap: () => _cambiarVehiculo(vehiculo.uid),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: seleccionado ? AppTheme.cfeGreen : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: seleccionado ? AppTheme.cfeGreen : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (seleccionado) ...[
              const Icon(Icons.check, color: Colors.white, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              vehiculo.numeroEconomico,
              style: TextStyle(
                color: seleccionado ? Colors.white : const Color(0xFF26332B),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const InicioFooter(),
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reportes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo de reporte.
                const Text(
                  'Tipo de reporte',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 9),

                ..._tiposReporte.map((tipo) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _construirOpcionReporte(tipo),
                  );
                }),

                const SizedBox(height: 5),

                // Periodo del reporte.
                Row(
                  children: [
                    _construirSelectorFecha(
                      titulo: 'Desde',
                      fecha: _fechaInicio!,
                      onTap: () => _seleccionarFecha(true),
                    ),
                    const SizedBox(width: 12),
                    _construirSelectorFecha(
                      titulo: 'Hasta',
                      fecha: _fechaFin!,
                      onTap: () => _seleccionarFecha(false),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Selección de vehículos.
                const Text(
                  'Vehículos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 9),

                StreamBuilder<List<VehiculoModel>>(
                  stream: _viewmodel.obtenerVehiculos(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'No fue posible consultar los vehículos.',
                        style: TextStyle(color: tema.colorScheme.error),
                      );
                    }

                    final vehiculos = snapshot.data ?? [];

                    if (vehiculos.isEmpty) {
                      return const Text('No hay vehículos disponibles.');
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vehiculos.map((vehiculo) {
                        return _construirOpcionVehiculo(vehiculo);
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 22),

                // Botón para generar el reporte.
                AnimatedBuilder(
                  animation: _viewmodel,
                  builder: (context, child) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _viewmodel.cargando ? null : _generarReporte,
                        icon: _viewmodel.cargando
                            ? const SizedBox(
                                height: 19,
                                width: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bar_chart),
                        label: Text(
                          _viewmodel.cargando
                              ? 'Consultando información...'
                              : 'Generar reporte',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cfeGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.cfeGreen.withValues(
                            alpha: 0.6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
