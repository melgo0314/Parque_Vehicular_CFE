import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/kilometraje_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/kilometraje_viewmodel.dart';

// Formulario para registrar una lectura de kilometraje.
class FormKilometrajeView extends StatefulWidget {
  // Vehículos disponibles para seleccionar.
  final List<VehiculoModel> vehiculos;

  // Identificador inicial del vehículo seleccionado, si se proporciona.
  final String? vehiculoUidInicial;

  // Crea el formulario con los vehículos disponibles.
  // Entradas: key opcional, lista vehiculos requerida y vehiculoUidInicial opcional.
  // Salida: una instancia de FormKilometrajeView.
  const FormKilometrajeView({
    super.key,
    required this.vehiculos,
    this.vehiculoUidInicial,
  });

  // Crea el estado asociado al formulario.
  // Entrada: ninguna.
  // Salida: el estado que administra la captura del kilometraje.
  @override
  State<FormKilometrajeView> createState() => _FormKilometrajeViewState();
}

// Estado y comportamiento del formulario de kilometraje.
class _FormKilometrajeViewState extends State<FormKilometrajeView> {
  // Llave global para validar los campos del formulario.
  final _formKey = GlobalKey<FormState>();

  // ViewModel que consulta y registra lecturas de kilometraje.
  final _viewModel = KilometrajeViewModel();

  // Controlador para el kilometraje ingresado.
  final _kilometrajeController = TextEditingController();

  // Controlador para las observaciones del registro.
  final _observacionesController = TextEditingController();

  // Suscripción a los registros del vehículo seleccionado.
  StreamSubscription<List<KilometrajeModel>>? _suscripcionRegistros;

  // Identificador del vehículo seleccionado.
  String? _vehiculoUid;

  // Fecha elegida para el registro.
  DateTime _fecha = DateTime.now();

  // Última lectura conocida del vehículo seleccionado.
  int _ultimoKilometraje = 0;

  // Indica si se está consultando el último kilometraje.
  bool _cargandoKilometraje = false;

  // Indica si se está guardando el registro.
  bool _guardando = false;

  // Indica si el usuario ya intentó guardar el formulario.
  bool _intentoGuardar = false;

  // Devuelve los vehículos que tienen un identificador válido.
  // Entrada: ninguna; consulta la lista recibida por el widget.
  // Salida: lista de vehículos con uid no vacío.
  List<VehiculoModel> get _vehiculosDisponibles {
    return widget.vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();
  }

  // Busca el vehículo seleccionado actualmente.
  // Entrada: ninguna; utiliza el uid guardado en el estado.
  // Salida: vehículo seleccionado o null si no se encuentra.
  VehiculoModel? get _vehiculoSeleccionado {
    for (final vehiculo in _vehiculosDisponibles) {
      if (vehiculo.uid == _vehiculoUid) {
        return vehiculo;
      }
    }

    return null;
  }

  // Inicializa el vehículo seleccionado y consulta su última lectura.
  // Entrada: ninguna.
  // Salida: ninguna; configura el estado inicial del formulario.
  @override
  void initState() {
    super.initState();

    if (_vehiculosDisponibles.isNotEmpty) {
      final uidInicial = widget.vehiculoUidInicial;

      if (uidInicial != null &&
          _vehiculosDisponibles.any((vehiculo) => vehiculo.uid == uidInicial)) {
        _vehiculoUid = uidInicial;
      } else {
        _vehiculoUid = _vehiculosDisponibles.first.uid;
      }

      _escucharUltimoKilometraje();
    }
  }

  // Cancela la suscripción y libera los controladores y el ViewModel.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _suscripcionRegistros?.cancel();
    _kilometrajeController.dispose();
    _observacionesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // Escucha los registros del vehículo y obtiene la lectura más reciente.
  // Entrada: ninguna; utiliza el vehículo seleccionado.
  // Salida: ninguna; actualiza _ultimoKilometraje y el estado de carga.
  void _escucharUltimoKilometraje() {
    _suscripcionRegistros?.cancel();

    final vehiculo = _vehiculoSeleccionado;

    if (vehiculo == null) return;

    setState(() {
      _cargandoKilometraje = true;
      _ultimoKilometraje = vehiculo.kilometrajeActual;
    });

    _suscripcionRegistros = _viewModel
        .obtenerRegistros(vehiculoUid: vehiculo.uid)
        .listen(
      (registros) {
        registros.sort((a, b) => b.fecha.compareTo(a.fecha));

        int ultimo = vehiculo.kilometrajeActual;

        if (registros.isNotEmpty &&
            registros.first.kilometrajeFinal > ultimo) {
          ultimo = registros.first.kilometrajeFinal;
        }

        if (!mounted) return;

        setState(() {
          _ultimoKilometraje = ultimo;
          _cargandoKilometraje = false;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _cargandoKilometraje = false;
        });
      },
    );
  }

