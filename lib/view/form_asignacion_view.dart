import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/asignacion_model.dart';
import '../models/user_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/asignacion_viewmodel.dart';

class FormAsignacionView extends StatefulWidget {
  final AsignacionModel? asignacion;

  const FormAsignacionView({
    super.key,
    this.asignacion,
  });

  @override
  State<FormAsignacionView> createState() => _FormAsignacionViewState();
}

class _FormAsignacionViewState extends State<FormAsignacionView> {
  final _formKey = GlobalKey<FormState>();
  final _viewModel = AsignacionViewModel();
  final _otroMotivoController = TextEditingController();

  static const List<String> _motivos = [
    'Vacaciones del titular',
    'Incapacidad del titular',
    'Comisión del titular',
    'Ausencia del titular',
    'Otro',
  ];

  late Future<List<UserModel>> _operadoresFuture;
  late Future<List<VehiculoModel>> _vehiculosFuture;

  String? _operadorUid;
  String? _vehiculoUid;
  String _tipo = 'permanente';
  String? _motivoSeleccionado;
  DateTime _fechaInicio = DateTime.now();
  DateTime? _fechaFin;
  bool _guardando = false;

  bool get _esEdicion => widget.asignacion != null;
  bool get _esTemporal => _tipo == 'temporal';

  String get _motivoGuardado {
    if (_motivoSeleccionado == 'Otro') {
      return _otroMotivoController.text.trim();
    }
    return _motivoSeleccionado ?? '';
  }

  @override
  void initState() {
    super.initState();

    final asignacion = widget.asignacion;
    if (asignacion != null) {
      _operadorUid = asignacion.operadorUid;
      _vehiculoUid = asignacion.vehiculoUid;
      _tipo = asignacion.tipo;
      _fechaInicio = asignacion.fechaInicio;
      _fechaFin = asignacion.fechaFin;

      if (_motivos.contains(asignacion.motivoTemporal)) {
        _motivoSeleccionado = asignacion.motivoTemporal;
      } else if (asignacion.motivoTemporal.isNotEmpty) {
        _motivoSeleccionado = 'Otro';
        _otroMotivoController.text = asignacion.motivoTemporal;
      }
    }

    _cargarListas();
  }

  void _cargarListas() {
    final uidExcluir = widget.asignacion?.uid;

    _operadoresFuture = _viewModel.obtenerOperadoresDisponibles(
      excluirAsignacionUid: uidExcluir,
    );
    _vehiculosFuture = _viewModel.obtenerVehiculosDisponibles(
      excluirAsignacionUid: uidExcluir,
    );
  }

  @override
  void dispose() {
    _otroMotivoController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia $mes ${fecha.year}';
  }

