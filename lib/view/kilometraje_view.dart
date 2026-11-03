import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/kilometraje_model.dart';
import '../models/vehiculos_model.dart';
import '../view/form_kilometraje_view.dart';
import '../viewmodel/kilometraje_viewmodel.dart';

// Pantalla que muestra y administra registros de kilometraje.
class KilometrajeView extends StatefulWidget {
  // Lista inicial de vehículos recibida desde la pantalla anterior.
  final List<VehiculoModel> vehiculos;

  // Crea la pantalla de kilometraje.
  // Entradas: key opcional y lista inicial de vehículos.
  // Salida: una instancia de KilometrajeView.
  const KilometrajeView({
    super.key,
    required this.vehiculos,
  });

  // Crea el estado asociado a la pantalla.
  // Entrada: ninguna.
  // Salida: el estado que administra vehículos y registros.
  @override
  State<KilometrajeView> createState() => _KilometrajeViewState();
}

// Estado y comportamiento de la pantalla de kilometraje.
class _KilometrajeViewState extends State<KilometrajeView> {
  // ViewModel que consulta y administra los registros.
  final _viewModel = KilometrajeViewModel();

  // Lista actual de vehículos disponibles.
  late List<VehiculoModel> _vehiculos;

  // Suscripción a los cambios en la lista de vehículos.
  StreamSubscription<List<VehiculoModel>>? _suscripcionVehiculos;

  // Identificador del vehículo seleccionado.
  String? _vehiculoUid;

  // Mensaje de error al cargar vehículos, si ocurre.
  String? _errorVehiculos;

  // Indica si se están cargando los vehículos.
  bool _cargandoVehiculos = false;

  // Inicializa la pantalla con los vehículos recibidos o los consulta.
  // Entrada: ninguna.
  // Salida: ninguna; establece la lista y el vehículo seleccionado.
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

  // Carga los vehículos y escucha los cambios de la fuente de datos.
  // Entrada: ninguna.
  // Salida: ninguna; actualiza el estado de carga, la lista o el error.
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

  // Cancela la suscripción y libera el ViewModel al cerrar la pantalla.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _suscripcionVehiculos?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  // Abre el formulario para registrar un nuevo kilometraje.
  // Entrada: ninguna; utiliza la lista actual y el vehículo seleccionado.
  // Salida: ninguna; abre el formulario o muestra un mensaje si no hay vehículos.
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

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: texto que se presentará y esError para determinar el color.
  // Salida: ninguna; muestra un SnackBar en la pantalla actual.
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

  // Da formato a una fecha para mostrarla en el historial.
  // Entrada: fecha que se desea presentar.
  // Salida: fecha con el formato día, mes abreviado y año.
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

  // Da formato al kilometraje agregando separadores de miles.
  // Entrada: kilometraje que se desea mostrar.
  // Salida: kilometraje con comas para separar los millares.
  String _formatearKilometraje(int kilometraje) {
    return kilometraje.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

  // Construye la pantalla con selector de vehículo y su historial.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets del módulo de kilometraje.
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
      // El botón permanece visible; si no hay vehículos, el formulario
      // muestra un mensaje que explica el problema.
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

  // Construye un estado vacío o de error con icono y mensaje.
  // Entradas: icono que se mostrará y mensaje que se presentará.
  // Salida: un widget centrado con el icono y el mensaje.
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
  // Entrada: lista de vehículos disponibles.
  // Salida: un campo desplegable que actualiza el vehículo seleccionado.
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

  // Construye el resumen del kilometraje actual y su variación.
  // Entradas: vehiculo seleccionado y lista de registros de kilometraje.
  // Salida: tarjeta con el kilometraje actual y la variación del periodo.
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

  // Construye una tarjeta con los datos de un registro de kilometraje.
  // Entrada: registro que se mostrará.
  // Salida: tarjeta con fecha, lectura final, variación y observaciones.
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

  // Construye el mensaje que se muestra cuando no hay registros.
  // Entrada: vehiculo consultado.
  // Salida: un widget informativo con el número económico del vehículo.
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