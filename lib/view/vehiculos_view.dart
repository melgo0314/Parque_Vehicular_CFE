import 'package:flutter/material.dart';
import 'package:p_vehicular/viewmodel/vehiculos_viewmodel.dart';
import 'package:p_vehicular/core/theme/app_theme.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'form_vehiculo_view.dart';

class VehiculosView extends StatefulWidget {
  const VehiculosView({super.key});

  @override
  State<VehiculosView> createState() => _VehiculosViewState();
}

class _VehiculosViewState extends State<VehiculosView> {
  final VehiculosViewModel _viewModel = VehiculosViewModel();
  final TextEditingController _busquedaController = TextEditingController();

  String _busqueda = '';
  String _filtro = 'todos';

  @override
  void dispose() {
    _busquedaController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario({VehiculoModel? vehiculo}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormVehiculoView(vehiculo: vehiculo),
      ),
    );
  }

  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}'.trim();
  }

  String _estadoColor(VehiculoModel vehiculo) {
    if (vehiculo.estado.toLowerCase() == 'baja') return 'baja';
    return vehiculo.estadoOperativo.toLowerCase();
  }

  String _nombreEstado(VehiculoModel vehiculo) {
    if (vehiculo.estado.toLowerCase() == 'baja') return 'De baja';

    switch (vehiculo.estadoOperativo.toLowerCase()) {
      case 'en_taller':
        return 'En taller';
      case 'servicio_proximo':
        return 'Servicio próximo';
      case 'servicio_vencido':
        return 'Servicio vencido';
      case 'operativo':
      default:
        return 'Operativo';
    }
  }

  IconData _iconoEstado(VehiculoModel vehiculo) {
    if (vehiculo.estado.toLowerCase() == 'baja') {
      return Icons.remove_circle_outline;
    }

    switch (vehiculo.estadoOperativo.toLowerCase()) {
      case 'en_taller':
        return Icons.build_outlined;
      case 'servicio_proximo':
        return Icons.schedule_outlined;
      case 'servicio_vencido':
        return Icons.warning_amber_rounded;
      case 'operativo':
      default:
        return Icons.check;
    }
  }

  String _formatearKilometraje(int kilometraje) {
    return kilometraje.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

  bool _coincideFiltro(VehiculoModel vehiculo) {
    final estadoAdministrativo = vehiculo.estado.toLowerCase();
    final estadoOperativo = vehiculo.estadoOperativo.toLowerCase();

    switch (_filtro) {
      case 'operativos':
        return estadoAdministrativo != 'baja' &&
            estadoOperativo == 'operativo';
      case 'taller':
        return estadoAdministrativo != 'baja' &&
            estadoOperativo == 'en_taller';
      case 'servicio':
        return estadoAdministrativo != 'baja' &&
            (estadoOperativo == 'servicio_proximo' ||
                estadoOperativo == 'servicio_vencido');
      case 'baja':
        return estadoAdministrativo == 'baja';
      case 'todos':
      default:
        return estadoAdministrativo != 'baja';
    }
  }

  Widget _chipFiltro(String valor, String etiqueta) {
    final seleccionado = _filtro == valor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(etiqueta),
        selected: seleccionado,
        showCheckmark: seleccionado,
        onSelected: (_) => setState(() => _filtro = valor),
        selectedColor: AppTheme.cfeGreen,
        backgroundColor: AppTheme.pureWhite,
        labelStyle: TextStyle(
          color: seleccionado ? AppTheme.pureWhite : AppTheme.primaryText,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: seleccionado ? AppTheme.cfeGreen : AppTheme.border,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }

  Widget _tarjetaVehiculo(VehiculoModel vehiculo) {
    final estadoColor = _estadoColor(vehiculo);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _abrirFormulario(vehiculo: vehiculo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.avatarSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppTheme.avatarText,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombreVehiculo(vehiculo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehiculo.placas} · ${vehiculo.numeroEconomico}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.vehicleStatusSurface(estadoColor),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconoEstado(vehiculo),
                                color: AppTheme.vehicleStatusText(estadoColor),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _nombreEstado(vehiculo),
                                style: TextStyle(
                                  color:
                                      AppTheme.vehicleStatusText(estadoColor),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.speed_outlined,
                              size: 16,
                              color: AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatearKilometraje(vehiculo.kilometrajeActual)} km',
                              style: const TextStyle(
                                color: AppTheme.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ver o editar ${_nombreVehiculo(vehiculo)}',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: () => _abrirFormulario(vehiculo: vehiculo),
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incluirBaja = _filtro == 'baja';

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Vehículos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: ColoredBox(
            color: AppTheme.accentYellow,
            child: SizedBox(height: 3, width: double.infinity),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: AppTheme.accentText,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo vehículo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: TextField(
                    controller: _busquedaController,
                    textInputAction: TextInputAction.search,
                    onChanged: (valor) => setState(() => _busqueda = valor),
                    decoration: InputDecoration(
                      hintText: 'Buscar por placa, marca o No. económico',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busqueda.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: () {
                                _busquedaController.clear();
                                setState(() => _busqueda = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: AppTheme.pureWhite,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: AppTheme.cfeGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chipFiltro('todos', 'Todos'),
                      _chipFiltro('operativos', 'Operativos'),
                      _chipFiltro('taller', 'En taller'),
                      _chipFiltro('servicio', 'Con servicio'),
                      _chipFiltro('baja', 'De baja'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<VehiculoModel>>(
                    stream: _viewModel.obtenerVehiculos(
                      busqueda: _busqueda,
                      incluirBaja: incluirBaja,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorRed,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No se pudieron cargar los vehículos.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.cfeGreen,
                          ),
                        );
                      }

                      final vehiculos = (snapshot.data ?? [])
                          .where(_coincideFiltro)
                          .toList();

                      if (vehiculos.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 48,
                                  color: AppTheme.secondaryText,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _busqueda.isEmpty && _filtro == 'todos'
                                      ? 'Todavía no hay vehículos registrados.'
                                      : 'No se encontraron vehículos con esos criterios.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppTheme.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: vehiculos.length,
                        itemBuilder: (context, index) {
                          return _tarjetaVehiculo(vehiculos[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}