import 'package:flutter/material.dart';
import 'package:p_vehicular/models/kilometraje_model.dart';
import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/kilometraje_viewmodel.dart';

class KilometrajeView extends StatefulWidget {
  final List<VehiculoModel> vehiculos;

  const KilometrajeView({
    super.key,
    required this.vehiculos,
  });

  @override
  State<KilometrajeView> createState() => _KilometrajeViewState();
}

class _KilometrajeViewState extends State<KilometrajeView> {
  final _viewModel = KilometrajeViewModel();

  String? _vehiculoUid;

  @override
  void initState() {
    super.initState();

    if (widget.vehiculos.isNotEmpty) {
      _vehiculoUid = widget.vehiculos.first.uid;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

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

    final dia = fecha.day.toString().padLeft(2, '0');
    return '$dia ${meses[fecha.month - 1]} ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final vehiculos = widget.vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();

    final vehiculoSeleccionado = vehiculos.firstWhere(
      (vehiculo) => vehiculo.uid == _vehiculoUid,
      orElse: () => vehiculos.isEmpty
          ? _vehiculoVacio()
          : vehiculos.first,
    );

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Kilometraje',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: vehiculos.isEmpty
            ? _vistaSinVehiculos()
            : StreamBuilder<List<KilometrajeModel>>(
                stream: _viewModel.obtenerRegistros(
                  vehiculoUid: vehiculoSeleccionado.uid,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'No se pudieron cargar los registros. '
                        'Revisa tu conexión.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final registros = snapshot.data ?? [];

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          children: [
                            _selectorVehiculo(vehiculos),
                            const SizedBox(height: 14),
                            _resumenKilometraje(
                              vehiculoSeleccionado,
                              registros,
                            ),
                            const SizedBox(height: 14),
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (registros.isEmpty)
                              _vistaSinRegistros(vehiculoSeleccionado)
                            else
                              ...registros.map(_tarjetaRegistro),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: vehiculos.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.accentYellow,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text(
                'Registrar km',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/form_kilometraje',
                  arguments: vehiculoSeleccionado,
                );
              },
            ),
    );
  }

  Widget _selectorVehiculo(List<VehiculoModel> vehiculos) {
    return DropdownButtonFormField<String>(
      value: _vehiculoUid,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.local_shipping_outlined),
      ),
      items: vehiculos.map((vehiculo) {
        return DropdownMenuItem<String>(
          value: vehiculo.uid,
          child: Text(
            '${vehiculo.numeroEconomico} · '
            '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (valor) {
        if (valor != null) {
          setState(() {
            _vehiculoUid = valor;
          });
        }
      },
    );
  }

  Widget _resumenKilometraje(
    VehiculoModel vehiculo,
    List<KilometrajeModel> registros,
  ) {
    final kilometrajeActual = registros.isNotEmpty
        ? registros.first.kilometrajeFinal
        : vehiculo.kilometrajeActual;

    int variacion = 0;
    if (registros.length > 1) {
      variacion =
          registros.first.kilometrajeFinal - registros.last.kilometrajeFinal;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kilometraje actual',
            style: TextStyle(
              color: AppTheme.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatearKilometraje(kilometrajeActual)} km',
            style: const TextStyle(
              color: AppTheme.cfeGreen,
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.speed_outlined,
                size: 18,
                color: AppTheme.secondaryText,
              ),
              const SizedBox(width: 6),
              const Text(
                'Variación en el periodo: ',
                style: TextStyle(color: AppTheme.secondaryText),
              ),
              Text(
                '${variacion >= 0 ? '+' : ''}'
                '${_formatearKilometraje(variacion)} km',
                style: const TextStyle(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaRegistro(KilometrajeModel registro) {
    final variacion = registro.kilometrajeFinal - registro.kilometrajeIni;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatearFecha(registro.fecha),
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${_formatearKilometraje(registro.kilometrajeFinal)} km',
                style: const TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  registro.observaciones.isEmpty
                      ? 'Registro de kilometraje'
                      : registro.observaciones,
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
              ),
              if (variacion > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.roleSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${_formatearKilometraje(variacion)} km',
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vistaSinRegistros(VehiculoModel vehiculo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Todavía no hay registros de kilometraje para '
        '${vehiculo.numeroEconomico}.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.secondaryText),
      ),
    );
  }

  Widget _vistaSinVehiculos() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No hay vehículos disponibles para consultar el kilometraje.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _formatearKilometraje(int kilometraje) {
    return kilometraje.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

  VehiculoModel _vehiculoVacio() {
    return const VehiculoModel(
      uid: '',
      placas: '',
      numeroEconomico: '',
      marca: '',
      modelo: '',
      anio: 0,
    );
  }
}