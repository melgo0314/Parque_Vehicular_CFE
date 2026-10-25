import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';
import 'form_mantenimiento_view.dart';

class MantenimientoView extends StatefulWidget {
  const MantenimientoView({super.key, required List<dynamic> vehiculos});

  @override
  State<MantenimientoView> createState() => _MantenimientoViewState();
}

class _MantenimientoViewState extends State<MantenimientoView> {
  final _viewModel = MantenimientoViewModel();

  late final Stream<List<VehiculoModel>> _vehiculosStream;

  String? _vehiculoUid;
  String _modulo = 'mecanico';
  String _filtroTipo = 'todos';

  @override
  void initState() {
    super.initState();
    _vehiculosStream = _viewModel.obtenerVehiculos();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _nombreModulo(String modulo) {
    if (modulo == 'hidraulico') return 'Hidráulico';
    if (modulo == 'laboratorio_pemp') return 'Pruebas PEMP';
    return 'Mecánico';
  }

  String _nombreTipo(String tipo) {
    if (tipo == 'correctivo') return 'Correctivo';
    if (tipo == 'prueba') return 'Prueba';
    return 'Preventivo';
  }

  String _fechaTexto(DateTime fecha) {
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

  String _numeroTexto(int numero) {
    return numero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

  Future<void> _abrirFormulario({
    MantenimientoModel? mantenimiento,
  }) async {
    final vehiculoUid = _vehiculoUid;

    if (vehiculoUid == null || vehiculoUid.isEmpty) {
      _mensaje('Primero selecciona un vehículo.', esError: true);
      return;
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => FormMantenimientoView(
          vehiculoUidInicial: vehiculoUid,
          moduloInicial: _modulo,
          mantenimiento: mantenimiento,
        ),
      ),
    );

    if (!mounted || resultado != true) return;

    _mensaje(
      mantenimiento == null
          ? 'El mantenimiento se registró correctamente.'
          : 'Los cambios se guardaron correctamente.',
    );
  }

  Future<void> _confirmarEliminacion(
    MantenimientoModel mantenimiento,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.alertOrange,
          ),
          title: const Text('¿Eliminar mantenimiento?'),
          content: const Text(
            'Se eliminará este registro del historial. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
                minimumSize: const Size(100, 48),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    final eliminado =
        await _viewModel.eliminarMantenimiento(mantenimiento.uid);

    if (!mounted) return;

    if (eliminado) {
      _mensaje('El mantenimiento se eliminó correctamente.');
    } else {
      _mensaje(
        _viewModel.mensajeError ?? 'No se pudo eliminar el mantenimiento.',
        esError: true,
      );
    }
  }

  void _mensaje(String texto, {bool esError = false}) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Mantenimientos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<VehiculoModel>>(
          stream: _vehiculosStream,
          builder: (context, vehiculosSnapshot) {
            if (vehiculosSnapshot.hasError) {
              return _estado(
                'No se pudieron cargar los vehículos. Revisa tu conexión.',
              );
            }

            if (vehiculosSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !vehiculosSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final vehiculos = vehiculosSnapshot.data ?? [];

            if (vehiculos.isEmpty) {
              return _estado('No hay vehículos disponibles.');
            }

            if (_vehiculoUid == null ||
                !vehiculos.any((vehiculo) => vehiculo.uid == _vehiculoUid)) {
              _vehiculoUid = vehiculos.first.uid;
            }

            VehiculoModel vehiculoSeleccionado = vehiculos.first;

            for (final vehiculo in vehiculos) {
              if (vehiculo.uid == _vehiculoUid) {
                vehiculoSeleccionado = vehiculo;
                break;
              }
            }

            return _contenido(vehiculos, vehiculoSeleccionado);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text(
          'Registrar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _contenido(
    List<VehiculoModel> vehiculos,
    VehiculoModel vehiculoSeleccionado,
  ) {
    return StreamBuilder<List<MantenimientoModel>>(
      stream: _viewModel.obtenerMantenimientos(
        vehiculoUid: vehiculoSeleccionado.uid,
        modulo: _modulo,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _estado(
            'No se pudo cargar el historial. Revisa tu conexión.',
          );
        }

        final mantenimientos = snapshot.data ?? [];

        final registrosVisibles = mantenimientos.where((registro) {
          return _filtroTipo == 'todos' ||
              registro.tipoMantenimiento == _filtroTipo;
        }).toList();

        final proximoPreventivo = _buscarProximoPreventivo(
          mantenimientos,
          vehiculoSeleccionado.kilometrajeActual,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _selectorVehiculo(vehiculos),
            const SizedBox(height: 12),
            _avisoPreventivo(
              proximoPreventivo,
              vehiculoSeleccionado.kilometrajeActual,
            ),
            const SizedBox(height: 18),
            Text(
              'Historial · ${_nombreModulo(_modulo)}',
              style: const TextStyle(
                color: AppTheme.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _selectorModulo(),
            const SizedBox(height: 10),
            if (_modulo != 'laboratorio_pemp') ...[
              _selectorTipo(),
              const SizedBox(height: 12),
            ],
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (registrosVisibles.isEmpty)
              _sinRegistros()
            else
              ...registrosVisibles.map(_tarjetaMantenimiento),
          ],
        );
      },
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
          setState(() => _vehiculoUid = valor);
        }
      },
    );
  }

  Widget _selectorModulo() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _botonModulo('Mecánico', 'mecanico'),
        _botonModulo('Hidráulico', 'hidraulico'),
        _botonModulo('Pruebas PEMP', 'laboratorio_pemp'),
      ],
    );
  }

