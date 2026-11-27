import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';
import 'package:p_vehicular/models/detalle_refaccion_model.dart';

import '../core/theme/app_theme.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';

class FormMantenimientoView extends StatefulWidget {
  final VehiculoModel vehiculo;
  final MantenimientoModel? mantenimiento;

  const FormMantenimientoView({
    super.key,
    required this.vehiculo,
    this.mantenimiento,
  });

  @override
  State<FormMantenimientoView> createState() => _FormMantenimientoViewState();
}

class _FormMantenimientoViewState extends State<FormMantenimientoView> {
  static const List<String> _categoriasPrueba = [
    'Categoría I: anomalía crítica inoperable',
    'Categoría II: anomalía crítica limitada',
    'Categoría III: daños poco severos/operable',
    'Categoría IV: excelente estado',
  ];

  final _formKey = GlobalKey<FormState>();
  final _viewModel = MantenimientoViewModel();

  final _trabajoController = TextEditingController();
  final _kilometrajeProgramadoController = TextEditingController();
  final _kilometrajeRealizadoController = TextEditingController();
  final _horometroController = TextEditingController();
  final _costoController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _vidaUtilLlantasController = TextEditingController();
  final _desgasteLlantasController = TextEditingController();

  final List<TextEditingController> _nombreRefaccionControllers = [];
  final List<TextEditingController> _cantidadRefaccionControllers = [];

  String _tipoMantenimiento = 'preventivo';
  String _modulo = 'mecanico';
  String _estado = 'programado';
  String? _categoriaPrueba;

  DateTime? _fechaProgramada;
  DateTime? _fechaRealizado;
  DateTime? _fechaCaducidadLlantas;
  DateTime? _fechaPrueba;

  bool _controlLlantas = false;
  bool _regularizaPreventivo = false;

  bool get _esLaboratorio => _modulo == 'laboratorio_pemp';
  bool get _estaRealizado => _estado == 'realizado';
  bool get _estaProgramado => _estado == 'programado';
  bool get _estaPendiente => _estado == 'pendiente';

  @override
  void initState() {
    super.initState();

    final mantenimiento = widget.mantenimiento;

    if (mantenimiento != null) {
      _tipoMantenimiento = mantenimiento.tipoMantenimiento;
      _modulo = mantenimiento.modulo;
      _estado = mantenimiento.estado;
      _regularizaPreventivo = mantenimiento.regularizaPreventivo;

      _fechaProgramada = mantenimiento.fechaProgramada;
      _fechaRealizado = mantenimiento.fechaRealizado;
      _fechaCaducidadLlantas = mantenimiento.fechaCaducidadLlantas;
      _fechaPrueba = mantenimiento.fechaPrueba;

      _kilometrajeProgramadoController.text =
          mantenimiento.kilometrajeProgramado?.toString() ?? '';
      _kilometrajeRealizadoController.text =
          mantenimiento.kilometrajeRealizado?.toString() ?? '';
      _horometroController.text = mantenimiento.horometro?.toString() ?? '';

      _trabajoController.text = mantenimiento.trabajoRealizado;
      _costoController.text = mantenimiento.costo.toString();
      _proveedorController.text = mantenimiento.proveedor;
      _observacionesController.text = mantenimiento.observaciones;

      _vidaUtilLlantasController.text =
          mantenimiento.vidaUtilLlantas?.toString() ?? '';
      _desgasteLlantasController.text =
          mantenimiento.nivelDesgasteLlantas?.toString() ?? '';

      if (_categoriasPrueba.contains(mantenimiento.categoriaPrueba)) {
        _categoriaPrueba = mantenimiento.categoriaPrueba;
      }

      _controlLlantas =
          mantenimiento.fechaCaducidadLlantas != null ||
          mantenimiento.vidaUtilLlantas != null ||
          mantenimiento.nivelDesgasteLlantas != null;

      for (final refaccion in mantenimiento.detalleRefacciones) {
        _agregarRefaccion(
          nombre: refaccion.nombre,
          cantidad: refaccion.cantidad.toString(),
        );
      }
    } else {
      _costoController.text = '0';
    }
  }

  @override
  void dispose() {
    _trabajoController.dispose();
    _kilometrajeProgramadoController.dispose();
    _kilometrajeRealizadoController.dispose();
    _horometroController.dispose();
    _costoController.dispose();
    _proveedorController.dispose();
    _observacionesController.dispose();
    _vidaUtilLlantasController.dispose();
    _desgasteLlantasController.dispose();

    for (final controller in _nombreRefaccionControllers) {
      controller.dispose();
    }

    for (final controller in _cantidadRefaccionControllers) {
      controller.dispose();
    }

    _viewModel.dispose();
    super.dispose();
  }

