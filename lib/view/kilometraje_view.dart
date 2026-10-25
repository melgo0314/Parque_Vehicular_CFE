import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/kilometraje_model.dart';
import '../models/vehiculos_model.dart';
import '../view/form_kilometraje_view.dart';
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

  late List<VehiculoModel> _vehiculos;
  StreamSubscription<List<VehiculoModel>>? _suscripcionVehiculos;

  String? _vehiculoUid;
  String? _errorVehiculos;
  bool _cargandoVehiculos = false;

  @override
  void initState() {
    super.initState();

    _vehiculos = widget.vehiculos;

    if (_vehiculos.isEmpty) {
      _cargarVehiculos();
    } else {
      _vehiculoUid = _vehiculos.first.uid;
    }
  }

  void _cargarVehiculos() {
    _cargandoVehiculos = true;

    _suscripcionVehiculos = _viewModel.obtenerVehiculos().listen(
      (vehiculos) {
        if (!mounted) return;

        setState(() {
          _vehiculos = vehiculos;
          _cargandoVehiculos = false;
          _errorVehiculos = null;

          if (_vehiculos.isNotEmpty &&
              !_vehiculos.any((vehiculo) => vehiculo.uid == _vehiculoUid)) {
            _vehiculoUid = _vehiculos.first.uid;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _cargandoVehiculos = false;
          _errorVehiculos =
              'No se pudieron cargar los vehículos. Revisa tu conexión.';
        });
      },
    );
  }

  @override
  void dispose() {
    _suscripcionVehiculos?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario() async {
    if (_cargandoVehiculos) {
      _mostrarMensaje('Espera mientras se cargan los vehículos.');
      return;
    }

    final vehiculosDisponibles = _vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();

    if (vehiculosDisponibles.isEmpty) {
      _mostrarMensaje(
        _errorVehiculos ?? 'No hay vehículos para registrar kilometraje.',
        esError: true,
      );
      return;
    }

    VehiculoModel vehiculoSeleccionado = vehiculosDisponibles.first;

    for (final vehiculo in vehiculosDisponibles) {
      if (vehiculo.uid == _vehiculoUid) {
        vehiculoSeleccionado = vehiculo;
        break;
      }
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => FormKilometrajeView(
          vehiculos: vehiculosDisponibles,
          vehiculoUidInicial: vehiculoSeleccionado.uid,
        ),
      ),
    );

    if (!mounted || resultado != true) return;

    _mostrarMensaje('El registro de kilometraje se guardó correctamente.');
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  String _formatearKilometraje(int kilometraje) {
    return kilometraje.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final vehiculosDisponibles = _vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();

    VehiculoModel? vehiculoSeleccionado;

    for (final vehiculo in vehiculosDisponibles) {
      if (vehiculo.uid == _vehiculoUid) {
        vehiculoSeleccionado = vehiculo;
        break;
      }
    }

    vehiculoSeleccionado ??=
        vehiculosDisponibles.isEmpty ? null : vehiculosDisponibles.first;

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
        child: _cargandoVehiculos
            ? const Center(child: CircularProgressIndicator())
            : _errorVehiculos != null
                ? _estadoVacio(
                    icono: Icons.cloud_off_outlined,
                    mensaje: _errorVehiculos!,
                  )
                : vehiculoSeleccionado == null
                    ? _estadoVacio(
                        icono: Icons.local_shipping_outlined,
                        mensaje:
                            'No hay vehículos disponibles para consultar el kilometraje.',
                      )
                    : StreamBuilder<List<KilometrajeModel>>(
                        stream: _viewModel.obtenerRegistros(
                          vehiculoUid: vehiculoSeleccionado.uid,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _estadoVacio(
                              icono: Icons.cloud_off_outlined,
                              mensaje:
                                  'No se pudieron cargar los registros. '
                                  'Revisa tu conexión.',
                            );
                          }

                          final registros = snapshot.data ?? [];

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              20,
                              16,
                              100,
                            ),
                            children: [
                              _selectorVehiculo(vehiculosDisponibles),
                              const SizedBox(height: 14),
                              _resumenKilometraje(
                                vehiculoSeleccionado!,
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
                          );
                        },
                      ),
      ),
      // El botón permanece visible. Si aún no hay vehículos,
      // _abrirFormulario muestra un mensaje explicando el problema.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text(
          'Registrar km',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _estadoVacio({
    required IconData icono,
    required String mensaje,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 48,
              color: AppTheme.secondaryText,
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectorVehiculo(List<VehiculoModel> vehiculos) {
    final valorSeleccionado = vehiculos.any(
      (vehiculo) => vehiculo.uid == _vehiculoUid,
    )
        ? _vehiculoUid
        : vehiculos.first.uid;

    return DropdownButtonFormField<String>(
      value: valorSeleccionado,
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
        if (valor == null) return;

        setState(() {
          _vehiculoUid = valor;
        });
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
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
}