  Widget _botonModulo(String texto, String valor) {
    final seleccionado = _modulo == valor;

    return ChoiceChip(
      label: Text(texto),
      selected: seleccionado,
      onSelected: (_) {
        setState(() {
          _modulo = valor;
          _filtroTipo = 'todos';
        });
      },
      selectedColor: AppTheme.cfeGreen,
      labelStyle: TextStyle(
        color: seleccionado ? AppTheme.pureWhite : AppTheme.primaryText,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _selectorTipo() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'todos', label: Text('Todos')),
        ButtonSegment(value: 'preventivo', label: Text('Preventivo')),
        ButtonSegment(value: 'correctivo', label: Text('Correctivo')),
      ],
      selected: {_filtroTipo},
      showSelectedIcon: false,
      onSelectionChanged: (seleccion) {
        if (seleccion.isNotEmpty) {
          setState(() => _filtroTipo = seleccion.first);
        }
      },
    );
  }

  MantenimientoModel? _buscarProximoPreventivo(
    List<MantenimientoModel> mantenimientos,
    int kilometrajeActual,
  ) {
    MantenimientoModel? proximo;

    for (final mantenimiento in mantenimientos) {
      final kilometrajeProgramado = mantenimiento.kilometrajeProgramado;

      if (mantenimiento.tipoMantenimiento != 'preventivo' ||
          kilometrajeProgramado == null ||
          kilometrajeProgramado < kilometrajeActual) {
        continue;
      }

      if (proximo == null ||
          kilometrajeProgramado < proximo.kilometrajeProgramado!) {
        proximo = mantenimiento;
      }
    }

    return proximo;
  }

  Widget _avisoPreventivo(
    MantenimientoModel? proximo,
    int kilometrajeActual,
  ) {
    if (proximo == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.roleSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No hay un próximo mantenimiento preventivo programado.',
          style: TextStyle(color: AppTheme.primaryText),
        ),
      );
    }

    final kilometrajeProgramado = proximo.kilometrajeProgramado!;
    final faltan = kilometrajeProgramado - kilometrajeActual;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningSurface,
        border: Border.all(
          color: AppTheme.alertOrange.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            faltan == 0
                ? 'Preventivo programado: '
                    '${_numeroTexto(kilometrajeProgramado)} km'
                : 'Próximo preventivo: '
                    '${_numeroTexto(kilometrajeProgramado)} km',
            style: const TextStyle(
              color: AppTheme.warningText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            faltan == 0
                ? 'El vehículo llegó al kilometraje programado.'
                : 'Faltan ${_numeroTexto(faltan)} km · '
                    'kilometraje actual ${_numeroTexto(kilometrajeActual)} km',
            style: const TextStyle(color: AppTheme.warningText),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaMantenimiento(MantenimientoModel mantenimiento) {
    final esPreventivo =
        mantenimiento.tipoMantenimiento == 'preventivo';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: esPreventivo
                        ? AppTheme.operationalSurface
                        : AppTheme.warningSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _nombreTipo(mantenimiento.tipoMantenimiento),
                    style: TextStyle(
                      color: esPreventivo
                          ? AppTheme.operationalText
                          : AppTheme.warningText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _fechaTexto(mantenimiento.fechaRealizado),
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Acciones del mantenimiento',
                  onSelected: (accion) {
                    if (accion == 'editar') {
                      _abrirFormulario(mantenimiento: mantenimiento);
                    } else if (accion == 'eliminar') {
                      _confirmarEliminacion(mantenimiento);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mantenimiento.trabajoRealizado,
              style: const TextStyle(
                color: AppTheme.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (mantenimiento.piezasUtilizadas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Piezas: ${mantenimiento.piezasUtilizadas}',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            if (mantenimiento.proveedor.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Responsable o proveedor: ${mantenimiento.proveedor}',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            if (_modulo == 'laboratorio_pemp' &&
                mantenimiento.categoriaPemp.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Categoría PEMP: ${mantenimiento.categoriaPemp}',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            if (mantenimiento.horometroHoras != null) ...[
              const SizedBox(height: 4),
              Text(
                'Horómetro: ${mantenimiento.horometroHoras} horas',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            if (mantenimiento.observaciones.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Observaciones: ${mantenimiento.observaciones}',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    mantenimiento.kilometraje == null
                        ? 'Kilometraje no indicado'
                        : '${_numeroTexto(mantenimiento.kilometraje!)} km',
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '\$${mantenimiento.costo.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sinRegistros() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No hay registros para este vehículo y módulo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.secondaryText),
      ),
    );
  }

  Widget _estado(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.secondaryText),
        ),
      ),
    );
  }
}