  void _agregarRefaccion({String nombre = '', String cantidad = '1'}) {
    setState(() {
      _nombreRefaccionControllers.add(TextEditingController(text: nombre));
      _cantidadRefaccionControllers.add(TextEditingController(text: cantidad));
    });
  }

  void _quitarRefaccion(int indice) {
    setState(() {
      _nombreRefaccionControllers[indice].dispose();
      _cantidadRefaccionControllers[indice].dispose();

      _nombreRefaccionControllers.removeAt(indice);
      _cantidadRefaccionControllers.removeAt(indice);
    });
  }

  Future<DateTime?> _elegirFecha(DateTime? fechaActual) async {
    final hoy = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: fechaActual ?? hoy,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  String _mostrarFecha(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar fecha';

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  String? _validarObligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    return null;
  }

  String? _validarNumero(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    if (double.tryParse(valor.trim()) == null) {
      return 'Escribe un número válido.';
    }

    return null;
  }

  String? _validarNumeroOpcional(String? valor) {
    if (valor == null || valor.trim().isEmpty) return null;

    if (double.tryParse(valor.trim()) == null) {
      return 'Escribe un número válido.';
    }

    return null;
  }

  void _actualizarEstadoPorTipo(String tipo) {
    setState(() {
      _tipoMantenimiento = tipo;
      _estado = tipo == 'preventivo' ? 'programado' : 'pendiente';
      if (tipo != 'correctivo') _regularizaPreventivo = false;
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_esLaboratorio && _fechaPrueba == null) {
      _mostrarMensaje('Selecciona la fecha de la prueba.', esError: true);
      return;
    }

    if (_esLaboratorio &&
        (_categoriaPrueba == null ||
            !_categoriasPrueba.contains(_categoriaPrueba))) {
      _mostrarMensaje('Selecciona la categoría de la prueba.', esError: true);
      return;
    }

    if (_estaProgramado) {
      final tieneFecha = _fechaProgramada != null;
      final tieneKilometraje = _kilometrajeProgramadoController.text
          .trim()
          .isNotEmpty;

      if (!tieneFecha && !tieneKilometraje) {
        _mostrarMensaje(
          'Registra una fecha o un kilometraje programado.',
          esError: true,
        );
        return;
      }
    }

    if (_estaRealizado && !_esLaboratorio && _fechaRealizado == null) {
      _mostrarMensaje(
        'Selecciona la fecha en que se realizó el mantenimiento.',
        esError: true,
      );
      return;
    }

    if (_estaRealizado &&
        _modulo == 'mecanico' &&
        _tipoMantenimiento == 'correctivo' &&
        _regularizaPreventivo) {
      final kilometrajeProgramado = int.tryParse(
        _kilometrajeProgramadoController.text.trim(),
      );
      final kilometrajeRealizado = int.tryParse(
        _kilometrajeRealizadoController.text.trim(),
      );

      if (kilometrajeProgramado == null || kilometrajeProgramado <= 0) {
        _mostrarMensaje(
          'Indica el kilometraje en que vencía el preventivo.',
          esError: true,
        );
        return;
      }

      if (kilometrajeRealizado == null ||
          kilometrajeRealizado < kilometrajeProgramado) {
        _mostrarMensaje(
          'El kilometraje real debe ser igual o mayor al kilometraje vencido.',
          esError: true,
        );
        return;
      }
    }

    if (_estaPendiente && _trabajoController.text.trim().isEmpty) {
      _mostrarMensaje(
        'Describe el problema o mantenimiento que está pendiente.',
        esError: true,
      );
      return;
    }

    final refacciones = <DetalleRefaccionModel>[];

    for (var i = 0; i < _nombreRefaccionControllers.length; i++) {
      final nombre = _nombreRefaccionControllers[i].text.trim();
      final cantidad = int.tryParse(
        _cantidadRefaccionControllers[i].text.trim(),
      );

      if (nombre.isNotEmpty && cantidad != null && cantidad > 0) {
        refacciones.add(
          DetalleRefaccionModel(nombre: nombre, cantidad: cantidad),
        );
      }
    }

    final mantenimientoAnterior = widget.mantenimiento;

    final mantenimiento = MantenimientoModel(
      uid: mantenimientoAnterior?.uid ?? '',
      vehiculoUid: widget.vehiculo.uid,
      usuarioUid: mantenimientoAnterior?.usuarioUid ?? '',
      rpeUsuario: mantenimientoAnterior?.rpeUsuario ?? '',
      tipoMantenimiento: _esLaboratorio ? 'prueba' : _tipoMantenimiento,
      modulo: _modulo,
      estado: _esLaboratorio ? 'realizado' : _estado,
      fechaProgramada: _fechaProgramada,
      fechaRealizado: _estaRealizado ? _fechaRealizado : null,
      kilometrajeProgramado: int.tryParse(
        _kilometrajeProgramadoController.text.trim(),
      ),
      kilometrajeRealizado: _esLaboratorio || !_estaRealizado
          ? null
          : int.tryParse(_kilometrajeRealizadoController.text.trim()),
      regularizaPreventivo:
          _modulo == 'mecanico' &&
          _tipoMantenimiento == 'correctivo' &&
          _regularizaPreventivo,
      horometro: _modulo == 'hidraulico' && _estaRealizado
          ? double.tryParse(_horometroController.text.trim())
          : null,
      trabajoRealizado: _trabajoController.text.trim(),
      detalleRefacciones: refacciones,
      costo: _estaRealizado
          ? double.tryParse(_costoController.text.trim()) ?? 0
          : 0,
      proveedor: _estaRealizado ? _proveedorController.text.trim() : '',
      observaciones: _observacionesController.text.trim(),
      fechaCaducidadLlantas: _controlLlantas ? _fechaCaducidadLlantas : null,
      vidaUtilLlantas: _controlLlantas
          ? double.tryParse(_vidaUtilLlantasController.text.trim())
          : null,
      nivelDesgasteLlantas: _controlLlantas
          ? double.tryParse(_desgasteLlantasController.text.trim())
          : null,
      fechaPrueba: _esLaboratorio ? _fechaPrueba : null,
      categoriaPrueba: _esLaboratorio ? _categoriaPrueba! : '',
      observacionesPrueba: _esLaboratorio
          ? _observacionesController.text.trim()
          : '',
    );

    final resultado = mantenimientoAnterior == null
        ? await _viewModel.registrarMantenimiento(mantenimiento)
        : await _viewModel.actualizarMantenimiento(mantenimiento);

    if (!mounted) return;

    if (resultado) {
      _mostrarMensaje(
        _viewModel.mensajeExito ?? 'Mantenimiento guardado correctamente.',
      );
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar el mantenimiento.',
        esError: true,
      );
      _viewModel.limpiarMensajes();
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
        ),
      );
  }