  // Abre el selector para elegir la fecha del registro.
  // Entrada: ninguna.
  // Salida: ninguna; actualiza _fecha cuando se selecciona una fecha.
  Future<void> _seleccionarFecha() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Selecciona la fecha del registro',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fechaSeleccionada != null && mounted) {
      setState(() {
        _fecha = fechaSeleccionada;
      });
    }
  }

  // Da formato a una fecha para mostrarla en el formulario.
  // Entrada: fecha que se desea presentar.
  // Salida: texto con día, mes abreviado y año.
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

  // Valida que el kilometraje sea entero y mayor que la última lectura.
  // Entrada: valor escrito en el campo de kilometraje.
  // Salida: mensaje de error si no es válido; de lo contrario, null.
  String? _validarKilometraje(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el kilometraje.';
    }

    final kilometraje = int.tryParse(valor.trim());

    if (kilometraje == null || kilometraje < 0) {
      return 'Ingresa un kilometraje válido.';
    }

    if (kilometraje <= _ultimoKilometraje) {
      return 'El kilometraje debe ser mayor al último registro '
          '(${_formatearNumero(_ultimoKilometraje)} km).';
    }

    return null;
  }

  // Valida y guarda un nuevo registro de kilometraje.
  // Entrada: ninguna; utiliza el vehículo y los valores del formulario.
  // Salida: ninguna; guarda el registro y cierra el formulario si tiene éxito.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    // Después del primer intento, muestra la validación mientras se corrigen
    // los campos del formulario.
    setState(() {
      _intentoGuardar = true;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final vehiculo = _vehiculoSeleccionado;
    final kilometrajeFinal = int.tryParse(
      _kilometrajeController.text.trim(),
    );

    if (vehiculo == null || kilometrajeFinal == null) {
      _mostrarMensaje('Selecciona un vehículo e ingresa el kilometraje.');
      return;
    }

    final registro = KilometrajeModel(
      uid: '',
      vehiculoUid: vehiculo.uid,
      // El repositorio obtiene el RPE de la sesión iniciada.
      rpeUsuario: '',
      fecha: _fecha,
      kilometrajeIni: _ultimoKilometraje,
      kilometrajeFinal: kilometrajeFinal,
      observaciones: _observacionesController.text.trim(),
    );

    setState(() {
      _guardando = true;
    });

    final guardado = await _viewModel.registrarKilometraje(registro);

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (!guardado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar el registro.',
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  // Muestra un mensaje flotante en la pantalla.
  // Entrada: mensaje que se presentará.
  // Salida: ninguna; muestra un SnackBar con el estilo de error.
  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // Da formato a un kilometraje agregando separadores de miles.
  // Entrada: numero que se desea presentar.
  // Salida: número con comas para separar los millares.
  String _formatearNumero(int numero) {
    return numero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

  // Construye el mensaje que se muestra si no hay vehículos disponibles.
  // Entrada: ninguna.
  // Salida: un widget informativo para el estado vacío.
  Widget _vistaSinVehiculos() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No hay vehículos disponibles para registrar kilometraje.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Construye los campos y controles del formulario.
  // Entrada: ninguna; utiliza los datos y el estado actuales.
  // Salida: un widget Form con los campos del registro.
  Widget _contenidoFormulario() {
    return Form(
      key: _formKey,
      autovalidateMode: _intentoGuardar
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos del registro',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Vehículo',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _vehiculoUid,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            items: _vehiculosDisponibles.map((vehiculo) {
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
            onChanged: _guardando
                ? null
                : (valor) {
                    if (valor == null) return;

                    setState(() {
                      _vehiculoUid = valor;
                      _kilometrajeController.clear();
                    });

                    _escucharUltimoKilometraje();
                  },
            validator: (valor) {
              if (valor == null || valor.isEmpty) {
                return 'Selecciona un vehículo.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Fecha',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _guardando ? null : _seleccionarFecha,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(_formatearFecha(_fecha)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kilometraje',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _kilometrajeController,
            enabled: !_guardando && !_cargandoKilometraje,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              hintText: 'Ingresa la lectura actual',
              suffixText: 'km',
            ),
            validator: _validarKilometraje,
          ),
          const SizedBox(height: 6),
          Text(
            _cargandoKilometraje
                ? 'Consultando el último kilometraje...'
                : 'Último registro: '
                    '${_formatearNumero(_ultimoKilometraje)} km',
            style: const TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _observacionesController,
            enabled: !_guardando,
            minLines: 3,
            maxLines: 4,
            maxLength: 250,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              hintText: 'Ej. Inicio de turno',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _guardando || _cargandoKilometraje ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.pureWhite,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _guardando ? 'Guardando…' : 'Guardar registro',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed:
                  _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  // Construye la pantalla del formulario o el estado sin vehículos.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets para registrar el kilometraje.
  @override
  Widget build(BuildContext context) {
    if (_vehiculosDisponibles.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.pearlWhite,
        appBar: AppBar(
          backgroundColor: AppTheme.cfeGreen,
          foregroundColor: AppTheme.pureWhite,
          title: const Text('Registrar kilometraje'),
        ),
        body: SafeArea(
          child: _vistaSinVehiculos(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Registrar kilometraje',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Card(
                color: AppTheme.pureWhite,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _contenidoFormulario(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}