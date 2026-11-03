import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';
import 'form_mantenimiento_view.dart';

// Pantalla que presenta los mantenimientos de los vehículos.
class MantenimientoView extends StatefulWidget {
  // Crea la pantalla de mantenimientos.
  // Entradas: key opcional y lista de vehículos requerida por la ruta.
  // Salida: una instancia de MantenimientoView.
  const MantenimientoView({
    super.key,
    required List<dynamic> vehiculos,
  });

  // Crea el estado asociado a la pantalla.
  // Entrada: ninguna.
  // Salida: el estado que administra el historial y sus filtros.
  @override
  State<MantenimientoView> createState() => _MantenimientoViewState();
}

// Estado y comportamiento de la pantalla de mantenimientos.
class _MantenimientoViewState extends State<MantenimientoView> {
  // ViewModel que consulta y administra mantenimientos.
  final MantenimientoViewModel _viewModel = MantenimientoViewModel();

  // Flujo de vehículos que alimenta el selector.
  late final Stream<List<VehiculoModel>> _vehiculosStream;

  // Identificador del vehículo seleccionado.
  String? _vehiculoSeleccionadoUid;

  // Tipo de mantenimiento seleccionado para filtrar el historial.
  String _filtroSeleccionado = 'todos';

  // Opciones de filtro disponibles en el historial.
  final List<Map<String, String>> _filtros = const [
    {'valor': 'todos', 'texto': 'Todos'},
    {'valor': 'preventivo', 'texto': 'Preventivo'},
    {'valor': 'correctivo', 'texto': 'Correctivo'},
    {'valor': 'prueba', 'texto': 'Pruebas PEMP'},
  ];

  // Inicializa el flujo de vehículos al crear el estado.
  // Entrada: ninguna.
  // Salida: ninguna; prepara el flujo que usa el selector de vehículos.
  @override
  void initState() {
    super.initState();
    _vehiculosStream = _viewModel.obtenerVehiculos();
  }

