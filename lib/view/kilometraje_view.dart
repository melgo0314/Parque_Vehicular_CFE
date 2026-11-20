
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/kilometraje_model.dart';
import '../models/vehiculos_model.dart';
import '../view/form_kilometraje_view.dart';
import '../viewmodel/kilometraje_viewmodel.dart';

// Pantalla que muestra y administra jornadas de kilometraje.
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
  bool _eliminando = false;

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

  // Carga los vehículos y escucha sus cambios.
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
              !_vehiculos.any(
                (vehiculo) => vehiculo.uid == _vehiculoUid,
              )) {
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

  // Abre el formulario para iniciar o finalizar una jornada.
  Future<void> _abrirFormulario({
    KilometrajeModel? registro,
  }) async {
    if (_cargandoVehiculos) {
      _mostrarMensaje('Espera mientras se cargan los vehículos.');
      return;
    }

    final vehiculosDisponibles = _vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();

    if (vehiculosDisponibles.isEmpty) {
      _mostrarMensaje(
        _errorVehiculos ?? 'No hay vehículos disponibles.',
        esError: true,
      );
      return;
    }

    final vehiculoUid = registro?.vehiculoUid ?? _vehiculoUid;

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => FormKilometrajeView(
          vehiculos: vehiculosDisponibles,
          vehiculoUidInicial: vehiculoUid,
          registro: registro,
        ),
      ),
    );

    if (!mounted || resultado != true) return;

    _mostrarMensaje(
      registro == null
          ? 'El kilometraje se inició correctamente.'
          : registro.estaPendiente
              ? 'El kilometraje finalizó correctamente.'
              : 'El registro se actualizó correctamente.',
    );
  }

  // Abre el formulario para editar una jornada finalizada.
  Future<void> _editarRegistro(KilometrajeModel registro) async {
    if (registro.estaPendiente) {
      _mostrarMensaje(
        'Primero debes finalizar la jornada para poder editarla.',
        esError: true,
      );
      return;
    }

    await _abrirFormulario(registro: registro);
  }

  // Solicita confirmación antes de eliminar una jornada.
  Future<void> _eliminarRegistro(KilometrajeModel registro) async {
    if (_eliminando) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Registro'),
          content: Text(
            registro.estaPendiente
                ? '¿Deseas eliminar este registro pendiente? '
                    'El vehículo quedará disponible para iniciar otro.'
                : '¿Estás seguro de que deseas eliminar este registro? '
                    'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(100, 48),
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

    setState(() {
      _eliminando = true;
    });

    final eliminado = await _viewModel.eliminarKilometraje(registro.uid);

    if (!mounted) return;

    setState(() {
      _eliminando = false;
    });

    if (eliminado) {
      _mostrarMensaje('El kilometraje se eliminó correctamente.');
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo eliminar el registro.',
        esError: true,
      );
    }
  }

  // Muestra un mensaje de éxito o error.
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

  // Da formato a una fecha.
  String _formatearFecha(DateTime fecha) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];

    final dia = fecha.day.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia ${meses[fecha.month - 1]} ${fecha.year} · $hora:$minuto';
  }

  // Da formato a un kilometraje.
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

                          KilometrajeModel? jornadaPendiente;

                          for (final registro in registros) {
                            if (registro.estaPendiente) {
                              jornadaPendiente = registro;
                              break;
                            }
                          }

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
                                jornadaPendiente,
                              ),
                              const SizedBox(height: 14),

                              if (jornadaPendiente != null)
                                _tarjetaJornadaPendiente(jornadaPendiente),

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // La jornada pendiente se finaliza desde el mismo formulario.
          // Si no existe, se inicia una nueva.
          _abrirFormulario();
        },
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text(
          'Iniciar Kilometraje',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Construye un estado vacío o de error.
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

  // Construye el selector de vehículo.
  Widget _selectorVehiculo(List<VehiculoModel> vehiculos) {
    final valorSeleccionado = vehiculos.any(
      (vehiculo) => vehiculo.uid == _vehiculoUid,
    )
        ? _vehiculoUid
        : vehiculos.first.uid;

    return DropdownButtonFormField<String>(
      initialValue: valorSeleccionado,
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

  // Construye el resumen del kilometraje del vehículo.
  Widget _resumenKilometraje(
    VehiculoModel vehiculo,
    List<KilometrajeModel> registros,
    KilometrajeModel? jornadaPendiente,
  ) {
    final finalizados = registros.where((registro) {
      return registro.kilometrajeFinal != null;
    }).toList();

    final kilometrajeActual = jornadaPendiente != null
        ? jornadaPendiente.kilometrajeIni
        : finalizados.isNotEmpty
            ? finalizados.first.kilometrajeFinal!
            : vehiculo.kilometrajeActual;

    int variacion = 0;

    if (finalizados.length > 1) {
      variacion = finalizados.first.kilometrajeFinal! -
          finalizados.last.kilometrajeFinal!;
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
          Text(
            jornadaPendiente != null
                ? 'Kilometraje al inicio de jornada'
                : 'Kilometraje actual',
            style: const TextStyle(
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
                'Variación en el historial: ',
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

  // Muestra la jornada que todavía no ha finalizado.
  Widget _tarjetaJornadaPendiente(KilometrajeModel registro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border.all(color: AppTheme.accentYellow, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions,
                color: AppTheme.primaryText,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jornada en curso',
                  style: TextStyle(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                'PENDIENTE',
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Inicio: ${_formatearFecha(registro.fecha)}',
            style: const TextStyle(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 6),
          Text(
            'Kilometraje inicial: '
            '${_formatearKilometraje(registro.kilometrajeIni)} km',
            style: const TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _abrirFormulario(registro: registro),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Finalizar jornada'),
            ),
          ),
        ],
      ),
    );
  }

  // Construye una tarjeta con los datos de una jornada.
  Widget _tarjetaRegistro(KilometrajeModel registro) {
    final estaPendiente = registro.estaPendiente;

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
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppTheme.secondaryText,
                ),
                tooltip: 'Opciones de la jornada',
                enabled: !_eliminando,
                onSelected: (opcion) {
                  if (opcion == 'finalizar') {
                    _abrirFormulario(registro: registro);
                  } else if (opcion == 'editar') {
                    _editarRegistro(registro);
                  } else if (opcion == 'eliminar') {
                    _eliminarRegistro(registro);
                  }
                },
                itemBuilder: (context) => [
                  if (estaPendiente)
                    const PopupMenuItem<String>(
                      value: 'finalizar',
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            color: AppTheme.cfeGreen,
                          ),
                          SizedBox(width: 10),
                          Text('Finalizar jornada'),
                        ],
                      ),
                    ),
                  if (!estaPendiente)
                    const PopupMenuItem<String>(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primaryText,
                          ),
                          SizedBox(width: 10),
                          Text('Editar'),
                        ],
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: AppTheme.errorRed,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: AppTheme.errorRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _datoKilometraje(
                  'Inicio',
                  registro.kilometrajeIni,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: estaPendiente
                    ? _datoPendiente()
                    : _datoKilometraje(
                        'Final',
                        registro.kilometrajeFinal!,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (estaPendiente)
            const Text(
              'Esta jornada todavía no tiene kilometraje final.',
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 13,
              ),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 18,
                  color: AppTheme.cfeGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recorrido: '
                  '${_formatearKilometraje(registro.distanciaRecorrida)} km',
                  style: const TextStyle(
                    color: AppTheme.cfeGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

          if (registro.observaciones.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              registro.observaciones,
              style: const TextStyle(color: AppTheme.secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  // Muestra un dato de kilometraje.
  Widget _datoKilometraje(String titulo, int kilometraje) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: AppTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatearKilometraje(kilometraje)} km',
          style: const TextStyle(
            color: AppTheme.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Muestra el espacio reservado para el kilometraje final pendiente.
  Widget _datoPendiente() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Final',
          style: TextStyle(
            color: AppTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Pendiente',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Muestra el mensaje cuando no hay jornadas registradas.
  Widget _vistaSinRegistros(VehiculoModel vehiculo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Todavía no hay jornadas de kilometraje para '
        '${vehiculo.numeroEconomico}.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.secondaryText),
      ),
    );
  }
}
