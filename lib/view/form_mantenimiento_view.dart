import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';

class FormMantenimientoView extends StatefulWidget {
  final String? vehiculoUidInicial;
  final String? moduloInicial;
  final MantenimientoModel? mantenimiento;

  const FormMantenimientoView({
    super.key,
    this.vehiculoUidInicial,
    this.moduloInicial,
    this.mantenimiento,
  });

  @override
  State<FormMantenimientoView> createState() =>
      _FormMantenimientoViewState();
}

class _FormMantenimientoViewState extends State<FormMantenimientoView> {
  final _formKey = GlobalKey<FormState>();
  final _viewModel = MantenimientoViewModel();

  final _trabajoController = TextEditingController();
  final _piezaController = TextEditingController();
  final _cantidadPiezaController = TextEditingController(text: '1');
  final _costoController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _kilometrajeController = TextEditingController();
  final _kilometrajeProgramadoController = TextEditingController();
  final _horometroController = TextEditingController();
  final _vidaUtilLlantaController = TextEditingController();
  final _desgasteLlantaController = TextEditingController();
  final _categoriaPempController = TextEditingController();

  late final Stream<List<VehiculoModel>> _vehiculosStream;

  final List<String> _piezas = [];

  String? _vehiculoUid;
  String _modulo = 'mecanico';
  String _tipoMantenimiento = 'preventivo';

  DateTime _fechaRealizado = DateTime.now();
  DateTime? _fechaProgramada;
  DateTime? _fechaCaducidadLlanta;

  bool _controlLlantas = false;
  bool _guardando = false;
  bool _intentoGuardar = false;

  bool get _esEdicion => widget.mantenimiento != null;
  bool get _esPemp => _modulo == 'laboratorio_pemp';
  bool get _esPreventivo => _tipoMantenimiento == 'preventivo';

  bool get _debeCapturarKilometraje {
    return _modulo == 'mecanico' ||
        (_modulo == 'hidraulico' && _esPreventivo);
  }

  @override
  void initState() {
    super.initState();

    _vehiculosStream = _viewModel.obtenerVehiculos();

    final mantenimiento = widget.mantenimiento;

    if (mantenimiento != null) {
      _vehiculoUid = mantenimiento.vehiculoUid;
      _modulo = mantenimiento.modulo;
      _tipoMantenimiento = mantenimiento.tipoMantenimiento;

      _fechaRealizado = mantenimiento.fechaRealizado;
      _fechaProgramada = mantenimiento.fechaProgramada;
      _fechaCaducidadLlanta = mantenimiento.fechaCaducidadLlanta;

      _trabajoController.text = mantenimiento.trabajoRealizado;
      _costoController.text = mantenimiento.costo.toStringAsFixed(2);
      _proveedorController.text = mantenimiento.proveedor;
      _observacionesController.text = mantenimiento.observaciones;
      _categoriaPempController.text = mantenimiento.categoriaPemp;

      if (mantenimiento.kilometraje != null) {
        _kilometrajeController.text =
            mantenimiento.kilometraje.toString();
      }

      if (mantenimiento.kilometrajeProgramado != null) {
        _kilometrajeProgramadoController.text =
            mantenimiento.kilometrajeProgramado.toString();
      }

      if (mantenimiento.horometroHoras != null) {
        _horometroController.text =
            mantenimiento.horometroHoras.toString();
      }

      if (mantenimiento.vidaUtilLlantaKm != null) {
        _vidaUtilLlantaController.text =
            mantenimiento.vidaUtilLlantaKm.toString();
      }

      if (mantenimiento.desgasteLlantaPorcentaje != null) {
        _desgasteLlantaController.text =
            mantenimiento.desgasteLlantaPorcentaje.toString();
      }

      if (mantenimiento.piezasUtilizadas.trim().isNotEmpty) {
        _piezas.add(mantenimiento.piezasUtilizadas);
      }

      _controlLlantas = mantenimiento.fechaCaducidadLlanta != null ||
          mantenimiento.vidaUtilLlantaKm != null ||
          mantenimiento.desgasteLlantaPorcentaje != null;
    } else {
      _vehiculoUid = widget.vehiculoUidInicial;

      final moduloInicial = widget.moduloInicial;
      if (moduloInicial != null && moduloInicial.isNotEmpty) {
        _modulo = moduloInicial;
      }

      if (_modulo == 'laboratorio_pemp') {
        _tipoMantenimiento = 'prueba';
      }
    }
  }