  // Libera el ViewModel al cerrar la pantalla.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // Regresa a la pantalla anterior o a la página principal del administrador.
  // Entrada: ninguna.
  // Salida: ninguna; realiza la navegación correspondiente.
  void _regresar() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.adminHome,
        (route) => false,
      );
    }
  }

  // Construye una descripción breve del vehículo.
  // Entrada: vehiculo cuyos datos se combinarán.
  // Salida: número económico, marca, modelo y año en un solo texto.
  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.numeroEconomico} · '
        '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}';
  }

  // Convierte el nombre interno del módulo en una etiqueta legible.
  // Entrada: modulo guardado en el registro.
  // Salida: nombre del módulo para mostrar en la interfaz.
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

  // Convierte el tipo interno del mantenimiento en una etiqueta legible.
  // Entrada: tipo guardado en el registro.
  // Salida: nombre del tipo para mostrar en la interfaz.
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

  // Da formato a una fecha para mostrarla en el historial.
  // Entrada: fecha que se desea presentar.
  // Salida: texto con día, mes abreviado y año.
  String _fecha(DateTime fecha) {
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

  // Obtiene el color de fondo correspondiente al tipo de mantenimiento.
  // Entrada: tipo de mantenimiento.
  // Salida: color de fondo asociado al tipo.
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

  // Obtiene el color de texto correspondiente al tipo de mantenimiento.
  // Entrada: tipo de mantenimiento.
  // Salida: color de texto asociado al tipo.
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

  // Abre el formulario para registrar o editar un mantenimiento.
  // Entradas: vehiculo requerido y mantenimiento opcional para editar.
  // Salida: ninguna; abre el formulario correspondiente.
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

  // Pide confirmación antes de eliminar un mantenimiento.
  // Entrada: mantenimiento que se desea eliminar.
  // Salida: ninguna; elimina el registro si se confirma y muestra el resultado.
  Future<void> _confirmarEliminacion(
    MantenimientoModel mantenimiento,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar mantenimiento'),
          content: const Text(
            '¿Quieres eliminar este registro? '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(context, true),
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

  // Calcula el próximo kilometraje programado para mantenimiento preventivo.
  // Entradas: vehiculo y lista de mantenimientos relacionados.
  // Salida: kilometraje del próximo preventivo o null si no puede calcularse.
  int? _obtenerProximoPreventivo(
    VehiculoModel vehiculo,
    List<MantenimientoModel> mantenimientos,
  ) {
    final kilometrajeActual = vehiculo.kilometrajeActual;
    final intervalo = vehiculo.intervaloPreventivo;

    final programados = mantenimientos.where((mantenimiento) {
      return mantenimiento.tipoMantenimiento == 'preventivo' &&
          mantenimiento.kilometrajeProgramado != null &&
          mantenimiento.kilometrajeProgramado! > kilometrajeActual;
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
          mantenimiento.kilometrajeRealizado != null;
    }).toList();

    if (realizados.isNotEmpty && intervalo > 0) {
      realizados.sort(
        (a, b) => b.fechaRealizado.compareTo(a.fechaRealizado),
      );

      return realizados.first.kilometrajeRealizado! + intervalo;
    }

    if (intervalo > 0) {
      return kilometrajeActual + intervalo;
    }

    return null;
  }

  // Construye un aviso sobre el próximo mantenimiento preventivo.
  // Entradas: vehiculo y lista de mantenimientos relacionados.
  // Salida: tarjeta informativa o un widget vacío si no hay un próximo servicio.
  Widget _mostrarAvisoPreventivo(
    VehiculoModel vehiculo,
    List<MantenimientoModel> mantenimientos,
  ) {
    final proximo = _obtenerProximoPreventivo(
      vehiculo,
      mantenimientos,
    );

    if (proximo == null) {
      return const SizedBox.shrink();
    }

    final faltan = proximo - vehiculo.kilometrajeActual;
    final vencido = faltan < 0;

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
                        : 'Faltan $faltan km · '
                            'kilometraje actual: '
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

  // Construye una tarjeta con los datos de un mantenimiento.
  // Entradas: mantenimiento que se mostrará y vehículo relacionado.
  // Salida: tarjeta con detalles, fecha y acciones para editar o eliminar.
  Widget _tarjetaMantenimiento(
    MantenimientoModel mantenimiento,
    VehiculoModel vehiculo,
  ) {
    final colorFondo = _colorFondoTipo(
      mantenimiento.tipoMantenimiento,
    );
    final colorTexto = _colorTextoTipo(
      mantenimiento.tipoMantenimiento,
    );

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
                  ? 'Registro de prueba PEMP'
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
                style: const TextStyle(
                  color: AppTheme.primaryText,
                ),
              ),
            ],
            if (mantenimiento.detalleRefacciones.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Refacciones: '
                '${mantenimiento.detalleRefacciones.map((pieza) => '${pieza.nombre} ×${pieza.cantidad}').join(', ')}',
                style: const TextStyle(
                  color: AppTheme.secondaryText,
                ),
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
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                  ),
                ),
              if (mantenimiento.vidaUtilLlantas != null)
                Text(
                  'Vida útil: ${mantenimiento.vidaUtilLlantas} km',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                  ),
                ),
              if (mantenimiento.nivelDesgasteLlantas != null)
                Text(
                  'Desgaste: ${mantenimiento.nivelDesgasteLlantas}%',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                  ),
                ),
            ],
            if (mantenimiento.observaciones.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Observaciones: ${mantenimiento.observaciones}',
                style: const TextStyle(
                  color: AppTheme.secondaryText,
                ),
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

  // Construye la pantalla con el selector de vehículo y su historial.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets del módulo de mantenimientos.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VehiculoModel>>(
      stream: _vehiculosStream,
      builder: (context, vehiculosSnapshot) {
        final cargandoVehiculos =
            vehiculosSnapshot.connectionState == ConnectionState.waiting;

        final vehiculos = vehiculosSnapshot.data ?? [];

        VehiculoModel? vehiculoSeleccionado;

        if (vehiculos.isNotEmpty) {
          final seleccionados = vehiculos.where(
            (vehiculo) => vehiculo.uid == _vehiculoSeleccionadoUid,
          );

          if (seleccionados.isNotEmpty) {
            vehiculoSeleccionado = seleccionados.first;
          } else {
            vehiculoSeleccionado = vehiculos.first;
            _vehiculoSeleccionadoUid = vehiculoSeleccionado.uid;
          }
        }

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
                  foregroundColor: Colors.black87,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Registrar mantenimiento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
          body: SafeArea(
            child: cargandoVehiculos
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : vehiculosSnapshot.hasError
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No se pudieron cargar los vehículos. '
                            'Revisa tu conexión e inténtalo de nuevo.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : vehiculos.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron vehículos en la colección '
                              '"vehiculo" de Firestore.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, limites) {
                              final ancho = math.min(
                                limites.maxWidth,
                                950.0,
                              );

                              return Center(
                                child: SizedBox(
                                  width: ancho,
                                  height: limites.maxHeight,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      88,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value: _vehiculoSeleccionadoUid,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Vehículo',
                                            prefixIcon: Icon(
                                              Icons.local_shipping_outlined,
                                            ),
                                          ),
                                          items: vehiculos.map((vehiculo) {
                                            return DropdownMenuItem<String>(
                                              value: vehiculo.uid,
                                              child: Text(
                                                _nombreVehiculo(vehiculo),
                                                overflow:
                                                    TextOverflow.ellipsis,
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
                                        if (vehiculoSeleccionado != null)
                                          Expanded(
                                            child: StreamBuilder<
                                                List<MantenimientoModel>>(
                                              stream: _viewModel
                                                  .obtenerMantenimientos(
                                                vehiculoUid:
                                                    vehiculoSeleccionado.uid,
                                              ),
                                              builder: (
                                                context,
                                                mantenimientoSnapshot,
                                              ) {
                                                if (mantenimientoSnapshot
                                                    .hasError) {
                                                  return const Center(
                                                    child: Text(
                                                      'No se pudo cargar el '
                                                      'historial.',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  );
                                                }

                                                if (mantenimientoSnapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting &&
                                                    !mantenimientoSnapshot
                                                        .hasData) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                }

                                                final todos =
                                                    mantenimientoSnapshot
                                                            .data ??
                                                        [];

                                                final filtrados = todos
                                                    .where(
                                                  (mantenimiento) {
                                                    return _filtroSeleccionado ==
                                                            'todos' ||
                                                        mantenimiento
                                                                .tipoMantenimiento ==
                                                            _filtroSeleccionado;
                                                  },
                                                ).toList();

                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
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
                                                            color: AppTheme
                                                                .primaryText,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      child: Row(
                                                        children: _filtros
                                                            .map((filtro) {
                                                          final seleccionado =
                                                              _filtroSeleccionado ==
                                                                  filtro[
                                                                      'valor'];

                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              right: 8,
                                                            ),
                                                            child: ChoiceChip(
                                                              label: Text(
                                                                filtro[
                                                                    'texto']!,
                                                              ),
                                                              selected:
                                                                  seleccionado,
                                                              selectedColor:
                                                                  AppTheme
                                                                      .cfeGreen,
                                                              backgroundColor:
                                                                  AppTheme
                                                                      .roleSurface,
                                                              labelStyle:
                                                                  TextStyle(
                                                                color: seleccionado
                                                                    ? AppTheme
                                                                        .pureWhite
                                                                    : AppTheme
                                                                        .primaryText,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              onSelected: (_) {
                                                                setState(() {
                                                                  _filtroSeleccionado =
                                                                      filtro[
                                                                          'valor']!;
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
                                                          ? Center(
                                                              child: Text(
                                                                todos.isEmpty
                                                                    ? 'Este vehículo todavía no tiene mantenimientos.'
                                                                    : 'No hay registros para este filtro.',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    const TextStyle(
                                                                  color: AppTheme
                                                                      .secondaryText,
                                                                ),
                                                              ),
                                                            )
                                                          : ListView.builder(
                                                              itemCount:
                                                                  filtrados
                                                                      .length,
                                                              itemBuilder:
                                                                  (context,
                                                                      index) {
                                                                return _tarjetaMantenimiento(
                                                                  filtrados[
                                                                      index],
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
                          ),
          ),
        );
      },
    );
  }
}