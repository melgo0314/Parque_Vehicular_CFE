import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';
import 'form_mantenimiento_view.dart';

class MantenimientoView extends StatefulWidget {
  final List<dynamic> vehiculos;

  const MantenimientoView({
    super.key,
    this.vehiculos = const [],
  });

  @override
  State<MantenimientoView> createState() => _MantenimientoViewState();
}

class _MantenimientoViewState extends State<MantenimientoView> {
  final MantenimientoViewModel _viewModel = MantenimientoViewModel();

  late final Stream<List<VehiculoModel>> _vehiculosStream;
  late final Future<bool> _esOperadorFuture;

  String? _vehiculoSeleccionadoUid;
  String _filtroSeleccionado = 'todos';

  final List<Map<String, String>> _filtros = const [
    {'valor': 'todos', 'texto': 'Todos'},
    {'valor': 'preventivo', 'texto': 'Preventivo'},
    {'valor': 'correctivo', 'texto': 'Correctivo'},
    {'valor': 'prueba', 'texto': 'Pruebas PEMP'},
  ];

  @override
  void initState() {
    super.initState();

    final vehiculosRecibidos =
        widget.vehiculos.whereType<VehiculoModel>().toList();

    if (vehiculosRecibidos.length == 1) {
      _vehiculoSeleccionadoUid = vehiculosRecibidos.first.uid;
    }

    _vehiculosStream = _viewModel.obtenerVehiculos();
    _esOperadorFuture = _consultarSiEsOperador();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<bool> _consultarSiEsOperador() async {
    final usuarioActual = FirebaseAuth.instance.currentUser;

    if (usuarioActual == null) {
      return true;
    }

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(usuarioActual.uid)
          .get();

      final rol =
          documento.data()?['rol']?.toString().trim().toLowerCase() ?? '';

      return rol != 'administrador' && rol != 'superusuario';
    } catch (_) {
      // Si no se puede comprobar el rol, ocultamos el selector por seguridad.
      return true;
    }
  }

