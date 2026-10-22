import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/combustible_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/combustible_viewmodel.dart';
import 'form_combustible_view.dart';

class CombustibleView extends StatefulWidget {
  final List<VehiculoModel> vehiculos;

  const CombustibleView({
    super.key,
    required this.vehiculos,
  });

  @override
  State<CombustibleView> createState() => _CombustibleViewState();
}

class _CombustibleViewState extends State<CombustibleView> {
  final _viewModel = CombustibleViewModel();
  final _busquedaController = TextEditingController();

  late List<VehiculoModel> _vehiculos;
  StreamSubscription<List<VehiculoModel>>? _suscripcionVehiculos;

  String _busqueda = '';
  String _vehiculoFiltro = '';
  String? _errorVehiculos;
  bool _cargandoVehiculos = false;

  @override
  void initState() {
    super.initState();

    _vehiculos = widget.vehiculos;

    // Si la pantalla que abre este módulo pasa una lista vacía,
    // carga los vehículos activos desde VehiculoRepositorie.
    if (_vehiculos.isEmpty) {
      _cargandoVehiculos = true;

      _suscripcionVehiculos = _viewModel.obtenerVehiculos().listen(
        (vehiculos) {
          if (!mounted) return;

          setState(() {
            _vehiculos = vehiculos;
            _cargandoVehiculos = false;
            _errorVehiculos = null;
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
  }

  @override
  void dispose() {
    _suscripcionVehiculos?.cancel();
    _busquedaController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario({CombustibleModel? carga}) async {
    if (_cargandoVehiculos) {
      _mostrarMensaje('Espera mientras se cargan los vehículos.');
      return;
    }

    if (_vehiculos.isEmpty) {
      _mostrarMensaje(
        _errorVehiculos ?? 'No hay vehículos activos para registrar una carga.',
        esError: true,
      );
      return;
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormCombustibleView(
          vehiculos: _vehiculos,
          carga: carga,
        ),
      ),
    );

    if (!mounted || resultado != true) return;

    _mostrarMensaje(
      carga == null
          ? 'La carga se registró correctamente.'
          : 'Los cambios se guardaron correctamente.',
    );
  }

  Future<void> _confirmarEliminacion(CombustibleModel carga) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar carga'),
        content: const Text(
          '¿Seguro que deseas eliminar este registro de combustible? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: AppTheme.pureWhite,
              minimumSize: const Size(100, 48),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final correcto = await _viewModel.eliminarCarga(carga.uid);

    if (!mounted) return;

    if (correcto) {
      _mostrarMensaje('La carga se eliminó correctamente.');
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo eliminar la carga.',
        esError: true,
      );
    }
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
        ),
      );
  }

  List<CombustibleModel> _filtrarCargas(
    List<CombustibleModel> cargas,
    Map<String, VehiculoModel> vehiculosPorId,
  ) {
    final texto = _busqueda.trim().toLowerCase();

    return cargas.where((carga) {
      if (_vehiculoFiltro.isNotEmpty &&
          carga.vehiculoUid != _vehiculoFiltro) {
        return false;
      }

      if (texto.isEmpty) return true;

      final vehiculo = vehiculosPorId[carga.vehiculoUid];
      final datosVehiculo = vehiculo == null
          ? ''
          : '${vehiculo.numeroEconomico} ${vehiculo.placas} '
              '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}';

      final datosCarga = [
        carga.tipoCombustible,
        carga.rpeUsuario,
        carga.kilometraje.toString(),
        carga.litros.toString(),
        carga.importe.toString(),
        _fechaFormateada(carga.fechaCarga),
        datosVehiculo,
      ].join(' ').toLowerCase();

      return datosCarga.contains(texto);
    }).toList();
  }

  String _fechaFormateada(DateTime fecha) {
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
    final vehiculosPorId = {
      for (final vehiculo in _vehiculos) vehiculo.uid: vehiculo,
    };

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        title: const Text('Combustible'),
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _busquedaController,
                onChanged: (valor) => setState(() => _busqueda = valor),
                decoration: InputDecoration(
                  hintText: 'Buscar por vehículo, tipo o RPE',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busqueda.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() => _busqueda = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            if (_cargandoVehiculos)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorVehiculos != null)
              Expanded(
                child: _estadoVacio(
                  icono: Icons.cloud_off_outlined,
                  mensaje: _errorVehiculos!,
                ),
              )
            else if (_vehiculos.isEmpty)
              Expanded(
                child: _estadoVacio(
                  icono: Icons.local_shipping_outlined,
                  mensaje: 'No hay vehículos activos registrados.',
                ),
              )
            else
              Expanded(
                child: StreamBuilder<List<CombustibleModel>>(
                  stream: _viewModel.obtenerCargas(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _estadoVacio(
                        icono: Icons.cloud_off_outlined,
                        mensaje:
                            'No se pudo cargar el historial. Revisa tu '
                            'conexión e inténtalo de nuevo.',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final todasLasCargas = snapshot.data ?? [];

                    if (todasLasCargas.isEmpty) {
                      return _estadoVacio(
                        icono: Icons.local_gas_station_outlined,
                        mensaje: 'Todavía no hay cargas de combustible.',
                      );
                    }

                    final rendimientoPorId = <String, double?>{};
                    for (var i = 0; i < todasLasCargas.length; i++) {
                      rendimientoPorId[todasLasCargas[i].uid] =
                          _viewModel.calcularRendimientoKmL(
                        todasLasCargas,
                        i,
                      );
                    }

                    final cargasVisibles = _filtrarCargas(
                      todasLasCargas,
                      vehiculosPorId,
                    );

                    if (cargasVisibles.isEmpty) {
                      return _estadoVacio(
                        icono: Icons.search_off,
                        mensaje:
                            'No se encontraron cargas con esos criterios.',
                      );
                    }

                    final litrosMostrados = cargasVisibles.fold<double>(
                      0,
                      (total, carga) => total + carga.litros,
                    );

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${cargasVisibles.length} '
                                  '${cargasVisibles.length == 1 ? 'carga' : 'cargas'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                '${litrosMostrados.toStringAsFixed(1)} L',
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: cargasVisibles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final carga = cargasVisibles[index];

                              return _TarjetaCarga(
                                carga: carga,
                                vehiculo: vehiculosPorId[carga.vehiculoUid],
                                rendimientoKmL: rendimientoPorId[carga.uid],
                                fecha: _fechaFormateada(carga.fechaCarga),
                                onEditar: () =>
                                    _abrirFormulario(carga: carga),
                                onEliminar: () =>
                                    _confirmarEliminacion(carga),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cargandoVehiculos || _vehiculos.isEmpty
            ? null
            : () => _abrirFormulario(),
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva carga',
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
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCarga extends StatelessWidget {
  final CombustibleModel carga;
  final VehiculoModel? vehiculo;
  final double? rendimientoKmL;
  final String fecha;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaCarga({
    required this.carga,
    required this.vehiculo,
    required this.rendimientoKmL,
    required this.fecha,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final identificadorVehiculo = vehiculo == null
        ? 'Vehículo'
        : '${vehiculo!.numeroEconomico} • ${vehiculo!.placas}';

    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.cfeGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_gas_station_outlined,
                color: AppTheme.cfeGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identificadorVehiculo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${carga.tipoCombustible} • $fecha',
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _DatoCarga(
                        icono: Icons.local_gas_station_outlined,
                        texto: '${carga.litros.toStringAsFixed(1)} L',
                      ),
                      _DatoCarga(
                        icono: Icons.payments_outlined,
                        texto: '\$${carga.importe.toStringAsFixed(2)}',
                      ),
                      _DatoCarga(
                        icono: Icons.speed_outlined,
                        texto: '${carga.kilometraje} km',
                      ),
                      if (rendimientoKmL != null)
                        _DatoCarga(
                          icono: Icons.trending_up,
                          texto: '${rendimientoKmL!.toStringAsFixed(2)} km/L',
                        ),
                    ],
                  ),
                  if (carga.rpeUsuario.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Registró: ${carga.rpeUsuario}',
                      style: const TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Acciones de la carga',
              onSelected: (accion) {
                if (accion == 'editar') onEditar();
                if (accion == 'eliminar') onEliminar();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorRed,
                    ),
                    title: Text('Eliminar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DatoCarga extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _DatoCarga({
    required this.icono,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icono,
          size: 15,
          color: AppTheme.secondaryText,
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(
            color: AppTheme.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}