  Future<void> _seleccionarFechaInicio() async {
    final hoy = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio.isAfter(hoy) ? hoy : _fechaInicio,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: 'Selecciona la fecha de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fecha == null || !mounted) return;

    setState(() {
      _fechaInicio = fecha;

      if (_fechaFin != null && _fechaFin!.isBefore(fecha)) {
        _fechaFin = null;
      }
    });
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? _fechaInicio,
      firstDate: _fechaInicio,
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha de término',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fecha != null && mounted) {
      setState(() => _fechaFin = fecha);
    }
  }

  void _cambiarTipo(String tipo) {
    setState(() {
      _tipo = tipo;

      if (tipo == 'permanente') {
        _fechaFin = null;
        _motivoSeleccionado = null;
        _otroMotivoController.clear();
      }
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_operadorUid == null || _vehiculoUid == null) {
      _mostrarMensaje(
        'Selecciona un operador y un vehículo.',
        error: true,
      );
      return;
    }

    if (_esTemporal && _fechaFin == null) {
      _mostrarMensaje(
        'Selecciona la fecha de término.',
        error: true,
      );
      return;
    }

    setState(() => _guardando = true);

    bool guardado;

    if (_esEdicion) {
      final asignacionActualizada = widget.asignacion!.copyWith(
        operadorUid: _operadorUid,
        vehiculoUid: _vehiculoUid,
        fechaInicio: _fechaInicio,
        fechaFin: _esTemporal ? _fechaFin : null,
        limpiarFechaFin: !_esTemporal,
        tipo: _tipo,
        motivoTemporal: _esTemporal ? _motivoGuardado : '',
        estado: _esTemporal ? 'temporal' : 'vigente',
      );

      guardado = await _viewModel.actualizarAsignacion(
        asignacionActualizada,
      );
    } else {
      guardado = await _viewModel.crearAsignacion(
        operadorUid: _operadorUid!,
        vehiculoUid: _vehiculoUid!,
        fechaInicio: _fechaInicio,
        tipo: _tipo,
        fechaFin: _esTemporal ? _fechaFin : null,
        motivoTemporal: _esTemporal ? _motivoGuardado : '',
      );
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (!guardado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar la asignación.',
        error: true,
      );
      return;
    }

    _mostrarMensaje(
      _viewModel.mensajeExito ?? 'La asignación se guardó correctamente.',
      error: false,
    );

    Navigator.of(context).pop(true);
  }

  void _mostrarMensaje(String mensaje, {required bool error}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? AppTheme.errorRed : AppTheme.cfeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _avisoTemporal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoSurface,
        border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.infoBlue,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asignación temporal',
                  style: TextStyle(
                    color: AppTheme.infoBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Al terminar la fecha de fin, la unidad regresa a su operador titular.',
                  style: TextStyle(
                    color: AppTheme.infoBlue,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cargandoLista(String etiqueta) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const Icon(Icons.hourglass_top),
      ),
      child: const LinearProgressIndicator(
        color: AppTheme.cfeGreen,
      ),
    );
  }

  Widget _errorLista({
    required String etiqueta,
    required VoidCallback reintentar,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const Icon(
          Icons.error_outline,
          color: AppTheme.errorRed,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'No se pudo cargar la lista. Revisa tu conexión.',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
          IconButton(
            tooltip: 'Reintentar',
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _selectorOperador() {
    return FutureBuilder<List<UserModel>>(
      future: _operadoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _cargandoLista('Operador');
        }

        if (snapshot.hasError) {
          return _errorLista(
            etiqueta: 'Operador',
            reintentar: () => setState(_cargarListas),
          );
        }

        final operadores = snapshot.data ?? [];

        if (operadores.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Operador',
              prefixIcon: Icon(Icons.person_outline),
            ),
            child: Text(
              'No hay operadores disponibles.',
              style: TextStyle(color: AppTheme.secondaryText),
            ),
          );
        }

        final operadorSeleccionado = operadores.any(
          (usuario) => usuario.uid == _operadorUid,
        )
            ? _operadorUid
            : null;

        return DropdownButtonFormField<String>(
          initialValue: operadorSeleccionado,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Operador',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: operadores.map((usuario) {
            return DropdownMenuItem<String>(
              value: usuario.uid,
              child: Text(
                usuario.nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          validator: (valor) {
            if (valor == null || valor.isEmpty) {
              return 'Selecciona un operador.';
            }
            return null;
          },
          onChanged: _guardando
              ? null
              : (valor) => setState(() => _operadorUid = valor),
        );
      },
    );
  }

  Widget _selectorVehiculo() {
    return FutureBuilder<List<VehiculoModel>>(
      future: _vehiculosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _cargandoLista('Vehículo');
        }

        if (snapshot.hasError) {
          return _errorLista(
            etiqueta: 'Vehículo',
            reintentar: () => setState(_cargarListas),
          );
        }

        final vehiculos = snapshot.data ?? [];

        if (vehiculos.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Vehículo',
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            child: Text(
              'No hay vehículos disponibles.',
              style: TextStyle(color: AppTheme.secondaryText),
            ),
          );
        }

        final vehiculoSeleccionado = vehiculos.any(
          (vehiculo) => vehiculo.uid == _vehiculoUid,
        )
            ? _vehiculoUid
            : null;

        return DropdownButtonFormField<String>(
          initialValue: vehiculoSeleccionado,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Vehículo',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          items: vehiculos.map((vehiculo) {
            final descripcion =
                '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}'.trim();

            return DropdownMenuItem<String>(
              value: vehiculo.uid,
              child: Text(
                '${descripcion.isEmpty ? 'Vehículo' : descripcion} · ${vehiculo.placas}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          validator: (valor) {
            if (valor == null || valor.isEmpty) {
              return 'Selecciona un vehículo.';
            }
            return null;
          },
          onChanged: _guardando
              ? null
              : (valor) => setState(() => _vehiculoUid = valor),
        );
      },
    );
  }

  Widget _selectorTipo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de asignación',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'permanente',
                label: Text('Permanente'),
              ),
              ButtonSegment<String>(
                value: 'temporal',
                label: Text('Temporal'),
              ),
            ],
            selected: {_tipo},
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(
                Size.fromHeight(48),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((estados) {
                if (estados.contains(WidgetState.selected)) {
                  return AppTheme.cfeGreen;
                }
                return AppTheme.roleSurface;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((estados) {
                if (estados.contains(WidgetState.selected)) {
                  return AppTheme.pureWhite;
                }
                return AppTheme.primaryText;
              }),
            ),
            onSelectionChanged: _guardando
                ? null
                : (seleccion) {
                    if (seleccion.isNotEmpty) {
                      _cambiarTipo(seleccion.first);
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _campoFecha({
    required String etiqueta,
    required DateTime? fecha,
    required VoidCallback alTocar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _guardando ? null : alTocar,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fecha == null
                          ? 'Selecciona una fecha'
                          : _formatearFecha(fecha),
                      style: TextStyle(
                        color: fecha == null
                            ? AppTheme.secondaryText
                            : AppTheme.primaryText,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: AppTheme.secondaryText,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fechas() {
    if (!_esTemporal) {
      return _campoFecha(
        etiqueta: 'Fecha de inicio',
        fecha: _fechaInicio,
        alTocar: _seleccionarFechaInicio,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            children: [
              _campoFecha(
                etiqueta: 'Fecha de inicio',
                fecha: _fechaInicio,
                alTocar: _seleccionarFechaInicio,
              ),
              const SizedBox(height: 14),
              _campoFecha(
                etiqueta: 'Fecha de fin',
                fecha: _fechaFin,
                alTocar: _seleccionarFechaFin,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _campoFecha(
                etiqueta: 'Fecha de inicio',
                fecha: _fechaInicio,
                alTocar: _seleccionarFechaInicio,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _campoFecha(
                etiqueta: 'Fecha de fin',
                fecha: _fechaFin,
                alTocar: _seleccionarFechaFin,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _selectorMotivo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _motivoSeleccionado,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            prefixIcon: Icon(Icons.event_note_outlined),
          ),
          items: _motivos.map((motivo) {
            return DropdownMenuItem<String>(
              value: motivo,
              child: Text(motivo),
            );
          }).toList(),
          validator: (valor) {
            if (!_esTemporal) return null;
            if (valor == null || valor.isEmpty) {
              return 'Selecciona el motivo.';
            }
            return null;
          },
          onChanged: _guardando
              ? null
              : (valor) {
                  setState(() {
                    _motivoSeleccionado = valor;
                    if (valor != 'Otro') {
                      _otroMotivoController.clear();
                    }
                  });
                },
        ),
        if (_motivoSeleccionado == 'Otro') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _otroMotivoController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Especifica el motivo',
              hintText: 'Describe el motivo de la asignación',
            ),
            validator: (valor) {
              if (!_esTemporal || _motivoSeleccionado != 'Otro') {
                return null;
              }
              if (valor == null || valor.trim().isEmpty) {
                return 'Escribe el motivo de la asignación.';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: Text(
          _esEdicion ? 'Editar asignación' : 'Nueva asignación',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_esTemporal) ...[
                    _avisoTemporal(),
                    const SizedBox(height: 16),
                  ],
                  _selectorOperador(),
                  const SizedBox(height: 16),
                  _selectorVehiculo(),
                  const SizedBox(height: 16),
                  _selectorTipo(),
                  const SizedBox(height: 16),
                  _fechas(),
                  if (_esTemporal) ...[
                    const SizedBox(height: 16),
                    _selectorMotivo(),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: AppTheme.cfeGreen,
                      foregroundColor: AppTheme.pureWhite,
                    ),
                    onPressed: _guardando ? null : _guardar,
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
                      _guardando
                          ? 'Guardando…'
                          : _esEdicion
                              ? 'Guardar cambios'
                              : 'Guardar asignación',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: AppTheme.primaryText,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}