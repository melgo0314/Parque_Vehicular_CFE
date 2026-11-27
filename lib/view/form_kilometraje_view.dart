import 'dart:async';

import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/kilometraje_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/kilometraje_viewmodel.dart';

// Formulario para iniciar, finalizar o editar una jornada.
class FormKilometrajeView extends StatefulWidget {
  final List<VehiculoModel> vehiculos;
  final String? vehiculoUidInicial;
  final KilometrajeModel? registro;

  const FormKilometrajeView({
    super.key,
    required this.vehiculos,
    this.vehiculoUidInicial,
    this.registro,
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
  bool _intentoGuardar = false;

  bool get _estaIniciando => widget.registro == null;

  bool get _estaFinalizando {
    return widget.registro != null && widget.registro!.kilometrajeFinal == null;
  }

  bool get _estaEditando {
    return widget.registro != null && widget.registro!.kilometrajeFinal != null;
  }

  // Vehículos con identificador válido.
  List<VehiculoModel> get _vehiculosDisponibles {
    return widget.vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();
  }

  // Vehículo seleccionado.
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

    if (widget.registro != null) {
      final registro = widget.registro!;

      _vehiculoUid = registro.vehiculoUid;
      _fecha = registro.fecha;
      _ultimoKilometraje = registro.kilometrajeIni;

      _kilometrajeController.text = registro.kilometrajeFinal?.toString() ?? '';

      _observacionesController.text = registro.observaciones;
    } else if (_vehiculosDisponibles.isNotEmpty) {
      final uidInicial = widget.vehiculoUidInicial;

      if (uidInicial != null &&
          _vehiculosDisponibles.any((vehiculo) => vehiculo.uid == uidInicial)) {
        _vehiculoUid = uidInicial;
      } else {
        _vehiculoUid = _vehiculosDisponibles.first.uid;
      }
    }

    if (_estaIniciando && _vehiculoSeleccionado != null) {
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

  // Consulta la última lectura de una jornada finalizada.
  void _escucharUltimoKilometraje() {
    _suscripcionRegistros?.cancel();

    final vehiculo = _vehiculoSeleccionado;
    if (vehiculo == null) return;

    setState(() {
      _cargandoKilometraje = true;
    });

    _suscripcionRegistros = _viewModel
        .obtenerRegistros(vehiculoUid: vehiculo.uid)
        .listen(
          (registros) {
            final finalizados = registros.where((registro) {
              return registro.kilometrajeFinal != null;
            }).toList();

            finalizados.sort((a, b) => b.fecha.compareTo(a.fecha));

            int ultimo = vehiculo.kilometrajeActual;

            if (finalizados.isNotEmpty &&
                finalizados.first.kilometrajeFinal! > ultimo) {
              ultimo = finalizados.first.kilometrajeFinal!;
            }

            if (!mounted) return;

            setState(() {
              _ultimoKilometraje = ultimo;
              _cargandoKilometraje = false;

              // Se coloca la última lectura como sugerencia inicial.
              if (_kilometrajeController.text.isEmpty) {
                _kilometrajeController.text = ultimo.toString();
              }
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

  // Da formato a una fecha.
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
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia ${meses[fecha.month - 1]} ${fecha.year} · $hora:$minuto';
  }

  // Valida la lectura que se está capturando.
  String? _validarKilometraje(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el kilometraje.';
    }

    final kilometraje = int.tryParse(valor.trim());

    if (kilometraje == null || kilometraje < 0) {
      return 'Ingresa un kilometraje válido.';
    }

    if (_estaIniciando && kilometraje < _ultimoKilometraje) {
      return 'El kilometraje no puede ser menor a la última lectura '
          '(${_formatearNumero(_ultimoKilometraje)} km).';
    }

    if (!_estaIniciando && kilometraje <= _ultimoKilometraje) {
      return 'El kilometraje final debe ser mayor a la lectura inicial '
          '(${_formatearNumero(_ultimoKilometraje)} km).';
    }

    return null;
  }

  // Guarda el inicio, finalización o modificación de una jornada.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _intentoGuardar = true;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final kilometraje = int.tryParse(_kilometrajeController.text.trim());

    if (kilometraje == null) return;

    setState(() {
      _guardando = true;
    });

    bool guardado = false;

    if (_estaIniciando) {
      final vehiculo = _vehiculoSeleccionado;

      if (vehiculo == null) {
        _mostrarMensaje('Selecciona un vehículo.');
        setState(() => _guardando = false);
        return;
      }

      final registro = KilometrajeModel(
        uid: '',
        vehiculoUid: vehiculo.uid,
        rpeUsuario: '',
        fecha: DateTime.now(),
        kilometrajeIni: kilometraje,
        kilometrajeFinal: null,
        observaciones: _observacionesController.text.trim(),
      );

      guardado = await _viewModel.registrarKilometraje(registro);
    } else if (_estaFinalizando) {
      final registro = widget.registro!;

      guardado = await _viewModel.finalizarKilometraje(
        uid: registro.uid,
        kilometrajeFinal: kilometraje,
        observaciones: _observacionesController.text.trim(),
      );
    } else if (_estaEditando) {
      final original = widget.registro!;

      final registro = KilometrajeModel(
        uid: original.uid,
        vehiculoUid: original.vehiculoUid,
        rpeUsuario: original.rpeUsuario,
        fecha: original.fecha,
        fechaFin: original.fechaFin ?? DateTime.now(),
        kilometrajeIni: original.kilometrajeIni,
        kilometrajeFinal: kilometraje,
        observaciones: _observacionesController.text.trim(),
      );

      guardado = await _viewModel.actualizarKilometraje(registro);
    }

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (!guardado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar la jornada.',
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  // Muestra mensajes de error.
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

  // Formatea números con separadores de miles.
  String _formatearNumero(int numero) {
    return numero.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (coincidencia) => '${coincidencia[1]},',
    );
  }

  // Muestra el formulario sin vehículos.
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

  // Construye los campos del formulario.
  Widget _contenidoFormulario() {
    final tituloKilometraje = _estaIniciando
        ? 'Kilometraje inicial'
        : 'Kilometraje final';

    final tituloBoton = _guardando
        ? 'Guardando…'
        : _estaIniciando
        ? 'Registrar Kilometraje'
        : _estaFinalizando
        ? 'Finalizar Kilometraje'
        : 'Guardar cambios';

    return Form(
      key: _formKey,
      autovalidateMode: _intentoGuardar
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos de la jornada',
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
            initialValue: _vehiculoUid,
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
            onChanged: _guardando || !_estaIniciando
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
            'Fecha de inicio',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            child: Text(
              _estaIniciando
                  ? _formatearFecha(DateTime.now())
                  : _formatearFecha(_fecha),
            ),
          ),

          const SizedBox(height: 16),

          if (!_estaIniciando) ...[
            const Text(
              'Kilometraje inicial',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.speed_outlined),
                suffixText: 'km',
              ),
              child: Text(
                '${_formatearNumero(_ultimoKilometraje)} km',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            tituloKilometraje,
            style: const TextStyle(
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: _estaIniciando
                  ? 'Ingresa la lectura al iniciar'
                  : 'Ingresa la lectura al finalizar',
              suffixText: 'km',
            ),
            validator: _validarKilometraje,
          ),

          const SizedBox(height: 6),

          Text(
            _cargandoKilometraje
                ? 'Consultando el último kilometraje...'
                : _estaIniciando
                ? 'Última lectura registrada: '
                      '${_formatearNumero(_ultimoKilometraje)} km'
                : 'Distancia recorrida: '
                      '${_formatearNumero((int.tryParse(_kilometrajeController.text) ?? 0) - _ultimoKilometraje)} km',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _observacionesController,
            enabled: !_guardando,
            minLines: 3,
            maxLines: 4,
            maxLength: 250,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Observaciones (opcional)',
              hintText: _estaIniciando
                  ? 'Ej. Inicio de jornada'
                  : 'Ej. Fin de jornada',
              alignLabelWithHint: true,
            ),
          ),

          if (_estaFinalizando) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.roleSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.cfeGreen),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Al finalizar, se actualizará el kilometraje actual '
                      'del vehículo.',
                      style: TextStyle(color: AppTheme.primaryText),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
                  : Icon(
                      _estaIniciando
                          ? Icons.play_arrow
                          : _estaFinalizando
                          ? Icons.flag_outlined
                          : Icons.check,
                    ),
              label: Text(
                tituloBoton,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _estaIniciando
        ? 'Iniciar Kilometraje'
        : _estaFinalizando
        ? 'Finalizar Kilometraje'
        : 'Editar kilometraje';

    if (_vehiculosDisponibles.isEmpty) {
      return Scaffold(
        bottomNavigationBar: const InicioFooter(),
        backgroundColor: AppTheme.pearlWhite,
        appBar: AppBar(
          backgroundColor: AppTheme.cfeGreen,
          foregroundColor: AppTheme.pureWhite,
          title: Text(titulo),
        ),
        body: SafeArea(child: _vistaSinVehiculos()),
      );
    }

    return Scaffold(
      bottomNavigationBar: const InicioFooter(),
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
