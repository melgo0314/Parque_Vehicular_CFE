import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/kilometraje_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/kilometraje_viewmodel.dart';

class FormKilometrajeView extends StatefulWidget {
  final List<VehiculoModel> vehiculos;
  final String? vehiculoUidInicial;

  const FormKilometrajeView({
    super.key,
    required this.vehiculos,
    this.vehiculoUidInicial,
  });

  @override
  State<FormKilometrajeView> createState() => _FormKilometrajeViewState();
}

class _FormKilometrajeViewState extends State<FormKilometrajeView> {
  final _formKey = GlobalKey<FormState>();
  final _viewModel = KilometrajeViewModel();

  final _kilometrajeController = TextEditingController();
  final _observacionesController = TextEditingController();

  StreamSubscription<List<KilometrajeModel>>? _suscripcionRegistros;

  String? _vehiculoUid;
  DateTime _fecha = DateTime.now();
  int _ultimoKilometraje = 0;
  bool _cargandoKilometraje = false;
  bool _guardando = false;

  List<VehiculoModel> get _vehiculosDisponibles {
    return widget.vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();
  }

  VehiculoModel? get _vehiculoSeleccionado {
    for (final vehiculo in _vehiculosDisponibles) {
      if (vehiculo.uid == _vehiculoUid) {
        return vehiculo;
      }
    }

    return null;
  }

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

  @override
  void dispose() {
    _suscripcionRegistros?.cancel();
    _kilometrajeController.dispose();
    _observacionesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

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

        _formKey.currentState?.validate();
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _cargandoKilometraje = false;
        });
      },
    );
  }

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

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

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

  String _formatearNumero(int numero) {
    return numero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (coincidencia) => '${coincidencia[1]},',
        );
  }

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

  Widget _contenidoFormulario() {
    final vehiculo = _vehiculoSeleccionado;

    return Form(
      key: _formKey,
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
            autovalidateMode: AutovalidateMode.onUserInteraction,
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

          // El parámetro se usa para que el dropdown pueda actualizar
          // el vehículo seleccionado cuando se cambia.
          if (vehiculo == null) const SizedBox.shrink(),
        ],
      ),
    );
  }

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
        body: SafeArea(child: _vistaSinVehiculos()),
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