  Widget _campoTexto({
    required String etiqueta,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLineas = 1,
    TextInputType? teclado,
    String? ayuda,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLineas,
      keyboardType: teclado,
      decoration: InputDecoration(labelText: etiqueta, hintText: ayuda),
    );
  }

  Widget _selectorFecha({
    required String etiqueta,
    required DateTime? fecha,
    required ValueChanged<DateTime> alElegir,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () async {
            final seleccionada = await _elegirFecha(fecha);
            if (seleccionada != null) alElegir(seleccionada);
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_mostrarFecha(fecha)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }

  Widget _tituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.cfeGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estaEditando = widget.mantenimiento != null;

    return Scaffold(
      bottomNavigationBar: const InicioFooter(),
      appBar: AppBar(
        title: Text(
          estaEditando ? 'Editar mantenimiento' : 'Registrar mantenimiento',
        ),
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Card(
              margin: const EdgeInsets.all(20),
              color: AppTheme.pureWhite,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Vehículo',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      child: Text(
                        '${widget.vehiculo.numeroEconomico} · '
                        '${widget.vehiculo.marca} '
                        '${widget.vehiculo.modelo} '
                        '${widget.vehiculo.anio}',
                      ),
                    ),
                    _tituloSeccion('Tipo de registro'),
                    DropdownButtonFormField<String>(
                      initialValue: _modulo == 'laboratorio_pemp'
                          ? 'prueba'
                          : _tipoMantenimiento,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de mantenimiento',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'preventivo',
                          child: Text('Preventivo'),
                        ),
                        DropdownMenuItem(
                          value: 'correctivo',
                          child: Text('Correctivo'),
                        ),
                        DropdownMenuItem(
                          value: 'prueba',
                          child: Text('Prueba LAPEM'),
                        ),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;

                        setState(() {
                          if (valor == 'prueba') {
                            _modulo = 'laboratorio_pemp';
                            _tipoMantenimiento = 'prueba';
                            _estado = 'realizado';
                          } else {
                            _modulo = 'mecanico';
                            _actualizarEstadoPorTipo(valor);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _modulo,
                      decoration: const InputDecoration(labelText: 'Módulo'),
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
                          child: Text(
                            'Laboratorio de pruebas de equipo y materiales '
                            '(LAPEM)',
                          ),
                        ),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;

                        setState(() {
                          _modulo = valor;

                          if (_modulo == 'laboratorio_pemp') {
                            _tipoMantenimiento = 'prueba';
                            _estado = 'realizado';
                          } else if (_tipoMantenimiento == 'prueba') {
                            _tipoMantenimiento = 'preventivo';
                            _estado = 'programado';
                          }
                        });
                      },
                    ),
                    if (!_esLaboratorio) ...[
                      _tituloSeccion('Estado del mantenimiento'),
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: _tipoMantenimiento == 'preventivo'
                            ? const [
                                DropdownMenuItem(
                                  value: 'programado',
                                  child: Text('Programado'),
                                ),
                                DropdownMenuItem(
                                  value: 'realizado',
                                  child: Text('Realizado'),
                                ),
                              ]
                            : const [
                                DropdownMenuItem(
                                  value: 'pendiente',
                                  child: Text('Pendiente'),
                                ),
                                DropdownMenuItem(
                                  value: 'realizado',
                                  child: Text('Realizado'),
                                ),
                              ],
                        onChanged: (valor) {
                          if (valor != null) {
                            setState(() => _estado = valor);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _estaProgramado
                            ? 'Registra cuándo o en qué kilometraje se debe '
                                  'realizar el mantenimiento.'
                            : _estaPendiente
                            ? 'Registra el problema que necesita atención.'
                            : 'Captura los datos del mantenimiento que '
                                  'ya se realizó.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (_esLaboratorio) ...[
                      _tituloSeccion(
                        'Laboratorio de pruebas de equipo y materiales '
                        '(LAPEM)',
                      ),
                      _selectorFecha(
                        etiqueta: 'Fecha de la prueba',
                        fecha: _fechaPrueba,
                        alElegir: (fecha) {
                          setState(() => _fechaPrueba = fecha);
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _categoriasPrueba.contains(_categoriaPrueba)
                            ? _categoriaPrueba
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoría asignada',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _categoriasPrueba.map((categoria) {
                          return DropdownMenuItem<String>(
                            value: categoria,
                            child: Text(
                              categoria,
                              overflow: TextOverflow.visible,
                            ),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          setState(() => _categoriaPrueba = valor);
                        },
                        validator: _validarObligatorio,
                      ),
                      const SizedBox(height: 14),
                      _campoTexto(
                        etiqueta: 'Observaciones de la prueba',
                        controller: _observacionesController,
                        maxLineas: 3,
                      ),
                    ] else ...[
                      _tituloSeccion('Fechas y lecturas'),
                      if (_estaProgramado || _estaRealizado) ...[
                        _selectorFecha(
                          etiqueta: 'Fecha programada (opcional)',
                          fecha: _fechaProgramada,
                          alElegir: (fecha) {
                            setState(() => _fechaProgramada = fecha);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_estaRealizado) ...[
                        _selectorFecha(
                          etiqueta: 'Fecha del servicio',
                          fecha: _fechaRealizado,
                          alElegir: (fecha) {
                            setState(() => _fechaRealizado = fecha);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_modulo == 'mecanico' &&
                          _tipoMantenimiento == 'correctivo')
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _regularizaPreventivo,
                          title: const Text(
                            'Este correctivo atiende un preventivo vencido',
                          ),
                          subtitle: const Text(
                            'Al completarlo, se calculará el siguiente servicio '
                            'desde el kilometraje real.',
                          ),
                          onChanged: (valor) {
                            setState(() {
                              _regularizaPreventivo = valor ?? false;
                              if (!_regularizaPreventivo) {
                                _kilometrajeProgramadoController.clear();
                              }
                            });
                          },
                        ),
                      if (_modulo == 'mecanico' &&
                          _tipoMantenimiento == 'preventivo' &&
                          (_estaProgramado || _estaRealizado))
                        _campoTexto(
                          etiqueta: 'Kilometraje programado',
                          controller: _kilometrajeProgramadoController,
                          validator: _validarNumeroOpcional,
                          teclado: TextInputType.number,
                        ),
                      if (_modulo == 'mecanico' &&
                          _tipoMantenimiento == 'correctivo' &&
                          _regularizaPreventivo &&
                          (_estaPendiente || _estaRealizado))
                        _campoTexto(
                          etiqueta: 'Kilometraje en que vencía el preventivo',
                          controller: _kilometrajeProgramadoController,
                          validator: _estaRealizado
                              ? _validarNumero
                              : _validarNumeroOpcional,
                          teclado: TextInputType.number,
                        ),
                      if (_estaRealizado && _modulo != 'hidraulico') ...[
                        const SizedBox(height: 14),
                        _campoTexto(
                          etiqueta: 'Kilometraje del servicio',
                          controller: _kilometrajeRealizadoController,
                          validator: _validarNumero,
                          teclado: TextInputType.number,
                        ),
                      ],
                      if (_estaRealizado && _modulo == 'hidraulico') ...[
                        const SizedBox(height: 14),
                        _campoTexto(
                          etiqueta: 'Horómetro (horas)',
                          controller: _horometroController,
                          validator: _validarNumero,
                          teclado: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                      _tituloSeccion(
                        _estaPendiente
                            ? 'Descripción del problema'
                            : _estaProgramado
                            ? 'Descripción del mantenimiento'
                            : 'Trabajo y responsable',
                      ),
                      _campoTexto(
                        etiqueta: _estaPendiente
                            ? 'Problema o trabajo requerido'
                            : _estaProgramado
                            ? 'Descripción del mantenimiento previsto'
                            : 'Descripción del trabajo realizado',
                        controller: _trabajoController,
                        validator: _estaPendiente || _estaRealizado
                            ? _validarObligatorio
                            : null,
                        maxLineas: 3,
                      ),
                      if (_estaRealizado) ...[
                        const SizedBox(height: 14),
                        _campoTexto(
                          etiqueta: 'Responsable o proveedor',
                          controller: _proveedorController,
                          validator: _validarObligatorio,
                        ),
                      ],
                      _tituloSeccion('Refacciones utilizadas'),
                      for (
                        var i = 0;
                        i < _nombreRefaccionControllers.length;
                        i++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nombreRefaccionControllers[i],
                                  decoration: InputDecoration(
                                    labelText: 'Nombre de refacción ${i + 1}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: _cantidadRefaccionControllers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Cantidad',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Quitar refacción',
                                onPressed: () => _quitarRefaccion(i),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _agregarRefaccion(),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar refacción'),
                      ),
                      if (_modulo == 'mecanico') ...[
                        _tituloSeccion('Control de llantas'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Registrar datos de llantas'),
                          value: _controlLlantas,
                          onChanged: (valor) {
                            setState(() => _controlLlantas = valor);
                          },
                        ),
                        if (_controlLlantas) ...[
                          _selectorFecha(
                            etiqueta: 'Fecha de caducidad',
                            fecha: _fechaCaducidadLlantas,
                            alElegir: (fecha) {
                              setState(() => _fechaCaducidadLlantas = fecha);
                            },
                          ),
                          const SizedBox(height: 14),
                          _campoTexto(
                            etiqueta: 'Vida útil (km)',
                            controller: _vidaUtilLlantasController,
                            validator: _validarNumeroOpcional,
                            teclado: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _campoTexto(
                            etiqueta: 'Desgaste (%)',
                            controller: _desgasteLlantasController,
                            validator: _validarNumeroOpcional,
                            teclado: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ],
                      _tituloSeccion('Costo y observaciones'),
                      _campoTexto(
                        etiqueta: 'Costo',
                        controller: _costoController,
                        validator: _estaRealizado
                            ? _validarNumero
                            : _validarNumeroOpcional,
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _campoTexto(
                        etiqueta: 'Observaciones (opcional)',
                        controller: _observacionesController,
                        maxLineas: 3,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, child) {
                        return ElevatedButton.icon(
                          onPressed: _viewModel.cargando ? null : _guardar,
                          icon: _viewModel.cargando
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
                            _viewModel.cargando
                                ? 'Guardando...'
                                : estaEditando
                                ? 'Guardar cambios'
                                : 'Guardar mantenimiento',
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _viewModel.cargando
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