  @override
  void dispose() {
    _trabajoController.dispose();
    _piezaController.dispose();
    _cantidadPiezaController.dispose();
    _costoController.dispose();
    _proveedorController.dispose();
    _observacionesController.dispose();
    _kilometrajeController.dispose();
    _kilometrajeProgramadoController.dispose();
    _horometroController.dispose();
    _vidaUtilLlantaController.dispose();
    _desgasteLlantaController.dispose();
    _categoriaPempController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String? _validarObligatorio(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa $campo.';
    }
    return null;
  }

  double? _leerDecimal(String valor) {
    return double.tryParse(valor.trim().replaceAll(',', '.'));
  }

  String? _validarCosto(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el costo.';
    }

    final costo = _leerDecimal(valor);
    if (costo == null || costo < 0) {
      return 'Ingresa un costo válido.';
    }

    return null;
  }

  String? _validarKilometraje(String? valor) {
    if (!_debeCapturarKilometraje) return null;

    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el kilometraje.';
    }

    final kilometraje = int.tryParse(valor.trim());

    if (kilometraje == null || kilometraje < 0) {
      return 'Ingresa un kilometraje válido.';
    }

    return null;
  }

  String? _validarKilometrajeProgramado(String? valor) {
    if (_modulo != 'mecanico' || !_esPreventivo) return null;

    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el kilometraje del próximo servicio.';
    }

    final programado = int.tryParse(valor.trim());
    final realizado = int.tryParse(_kilometrajeController.text.trim());

    if (programado == null || programado <= 0) {
      return 'Ingresa un kilometraje programado válido.';
    }

    if (realizado != null && programado <= realizado) {
      return 'Debe ser mayor que el kilometraje realizado.';
    }

    return null;
  }

  String? _validarHorometro(String? valor) {
    if (_modulo != 'hidraulico' || !_esPreventivo) return null;

    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa las horas del horómetro.';
    }

    final horas = _leerDecimal(valor);

    if (horas == null || horas < 0) {
      return 'Ingresa un valor válido para el horómetro.';
    }

    return null;
  }

  String? _validarCategoria(String? valor) {
    if (!_esPemp) return null;

    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa la categoría asignada en la prueba.';
    }

    return null;
  }

  String? _validarObservaciones(String? valor) {
    if (!_esPemp) return null;

    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa las observaciones de la prueba.';
    }

    return null;
  }

  String? _validarFechaCaducidadLlanta() {
    if (!_controlLlantas) return null;

    if (_fechaCaducidadLlanta == null) {
      return 'Selecciona la fecha de caducidad de la llanta.';
    }

    return null;
  }

  Future<DateTime?> _seleccionarFecha({
    required DateTime fechaInicial,
    bool permitirFechaFutura = false,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: permitirFechaFutura ? DateTime(2100) : DateTime.now(),
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
  }

  Future<void> _elegirFechaRealizado() async {
    final fecha = await _seleccionarFecha(
      fechaInicial: _fechaRealizado,
    );

    if (fecha != null && mounted) {
      setState(() => _fechaRealizado = fecha);
    }
  }

  Future<void> _elegirFechaProgramada() async {
    final fecha = await _seleccionarFecha(
      fechaInicial: _fechaProgramada ?? DateTime.now(),
      permitirFechaFutura: true,
    );

    if (fecha != null && mounted) {
      setState(() => _fechaProgramada = fecha);
    }
  }

  Future<void> _elegirFechaCaducidadLlanta() async {
    final fecha = await _seleccionarFecha(
      fechaInicial: _fechaCaducidadLlanta ?? DateTime.now(),
      permitirFechaFutura: true,
    );

    if (fecha != null && mounted) {
      setState(() => _fechaCaducidadLlanta = fecha);
    }
  }

  String _fechaTexto(DateTime? fecha) {
    if (fecha == null) return 'Selecciona una fecha';

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

  void _agregarPieza() {
    final nombre = _piezaController.text.trim();
    final cantidad = int.tryParse(_cantidadPiezaController.text.trim());

    if (nombre.isEmpty) {
      _mensaje('Escribe el nombre de la pieza o refacción.');
      return;
    }

    if (cantidad == null || cantidad <= 0) {
      _mensaje('La cantidad debe ser mayor que cero.');
      return;
    }

    setState(() {
      _piezas.add('$nombre ×$cantidad');
      _piezaController.clear();
      _cantidadPiezaController.text = '1';
    });
  }

  Future<void> _guardar(String vehiculoUid) async {
    FocusScope.of(context).unfocus();

    setState(() => _intentoGuardar = true);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final errorCaducidad = _validarFechaCaducidadLlanta();
    if (errorCaducidad != null) {
      _mensaje(errorCaducidad);
      return;
    }

    final costo = _leerDecimal(_costoController.text);
    if (costo == null) return;

    final mantenimiento = MantenimientoModel(
      uid: widget.mantenimiento?.uid ?? '',
      vehiculoUid: vehiculoUid,
      rpeUsuario: widget.mantenimiento?.rpeUsuario ?? '',
      tipoMantenimiento: _tipoMantenimiento,
      modulo: _modulo,
      fechaProgramada: _fechaProgramada,
      fechaRealizado: _fechaRealizado,
      kilometraje: int.tryParse(_kilometrajeController.text.trim()),
      kilometrajeProgramado:
          int.tryParse(_kilometrajeProgramadoController.text.trim()),
      horometroHoras: _leerDecimal(_horometroController.text),
      trabajoRealizado: _trabajoController.text.trim(),
      piezasUtilizadas: _piezas.join('; '),
      costo: costo,
      proveedor: _proveedorController.text.trim(),
      observaciones: _observacionesController.text.trim(),
      fechaCaducidadLlanta:
          _controlLlantas ? _fechaCaducidadLlanta : null,
      vidaUtilLlantaKm: _controlLlantas
          ? int.tryParse(_vidaUtilLlantaController.text.trim())
          : null,
      desgasteLlantaPorcentaje: _controlLlantas
          ? _leerDecimal(_desgasteLlantaController.text)
          : null,
      categoriaPemp: _categoriaPempController.text.trim(),
    );

    setState(() => _guardando = true);

    final guardado = _esEdicion
        ? await _viewModel.actualizarMantenimiento(mantenimiento)
        : await _viewModel.registrarMantenimiento(mantenimiento);

    if (!mounted) return;

    setState(() => _guardando = false);

    if (!guardado) {
      _mensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar el mantenimiento.',
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _fechaCampo({
    required String etiqueta,
    required DateTime? fecha,
    required VoidCallback alTocar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(etiqueta),
        const SizedBox(height: 6),
        InkWell(
          onTap: _guardando ? null : alTocar,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_month_outlined),
            ),
            child: Text(_fechaTexto(fecha)),
          ),
        ),
      ],
    );
  }

  Widget _etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppTheme.primaryText,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _dosColumnas(Widget primero, Widget segundo) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primero,
              const SizedBox(height: 14),
              segundo,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: primero),
            const SizedBox(width: 12),
            Expanded(child: segundo),
          ],
        );
      },
    );
  }

  Widget _campoKilometraje({
    required TextEditingController controller,
    required String etiqueta,
    required String? Function(String?) validar,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_guardando,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixText: 'km',
      ),
      validator: validar,
    );
  }

  Widget _campoCosto() {
    return TextFormField(
      controller: _costoController,
      enabled: !_guardando,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^\d*([.,]\d{0,2})?$'),
        ),
      ],
      decoration: const InputDecoration(
        labelText: 'Costo',
        prefixText: '\$ ',
      ),
      validator: _validarCosto,
    );
  }

  Widget _campoProveedor() {
    return TextFormField(
      controller: _proveedorController,
      enabled: !_guardando,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Responsable o proveedor',
      ),
      validator: (valor) =>
          _validarObligatorio(valor, 'el responsable o proveedor'),
    );
  }

  Widget _seccionPiezas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiqueta('Piezas o refacciones utilizadas'),
        const SizedBox(height: 8),
        if (_piezas.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _piezas.map((pieza) {
              return Chip(
                label: Text(pieza),
                onDeleted: _guardando
                    ? null
                    : () {
                        setState(() => _piezas.remove(pieza));
                      },
              );
            }).toList(),
          ),
        _dosColumnas(
          TextField(
            controller: _piezaController,
            enabled: !_guardando,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Pieza o refacción',
              hintText: 'Ej. Balatas delanteras',
            ),
          ),
          TextField(
            controller: _cantidadPiezaController,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Cantidad',
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _guardando ? null : _agregarPieza,
          icon: const Icon(Icons.add),
          label: const Text('Agregar pieza o refacción'),
        ),
      ],
    );
  }

  Widget _camposLlantas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Registrar control de llantas'),
          value: _controlLlantas,
          onChanged: _guardando
              ? null
              : (valor) {
                  setState(() => _controlLlantas = valor);
                },
        ),
        if (_controlLlantas) ...[
          _fechaCampo(
            etiqueta: 'Fecha de caducidad',
            fecha: _fechaCaducidadLlanta,
            alTocar: _elegirFechaCaducidadLlanta,
          ),
          const SizedBox(height: 14),
          _campoKilometraje(
            controller: _vidaUtilLlantaController,
            etiqueta: 'Vida útil de la llanta',
            validar: (valor) {
              if (!_controlLlantas) return null;
              if (valor == null || valor.trim().isEmpty) {
                return 'Ingresa la vida útil en kilómetros.';
              }

              final vidaUtil = int.tryParse(valor.trim());
              if (vidaUtil == null || vidaUtil <= 0) {
                return 'La vida útil debe ser mayor que cero.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _desgasteLlantaController,
            enabled: !_guardando,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,3}([.,]\d{0,2})?$'),
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'Nivel de desgaste',
              suffixText: '%',
            ),
            validator: (valor) {
              if (!_controlLlantas) return null;
              if (valor == null || valor.trim().isEmpty) {
                return 'Ingresa el desgaste de la llanta.';
              }

              final desgaste = _leerDecimal(valor);
              if (desgaste == null || desgaste < 0 || desgaste > 100) {
                return 'El desgaste debe estar entre 0 y 100%.';
              }

              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _contenidoFormulario(
    List<VehiculoModel> vehiculos,
    String vehiculoUidSeleccionado,
  ) {
    return Form(
      key: _formKey,
      autovalidateMode: _intentoGuardar
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _esEdicion ? 'Editar mantenimiento' : 'Registrar mantenimiento',
            style: const TextStyle(
              color: AppTheme.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: vehiculoUidSeleccionado,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Vehículo',
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
            onChanged: _guardando
                ? null
                : (valor) {
                    if (valor != null) {
                      setState(() => _vehiculoUid = valor);
                    }
                  },
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _modulo,
            decoration: const InputDecoration(
              labelText: 'Módulo',
              prefixIcon: Icon(Icons.build_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'mecanico',
                child: Text('Mecánico'),
              ),
              DropdownMenuItem(
                value: 'hidraulico',
                child: Text('Hidráulico'),
              ),
              DropdownMenuItem(
                value: 'laboratorio_pemp',
                child: Text('Laboratorio de pruebas PEMP'),
              ),
            ],
            onChanged: _guardando
                ? null
                : (valor) {
                    if (valor == null) return;

                    setState(() {
                      _modulo = valor;
                      _tipoMantenimiento = valor == 'laboratorio_pemp'
                          ? 'prueba'
                          : 'preventivo';
                    });
                  },
          ),

          if (!_esPemp) ...[
            const SizedBox(height: 16),
            _etiqueta('Tipo de mantenimiento'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'preventivo',
                  label: Text('Preventivo'),
                ),
                ButtonSegment(
                  value: 'correctivo',
                  label: Text('Correctivo'),
                ),
              ],
              selected: {_tipoMantenimiento},
              showSelectedIcon: false,
              onSelectionChanged: _guardando
                  ? null
                  : (seleccion) {
                      if (seleccion.isNotEmpty) {
                        setState(
                          () => _tipoMantenimiento = seleccion.first,
                        );
                      }
                    },
            ),
          ],

          const SizedBox(height: 16),
          _dosColumnas(
            _fechaCampo(
              etiqueta: 'Fecha realizada',
              fecha: _fechaRealizado,
              alTocar: _elegirFechaRealizado,
            ),
            _debeCapturarKilometraje
                ? _campoKilometraje(
                    controller: _kilometrajeController,
                    etiqueta: 'Kilometraje',
                    validar: _validarKilometraje,
                  )
                : const SizedBox.shrink(),
          ),

          if (_modulo == 'mecanico' && _esPreventivo) ...[
            const SizedBox(height: 14),
            _dosColumnas(
              _fechaCampo(
                etiqueta: 'Fecha del próximo servicio (opcional)',
                fecha: _fechaProgramada,
                alTocar: _elegirFechaProgramada,
              ),
              _campoKilometraje(
                controller: _kilometrajeProgramadoController,
                etiqueta: 'Km del próximo servicio',
                validar: _validarKilometrajeProgramado,
              ),
            ),
          ],

          if (_modulo == 'hidraulico' && _esPreventivo) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _horometroController,
              enabled: !_guardando,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*([.,]\d{0,2})?$'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Lectura del horómetro',
                suffixText: 'horas',
              ),
              validator: (valor) => _modulo == 'hidraulico' &&
                      _esPreventivo
                  ? _validarHorometro(valor)
                  : null,
            ),
          ],

          const SizedBox(height: 16),
          TextFormField(
            controller: _trabajoController,
            enabled: !_guardando,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción del trabajo realizado',
              hintText: 'Describe el mantenimiento, reparación o prueba',
              alignLabelWithHint: true,
            ),
            validator: (valor) =>
                _validarObligatorio(valor, 'la descripción del trabajo'),
          ),

          const SizedBox(height: 16),
          _seccionPiezas(),

          const SizedBox(height: 16),
          _dosColumnas(
            _campoCosto(),
            _campoProveedor(),
          ),

          if (_esPemp) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoriaPempController,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Categoría asignada en la prueba PEMP',
              ),
              validator: _validarCategoria,
            ),
          ],

          if (_modulo == 'mecanico') ...[
            const SizedBox(height: 12),
            _camposLlantas(),
          ],

          const SizedBox(height: 16),
          TextFormField(
            controller: _observacionesController,
            enabled: !_guardando,
            minLines: 2,
            maxLines: 4,
            maxLength: 250,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              hintText: 'Opcional',
              alignLabelWithHint: true,
            ),
            validator: _validarObservaciones,
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _guardando
                  ? null
                  : () => _guardar(vehiculoUidSeleccionado),
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
                        : 'Guardar mantenimiento',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: Text(
          _esEdicion ? 'Editar mantenimiento' : 'Registrar mantenimiento',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<VehiculoModel>>(
          stream: _vehiculosStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se pudieron cargar los vehículos. Revisa tu conexión.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final vehiculos = snapshot.data ?? [];

            if (vehiculos.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hay vehículos disponibles para registrar mantenimiento.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            String vehiculoUidSeleccionado =
                _vehiculoUid ?? vehiculos.first.uid;

            if (!vehiculos.any(
              (vehiculo) => vehiculo.uid == vehiculoUidSeleccionado,
            )) {
              vehiculoUidSeleccionado = vehiculos.first.uid;
            }

            return Center(
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
                      child: _contenidoFormulario(
                        vehiculos,
                        vehiculoUidSeleccionado,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}