  Future<void> _regresar() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    final esOperador = await _esOperadorFuture;

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      esOperador ? AppRoutes.operatorHome : AppRoutes.adminHome,
      (route) => false,
    );
  }

  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.numeroEconomico} · '
        '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}';
  }

  String _nombreModulo(String modulo) {
    switch (modulo) {
      case 'mecanico':
        return 'Mecánico';
      case 'hidraulico':
        return 'Hidráulico';
      case 'laboratorio_pemp':
        return 'Laboratorio PEMP';
      default:
        return modulo;
    }
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case 'preventivo':
        return 'Preventivo';
      case 'correctivo':
        return 'Correctivo';
      case 'prueba':
        return 'Prueba PEMP';
      default:
        return tipo;
    }
  }

  String _fecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin fecha';
    }

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

    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  Color _colorFondoTipo(String tipo) {
    switch (tipo) {
      case 'correctivo':
        return AppTheme.warningSurface;
      case 'prueba':
        return AppTheme.infoSurface;
      case 'preventivo':
      default:
        return AppTheme.operationalSurface;
    }
  }

  Color _colorTextoTipo(String tipo) {
    switch (tipo) {
      case 'correctivo':
        return AppTheme.warningText;
      case 'prueba':
        return AppTheme.infoBlue;
      case 'preventivo':
      default:
        return AppTheme.operationalText;
    }
  }

  Future<void> _abrirFormulario({
    required VehiculoModel vehiculo,
    MantenimientoModel? mantenimiento,
  }) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormMantenimientoView(
          vehiculo: vehiculo,
          mantenimiento: mantenimiento,
        ),
      ),
    );
  }

  Future<void> _confirmarEliminacion(
    MantenimientoModel mantenimiento,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar mantenimiento'),
          content: const Text(
            '¿Quieres eliminar este registro? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(100, 48),
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    final eliminado = await _viewModel.eliminarMantenimiento(
      mantenimiento.uid,
    );

    if (!mounted) return;

    final mensaje = eliminado
        ? _viewModel.mensajeExito ?? 'Mantenimiento eliminado.'
        : _viewModel.mensajeError ?? 'No se pudo eliminar el mantenimiento.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: eliminado ? AppTheme.cfeGreen : AppTheme.errorRed,
        ),
      );

    _viewModel.limpiarMensajes();
  }

  int? _obtenerProximoPreventivo(
    VehiculoModel vehiculo,
    List<MantenimientoModel> mantenimientos,
  ) {
    final intervalo = vehiculo.intervaloPreventivo;

    final programados = mantenimientos.where((mantenimiento) {
      return mantenimiento.tipoMantenimiento == 'preventivo' &&
          !mantenimiento.estaRealizado &&
          mantenimiento.kilometrajeProgramado != null &&
          mantenimiento.kilometrajeProgramado! > 0;
    }).toList();

    if (programados.isNotEmpty) {
      programados.sort(
        (a, b) => a.kilometrajeProgramado!
            .compareTo(b.kilometrajeProgramado!),
      );

      return programados.first.kilometrajeProgramado;
    }

    final realizados = mantenimientos.where((mantenimiento) {
      return mantenimiento.tipoMantenimiento == 'preventivo' &&
          mantenimiento.estaRealizado &&
          mantenimiento.kilometrajeRealizado != null;
    }).toList();

    if (realizados.isNotEmpty && intervalo > 0) {
      realizados.sort((a, b) {
        return b.kilometrajeRealizado!.compareTo(
          a.kilometrajeRealizado!,
        );
      });

      return realizados.first.kilometrajeRealizado! + intervalo;
    }

    final kilometrajeBase = vehiculo.kilometrajeBasePreventivo;
    if (kilometrajeBase != null && intervalo > 0) {
      return kilometrajeBase + intervalo;
    }

    return null;
  }

  Widget _mostrarAvisoPreventivo(
    VehiculoModel vehiculo,
    List<MantenimientoModel> mantenimientos,
  ) {
    final proximo = _obtenerProximoPreventivo(vehiculo, mantenimientos);

    if (proximo == null) {
      return const SizedBox.shrink();
    }

    final faltan = proximo - vehiculo.kilometrajeActual;
    final vencido = faltan <= 0;

    return Card(
      color: vencido ? AppTheme.errorSurface : AppTheme.warningSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              vencido ? Icons.error_outline : Icons.access_time,
              color: vencido ? AppTheme.errorRed : AppTheme.warningText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vencido
                        ? 'Mantenimiento preventivo vencido'
                        : 'Próximo preventivo: $proximo km',
                    style: TextStyle(
                      color: vencido
                          ? AppTheme.errorRed
                          : AppTheme.warningText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vencido
                        ? 'Se excedió por ${faltan.abs()} km · '
                            'kilometraje actual: '
                            '${vehiculo.kilometrajeActual} km'
                        : 'Faltan $faltan km · kilometraje actual: '
                            '${vehiculo.kilometrajeActual} km',
                    style: TextStyle(
                      color: vencido
                          ? AppTheme.errorRed
                          : AppTheme.warningText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaMantenimiento(
    MantenimientoModel mantenimiento,
    VehiculoModel vehiculo,
  ) {
    final colorFondo = _colorFondoTipo(mantenimiento.tipoMantenimiento);
    final colorTexto = _colorTextoTipo(mantenimiento.tipoMantenimiento);

    return Card(
      color: AppTheme.pureWhite,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      backgroundColor: colorFondo,
                      label: Text(
                        _nombreTipo(mantenimiento.tipoMantenimiento),
                        style: TextStyle(
                          color: colorTexto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Chip(
                      backgroundColor: AppTheme.roleSurface,
                      label: Text(
                        _nombreModulo(mantenimiento.modulo),
                        style: const TextStyle(
                          color: AppTheme.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _fecha(mantenimiento.fechaRealizado),
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mantenimiento.trabajoRealizado.isEmpty
                  ? 'Mantenimiento Programado'
                  : mantenimiento.trabajoRealizado,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (mantenimiento.categoriaPrueba.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Categoría PEMP: ${mantenimiento.categoriaPrueba}',
                style: const TextStyle(color: AppTheme.primaryText),
              ),
            ],
            if (mantenimiento.detalleRefacciones.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Refacciones: ${mantenimiento.detalleRefacciones.map(
                  (pieza) => '${pieza.nombre} ×${pieza.cantidad}',
                ).join(', ')}',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                if (mantenimiento.kilometrajeRealizado != null)
                  Text(
                    '${mantenimiento.kilometrajeRealizado} km',
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (mantenimiento.horometro != null)
                  Text(
                    '${mantenimiento.horometro} h de horómetro',
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                    ),
                  ),
                if (mantenimiento.costo > 0)
                  Text(
                    '\$${mantenimiento.costo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (mantenimiento.proveedor.isNotEmpty)
                  Text(
                    'Responsable: ${mantenimiento.proveedor}',
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                    ),
                  ),
              ],
            ),
            if (mantenimiento.fechaCaducidadLlantas != null ||
                mantenimiento.vidaUtilLlantas != null ||
                mantenimiento.nivelDesgasteLlantas != null) ...[
              const SizedBox(height: 10),
              const Text(
                'Control de llantas',
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (mantenimiento.fechaCaducidadLlantas != null)
                Text(
                  'Caducidad: '
                  '${_fecha(mantenimiento.fechaCaducidadLlantas!)}',
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
              if (mantenimiento.vidaUtilLlantas != null)
                Text(
                  'Vida útil: ${mantenimiento.vidaUtilLlantas} km',
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
              if (mantenimiento.nivelDesgasteLlantas != null)
                Text(
                  'Desgaste: ${mantenimiento.nivelDesgasteLlantas}%',
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
            ],
            if (mantenimiento.observaciones.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Observaciones: ${mantenimiento.observaciones}',
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ],
            const Divider(height: 24, color: AppTheme.border),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _abrirFormulario(
                    vehiculo: vehiculo,
                    mantenimiento: mantenimiento,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmarEliminacion(mantenimiento),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensaje(String texto, {bool error = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: error ? AppTheme.errorRed : AppTheme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _construirContenido({
    required bool esOperador,
    required List<VehiculoModel> vehiculos,
  }) {
    if (vehiculos.isEmpty) {
      return _mensaje(
        esOperador
            ? 'No tienes un vehículo asignado para consultar mantenimientos.'
            : 'No hay vehículos registrados.',
      );
    }

    if (esOperador && vehiculos.length > 1) {
      return _mensaje(
        'Tu cuenta tiene más de un vehículo asignado. '
        'Contacta al administrador para corregirlo.',
        error: true,
      );
    }

    VehiculoModel? vehiculoSeleccionado;

    for (final vehiculo in vehiculos) {
      if (vehiculo.uid == _vehiculoSeleccionadoUid) {
        vehiculoSeleccionado = vehiculo;
        break;
      }
    }

    vehiculoSeleccionado ??= vehiculos.first;

    return LayoutBuilder(
      builder: (context, limites) {
        final ancho = math.min(limites.maxWidth, 950.0);

        return Center(
          child: SizedBox(
            width: ancho,
            height: limites.maxHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).size.width < 600 ? 88 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (esOperador)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Vehículo asignado',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      child: Text(_nombreVehiculo(vehiculoSeleccionado!)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: vehiculoSeleccionado!.uid,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vehículo',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: vehiculos.map((vehiculo) {
                        return DropdownMenuItem<String>(
                          value: vehiculo.uid,
                          child: Text(
                            _nombreVehiculo(vehiculo),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (uid) {
                        setState(() {
                          _vehiculoSeleccionadoUid = uid;
                          _filtroSeleccionado = 'todos';
                        });
                      },
                    ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: StreamBuilder<List<MantenimientoModel>>(
                      stream: _viewModel.obtenerMantenimientos(
                        vehiculoUid: vehiculoSeleccionado.uid,
                      ),
                      builder: (context, mantenimientoSnapshot) {
                        if (mantenimientoSnapshot.hasError) {
                          return _mensaje(
                            'No se pudo cargar el historial. '
                            'Revisa tu conexión o los permisos de tu cuenta.',
                            error: true,
                          );
                        }

                        if (mantenimientoSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !mantenimientoSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.cfeGreen,
                            ),
                          );
                        }

                        final todos = mantenimientoSnapshot.data ?? [];

                        final filtrados = todos.where((mantenimiento) {
                          return _filtroSeleccionado == 'todos' ||
                              mantenimiento.tipoMantenimiento ==
                                  _filtroSeleccionado;
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _mostrarAvisoPreventivo(
                              vehiculoSeleccionado!,
                              todos,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Historial de mantenimientos',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppTheme.primaryText,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _filtros.map((filtro) {
                                  final seleccionado =
                                      _filtroSeleccionado == filtro['valor'];

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(filtro['texto']!),
                                      selected: seleccionado,
                                      selectedColor: AppTheme.cfeGreen,
                                      backgroundColor: AppTheme.roleSurface,
                                      labelStyle: TextStyle(
                                        color: seleccionado
                                            ? AppTheme.pureWhite
                                            : AppTheme.primaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      onSelected: (_) {
                                        setState(() {
                                          _filtroSeleccionado =
                                              filtro['valor']!;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: filtrados.isEmpty
                                  ? _mensaje(
                                      todos.isEmpty
                                          ? 'Este vehículo todavía no tiene mantenimientos.'
                                          : 'No hay registros para este filtro.',
                                    )
                                  : ListView.builder(
                                      itemCount: filtrados.length,
                                      itemBuilder: (context, index) {
                                        return _tarjetaMantenimiento(
                                          filtrados[index],
                                          vehiculoSeleccionado!,
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _esOperadorFuture,
      builder: (context, rolSnapshot) {
        final esOperador = rolSnapshot.data ?? true;

        return StreamBuilder<List<VehiculoModel>>(
          stream: _vehiculosStream,
          builder: (context, vehiculosSnapshot) {
            final vehiculos = vehiculosSnapshot.data ?? [];

            VehiculoModel? vehiculoSeleccionado;

            for (final vehiculo in vehiculos) {
              if (vehiculo.uid == _vehiculoSeleccionadoUid) {
                vehiculoSeleccionado = vehiculo;
                break;
              }
            }

            vehiculoSeleccionado ??=
                vehiculos.length == 1 ? vehiculos.first : null;

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Regresar',
                  onPressed: _regresar,
                  icon: const Icon(Icons.arrow_back),
                ),
                title: const Text('Mantenimientos'),
              ),
              floatingActionButton: vehiculoSeleccionado == null
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _abrirFormulario(
                        vehiculo: vehiculoSeleccionado!,
                      ),
                      backgroundColor: AppTheme.accentYellow,
                      foregroundColor: AppTheme.accentText,
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Registrar mantenimiento',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              body: SafeArea(
                child: rolSnapshot.connectionState == ConnectionState.waiting ||
                        (vehiculosSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !vehiculosSnapshot.hasData)
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.cfeGreen,
                        ),
                      )
                    : vehiculosSnapshot.hasError
                        ? _mensaje(
                            'No se pudieron cargar los vehículos. '
                            'Revisa tu conexión y los permisos de tu cuenta.',
                            error: true,
                          )
                        : _construirContenido(
                            esOperador: esOperador,
                            vehiculos: vehiculos,
                          ),
              ),
            );
          },
        );
      },
    );
  }
}
