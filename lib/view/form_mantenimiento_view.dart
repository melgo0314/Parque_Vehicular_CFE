import 'package:flutter/material.dart';
import 'package:p_vehicular/models/detalle_refaccion_model.dart';
import '../core/theme/app_theme.dart';
import '../models/mantenimiento_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';

// Formulario para registrar o editar un mantenimiento.
class FormMantenimientoView extends StatefulWidget {
  // Vehículo al que pertenece el mantenimiento.
  final VehiculoModel vehiculo;

  // Mantenimiento que se editará; es null cuando se crea uno nuevo.
  final MantenimientoModel? mantenimiento;

  // Crea el formulario para el vehículo indicado.
  // Entradas: key opcional, vehiculo requerido y mantenimiento opcional.
  // Salida: una instancia de FormMantenimientoView.
  const FormMantenimientoView({
    super.key,
    required this.vehiculo,
    this.mantenimiento,
  });

  // Crea el estado asociado al formulario.
  // Entrada: ninguna.
  // Salida: el estado que administra los campos y operaciones.
  @override
  State<FormMantenimientoView> createState() =>
      _FormMantenimientoViewState();
}

// Estado y comportamiento del formulario de mantenimiento.
class _FormMantenimientoViewState extends State<FormMantenimientoView> {
  // Llave global para validar los campos del formulario.
  final _formKey = GlobalKey<FormState>();

  // ViewModel que registra y actualiza mantenimientos.
  final _viewModel = MantenimientoViewModel();

  // Controlador para la descripción del trabajo realizado.
  final _trabajoController = TextEditingController();

  // Controlador para el kilometraje programado.
  final _kilometrajeProgramadoController = TextEditingController();

  // Controlador para el kilometraje realizado.
  final _kilometrajeRealizadoController = TextEditingController();

  // Controlador para el horómetro.
  final _horometroController = TextEditingController();

  // Controlador para el costo del servicio.
  final _costoController = TextEditingController();

  // Controlador para el proveedor o responsable.
  final _proveedorController = TextEditingController();

  // Controlador para las observaciones.
  final _observacionesController = TextEditingController();

  // Controlador para la vida útil de las llantas.
  final _vidaUtilLlantasController = TextEditingController();

  // Controlador para el nivel de desgaste de las llantas.
  final _desgasteLlantasController = TextEditingController();

  // Controlador para la categoría de la prueba PEMP.
  final _categoriaPruebaController = TextEditingController();

  // Controladores para los nombres de las refacciones.
  final List<TextEditingController> _nombreRefaccionControllers = [];

  // Controladores para las cantidades de las refacciones.
  final List<TextEditingController> _cantidadRefaccionControllers = [];

  // Tipo de mantenimiento seleccionado.
  String _tipoMantenimiento = 'preventivo';

  // Módulo de mantenimiento seleccionado.
  String _modulo = 'mecanico';

  // Fecha programada para el mantenimiento, si existe.
  DateTime? _fechaProgramada;

  // Fecha en que se realizó el mantenimiento.
  DateTime _fechaRealizado = DateTime.now();

  // Fecha de caducidad de las llantas, si se registra.
  DateTime? _fechaCaducidadLlantas;

  // Fecha de la prueba PEMP, si corresponde.
  DateTime? _fechaPrueba;

  // Indica si se capturarán datos de control de llantas.
  bool _controlLlantas = false;

  // Indica si el módulo seleccionado es el laboratorio PEMP.
  bool get _esLaboratorio => _modulo == 'laboratorio_pemp';

  // Carga los datos del mantenimiento existente en los campos.
  // Entrada: ninguna; consulta el mantenimiento recibido por el widget.
  // Salida: ninguna; prepara los campos y la lista de refacciones.
  @override
  void initState() {
    super.initState();

    final mantenimiento = widget.mantenimiento;

    if (mantenimiento != null) {
      _tipoMantenimiento = mantenimiento.tipoMantenimiento;
      _modulo = mantenimiento.modulo;
      _fechaProgramada = mantenimiento.fechaProgramada;
      _fechaRealizado = mantenimiento.fechaRealizado;
      _fechaCaducidadLlantas = mantenimiento.fechaCaducidadLlantas;
      _fechaPrueba = mantenimiento.fechaPrueba;

      _kilometrajeProgramadoController.text =
          mantenimiento.kilometrajeProgramado?.toString() ?? '';
      _kilometrajeRealizadoController.text =
          mantenimiento.kilometrajeRealizado?.toString() ?? '';
      _horometroController.text =
          mantenimiento.horometro?.toString() ?? '';
      _trabajoController.text = mantenimiento.trabajoRealizado;
      _costoController.text = mantenimiento.costo.toString();
      _proveedorController.text = mantenimiento.proveedor;
      _observacionesController.text = mantenimiento.observaciones;
      _vidaUtilLlantasController.text =
          mantenimiento.vidaUtilLlantas?.toString() ?? '';
      _desgasteLlantasController.text =
          mantenimiento.nivelDesgasteLlantas?.toString() ?? '';
      _categoriaPruebaController.text = mantenimiento.categoriaPrueba;

      _controlLlantas = mantenimiento.fechaCaducidadLlantas != null ||
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

  // Libera los controladores y el ViewModel al cerrar el formulario.
  // Entrada: ninguna.
  // Salida: ninguna.
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
    _categoriaPruebaController.dispose();

    for (final controller in _nombreRefaccionControllers) {
      controller.dispose();
    }

    for (final controller in _cantidadRefaccionControllers) {
      controller.dispose();
    }

    _viewModel.dispose();
    super.dispose();
  }

  // Agrega un par de campos para capturar una refacción y su cantidad.
  // Entradas: nombre opcional y cantidad opcional para precargar los campos.
  // Salida: ninguna; añade los controladores a sus listas.
  void _agregarRefaccion({
    String nombre = '',
    String cantidad = '1',
  }) {
    setState(() {
      _nombreRefaccionControllers.add(
        TextEditingController(text: nombre),
      );
      _cantidadRefaccionControllers.add(
        TextEditingController(text: cantidad),
      );
    });
  }

  // Quita una refacción y libera sus controladores.
  // Entrada: indice de la refacción que se eliminará.
  // Salida: ninguna; elimina los campos seleccionados del formulario.
  void _quitarRefaccion(int indice) {
    setState(() {
      _nombreRefaccionControllers[indice].dispose();
      _cantidadRefaccionControllers[indice].dispose();
      _nombreRefaccionControllers.removeAt(indice);
      _cantidadRefaccionControllers.removeAt(indice);
    });
  }

  // Abre un selector de fecha.
  // Entrada: fechaActual opcional para establecer la fecha inicial del selector.
  // Salida: fecha seleccionada o null si se cancela.
  Future<DateTime?> _elegirFecha(DateTime? fechaActual) async {
    final hoy = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: fechaActual ?? hoy,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  // Da formato a una fecha para mostrarla en el formulario.
  // Entrada: fecha opcional que se desea presentar.
  // Salida: fecha en formato día/mes/año o el texto para seleccionar una.
  String _mostrarFecha(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar fecha';

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  // Valida que el valor de un campo obligatorio tenga contenido.
  // Entrada: valor escrito en el campo.
  // Salida: mensaje de error si está vacío; de lo contrario, null.
  String? _validarObligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }
    return null;
  }

  // Valida que un campo requerido contenga un número válido.
  // Entrada: valor escrito en el campo numérico.
  // Salida: mensaje de error si está vacío o no es numérico; de lo contrario, null.
  String? _validarNumero(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    if (double.tryParse(valor.trim()) == null) {
      return 'Escribe un número válido.';
    }

    return null;
  }

  // Valida los campos, crea el modelo y lo registra o actualiza.
  // Entrada: ninguna; utiliza los valores de los campos del formulario.
  // Salida: ninguna; muestra el resultado y cierra el formulario si se guarda.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_esLaboratorio && _fechaPrueba == null) {
      _mostrarMensaje(
        'Selecciona la fecha de la prueba.',
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
          DetalleRefaccionModel(
            nombre: nombre,
            cantidad: cantidad,
          ),
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
      fechaProgramada: _fechaProgramada,
      fechaRealizado: _fechaRealizado,
      kilometrajeProgramado:
          int.tryParse(_kilometrajeProgramadoController.text.trim()),
      kilometrajeRealizado: _esLaboratorio
          ? null
          : int.tryParse(_kilometrajeRealizadoController.text.trim()),
      horometro: _modulo == 'hidraulico'
          ? double.tryParse(_horometroController.text.trim())
          : null,
      trabajoRealizado: _trabajoController.text.trim(),
      detalleRefacciones: refacciones,
      costo: double.tryParse(_costoController.text.trim()) ?? 0,
      proveedor: _proveedorController.text.trim(),
      observaciones: _observacionesController.text.trim(),
      fechaCaducidadLlantas:
          _controlLlantas ? _fechaCaducidadLlantas : null,
      vidaUtilLlantas: _controlLlantas
          ? double.tryParse(_vidaUtilLlantasController.text.trim())
          : null,
      nivelDesgasteLlantas: _controlLlantas
          ? double.tryParse(_desgasteLlantasController.text.trim())
          : null,
      fechaPrueba: _esLaboratorio ? _fechaPrueba : null,
      categoriaPrueba:
          _esLaboratorio ? _categoriaPruebaController.text.trim() : '',
      observacionesPrueba:
          _esLaboratorio ? _observacionesController.text.trim() : '',
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

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: mensaje que se presentará y esError para determinar el color.
  // Salida: ninguna; muestra un SnackBar en la pantalla actual.
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

  // Construye un campo de texto reutilizable para el formulario.
  // Entradas: etiqueta, controlador y opciones de validación, tamaño,
  // teclado y texto de ayuda.
  // Salida: un TextFormField configurado con los valores recibidos.
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
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: ayuda,
      ),
    );
  }

  // Construye un botón para seleccionar una fecha.
  // Entradas: etiqueta, fecha actual y función alElegir para recibir la selección.
  // Salida: un widget con botón de calendario y fecha seleccionada.
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
            if (seleccionada != null) {
              alElegir(seleccionada);
            }
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

  // Construye un título para separar las secciones del formulario.
  // Entrada: titulo que se mostrará.
  // Salida: un widget de texto con el estilo de sección.
  Widget _tituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.cfeGreen,
            ),
      ),
    );
  }

  // Construye la interfaz del formulario según el tipo de mantenimiento.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets con campos y acciones.
  @override
  Widget build(BuildContext context) {
    final estaEditando = widget.mantenimiento != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          estaEditando
              ? 'Editar mantenimiento'
              : 'Registrar mantenimiento',
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
                      value: _modulo == 'laboratorio_pemp'
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
                          child: Text('Prueba PEMP'),
                        ),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;

                        setState(() {
                          if (valor == 'prueba') {
                            _modulo = 'laboratorio_pemp';
                          } else {
                            _tipoMantenimiento = valor;
                            if (_modulo == 'laboratorio_pemp') {
                              _modulo = 'mecanico';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _modulo,
                      decoration: const InputDecoration(
                        labelText: 'Módulo',
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
                          child: Text('Laboratorio PEMP'),
                        ),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;

                        setState(() {
                          _modulo = valor;
                          if (_modulo == 'laboratorio_pemp') {
                            _tipoMantenimiento = 'prueba';
                          } else if (_tipoMantenimiento == 'prueba') {
                            _tipoMantenimiento = 'preventivo';
                          }
                        });
                      },
                    ),
                    if (_esLaboratorio) ...[
                      _tituloSeccion('Prueba de equipo PEMP'),
                      _selectorFecha(
                        etiqueta: 'Fecha de la prueba',
                        fecha: _fechaPrueba,
                        alElegir: (fecha) {
                          setState(() => _fechaPrueba = fecha);
                        },
                      ),
                      const SizedBox(height: 14),
                      _campoTexto(
                        etiqueta: 'Categoría asignada',
                        controller: _categoriaPruebaController,
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
                      _selectorFecha(
                        etiqueta: 'Fecha programada (opcional)',
                        fecha: _fechaProgramada,
                        alElegir: (fecha) {
                          setState(() => _fechaProgramada = fecha);
                        },
                      ),
                      const SizedBox(height: 14),
                      _selectorFecha(
                        etiqueta: 'Fecha del servicio',
                        fecha: _fechaRealizado,
                        alElegir: (fecha) {
                          setState(() => _fechaRealizado = fecha);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_modulo == 'mecanico' &&
                          _tipoMantenimiento == 'preventivo')
                        _campoTexto(
                          etiqueta: 'Kilometraje programado',
                          controller: _kilometrajeProgramadoController,
                          validator: _validarNumero,
                          teclado: TextInputType.number,
                        ),
                      if (_modulo != 'hidraulico' ||
                          _tipoMantenimiento == 'preventivo') ...[
                        const SizedBox(height: 14),
                        _campoTexto(
                          etiqueta: 'Kilometraje del servicio',
                          controller: _kilometrajeRealizadoController,
                          validator: _validarNumero,
                          teclado: TextInputType.number,
                        ),
                      ],
                      if (_modulo == 'hidraulico') ...[
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
                      _tituloSeccion('Trabajo y responsable'),
                      _campoTexto(
                        etiqueta: 'Descripción del trabajo realizado',
                        controller: _trabajoController,
                        validator: _validarObligatorio,
                        maxLineas: 3,
                      ),
                      const SizedBox(height: 14),
                      _campoTexto(
                        etiqueta: 'Responsable o proveedor',
                        controller: _proveedorController,
                        validator: _validarObligatorio,
                      ),
                      _tituloSeccion('Refacciones utilizadas'),
                      for (var i = 0;
                          i < _nombreRefaccionControllers.length;
                          i++)
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
                                  controller:
                                      _cantidadRefaccionControllers[i],
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
                              setState(
                                () => _fechaCaducidadLlantas = fecha,
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _campoTexto(
                            etiqueta: 'Vida útil (km)',
                            controller: _vidaUtilLlantasController,
                            teclado: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _campoTexto(
                            etiqueta: 'Desgaste (%)',
                            controller: _desgasteLlantasController,
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
                        validator: _validarNumero,
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