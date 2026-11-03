import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/vehiculos_viewmodel.dart';

// Formulario para registrar o editar un vehículo.
class FormVehiculoView extends StatefulWidget {
  // Vehículo que se editará; es null cuando se registra uno nuevo.
  final VehiculoModel? vehiculo;

  // Crea el formulario y recibe opcionalmente un vehículo existente.
  // Entradas: key opcional y vehiculo opcional para el modo de edición.
  // Salida: una instancia de FormVehiculoView.
  const FormVehiculoView({
    super.key,
    this.vehiculo,
  });

  // Crea el estado asociado al formulario.
  // Entrada: ninguna.
  // Salida: el estado que administra los campos y las operaciones.
  @override
  State<FormVehiculoView> createState() => _FormVehiculoViewState();
}

// Estado y comportamiento del formulario de vehículos.
class _FormVehiculoViewState extends State<FormVehiculoView> {
  // Llave para validar los campos del formulario.
  final _formKey = GlobalKey<FormState>();

  // ViewModel que registra y actualiza vehículos.
  final _viewModel = VehiculosViewModel();

  // Controlador para las placas.
  final _placasController = TextEditingController();

  // Controlador para el número económico.
  final _numeroEconomicoController = TextEditingController();

  // Controlador para la marca.
  final _marcaController = TextEditingController();

  // Controlador para el modelo.
  final _modeloController = TextEditingController();

  // Controlador para el año.
  final _anioController = TextEditingController();

  // Controlador para el intervalo preventivo, con valor inicial de 5,000 km.
  final _intervaloPreventivoController =
      TextEditingController(text: '5000');

  // Estado operativo seleccionado para el vehículo.
  String _estadoOperativo = 'operativo';

  // Indica si se están guardando los datos del formulario.
  bool _guardando = false;

  // Indica si se está cambiando el estado administrativo del vehículo.
  bool _cambiandoEstado = false;

  // Indica si el formulario está editando un vehículo existente.
  bool get _esEdicion => widget.vehiculo != null;

  // Carga los datos del vehículo existente en los campos del formulario.
  // Entrada: ninguna; consulta el vehículo recibido por el widget.
  // Salida: ninguna; prepara los controladores y el estado operativo.
  @override
  void initState() {
    super.initState();

    final vehiculo = widget.vehiculo;

    if (vehiculo != null) {
      _placasController.text = vehiculo.placas;
      _numeroEconomicoController.text = vehiculo.numeroEconomico;
      _marcaController.text = vehiculo.marca;
      _modeloController.text = vehiculo.modelo;
      _anioController.text = vehiculo.anio.toString();
      _estadoOperativo = vehiculo.estadoOperativo;
      _intervaloPreventivoController.text =
          vehiculo.intervaloPreventivoKm.toString();
    }
  }

  // Libera los controladores y el ViewModel al cerrar el formulario.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _placasController.dispose();
    _numeroEconomicoController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _intervaloPreventivoController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // Valida que un campo obligatorio tenga contenido.
  // Entradas: valor escrito y nombreCampo para construir el mensaje de error.
  // Salida: mensaje de error si el campo está vacío; de lo contrario, null.
  String? _validarObligatorio(String? valor, String nombreCampo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe $nombreCampo.';
    }

    return null;
  }

  // Valida que el año esté dentro del rango permitido.
  // Entrada: valor escrito en el campo del año.
  // Salida: mensaje de error si no es válido; de lo contrario, null.
  String? _validarAnio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe el año del vehículo.';
    }

    final anio = int.tryParse(valor.trim());
    final anioActual = DateTime.now().year;

    if (anio == null || anio < 1950 || anio > anioActual + 1) {
      return 'Escribe un año entre 1950 y ${anioActual + 1}.';
    }

    return null;
  }

  // Valida que el intervalo preventivo sea un número entero mayor que cero.
  // Entrada: valor escrito en el campo del intervalo.
  // Salida: mensaje de error si no es válido; de lo contrario, null.
  String? _validarIntervalo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe el intervalo preventivo.';
    }

    final intervalo = int.tryParse(valor.trim());

    if (intervalo == null || intervalo <= 0) {
      return 'El intervalo debe ser un número mayor que cero.';
    }

    return null;
  }

  // Valida y guarda los datos del vehículo.
  // Entrada: ninguna; utiliza los valores de los campos del formulario.
  // Salida: ninguna; muestra el resultado y cierra el formulario si se guarda.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final vehiculoOriginal = widget.vehiculo;

    final vehiculo = VehiculoModel(
      uid: vehiculoOriginal?.uid ?? '',
      placas: _placasController.text.trim().toUpperCase(),
      numeroEconomico: _numeroEconomicoController.text.trim(),
      marca: _marcaController.text.trim(),
      modelo: _modeloController.text.trim(),
      anio: int.parse(_anioController.text.trim()),
      estado: vehiculoOriginal?.estado ?? 'activo',
      estadoOperativo: _estadoOperativo,
      kilometrajeActual: vehiculoOriginal?.kilometrajeActual ?? 0,
      intervaloPreventivoKm:
          int.parse(_intervaloPreventivoController.text.trim()),
      operadorUidActual: vehiculoOriginal?.operadorUidActual ?? '',
    );

    setState(() {
      _guardando = true;
    });

    final resultado = _esEdicion
        ? await _viewModel.actualizarVehiculo(vehiculo)
        : await _viewModel.registrarVehiculo(vehiculo);

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (!resultado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudieron guardar los datos.',
        error: true,
      );
      return;
    }

    _mostrarMensaje(
      _viewModel.mensajeExito ??
          (_esEdicion
              ? 'Vehículo actualizado correctamente.'
              : 'Vehículo registrado correctamente.'),
      error: false,
    );

    Navigator.of(context).pop(true);
  }

  // Solicita confirmación para dar de baja o reactivar el vehículo.
  // Entrada: ninguna; utiliza el vehículo asociado al formulario.
  // Salida: ninguna; cambia el estado si el usuario confirma.
  Future<void> _confirmarCambioEstado() async {
    final vehiculo = widget.vehiculo;

    if (vehiculo == null) return;

    final estaDeBaja = vehiculo.estado.toLowerCase() == 'baja';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            estaDeBaja
                ? Icons.directions_car_outlined
                : Icons.warning_amber_rounded,
            color: estaDeBaja ? AppTheme.cfeGreen : AppTheme.alertOrange,
          ),
          title: Text(estaDeBaja ? '¿Reactivar vehículo?' : '¿Dar de baja?'),
          content: Text(
            estaDeBaja
                ? 'El vehículo volverá a aparecer entre las unidades activas.'
                : 'El vehículo dejará de aparecer entre las unidades activas. '
                    'Su información e historial se conservarán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    estaDeBaja ? AppTheme.cfeGreen : AppTheme.errorRed,
                minimumSize: const Size(110, 48),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(estaDeBaja ? 'Reactivar' : 'Dar de baja'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _cambiandoEstado = true;
    });

    final resultado = estaDeBaja
        ? await _viewModel.reactivarVehiculo(vehiculo.uid)
        : await _viewModel.darDeBaja(vehiculo.uid);

    if (!mounted) return;

    setState(() {
      _cambiandoEstado = false;
    });

    if (!resultado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo cambiar el estado del vehículo.',
        error: true,
      );
      return;
    }

    _mostrarMensaje(
      _viewModel.mensajeExito ?? 'Se completó la operación.',
      error: false,
    );

    Navigator.of(context).pop(true);
  }

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: mensaje que se mostrará y error para determinar el color.
  // Salida: ninguna; presenta un SnackBar en la pantalla actual.
  void _mostrarMensaje(String mensaje, {required bool error}) {
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

  // Construye un campo de texto reutilizable para el formulario.
  // Entradas: controlador, etiqueta, icono, función de validación y, de forma
  // opcional, tipo de teclado, texto de ayuda, capitalización y sufijo.
  // Salida: un TextFormField configurado con los valores recibidos.
  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    required String? Function(String?) validar,
    TextInputType tipoTeclado = TextInputType.text,
    String? hint,
    TextCapitalization capitalizacion = TextCapitalization.words,
    String? sufijo,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: tipoTeclado,
      textCapitalization: capitalizacion,
      textInputAction: TextInputAction.next,
      validator: validar,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: hint,
        prefixIcon: Icon(icono),
        suffixText: sufijo,
      ),
    );
  }

  // Construye la interfaz del formulario de registro o edición.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets con los campos y acciones disponibles.
  @override
  Widget build(BuildContext context) {
    final vehiculo = widget.vehiculo;
    final estaDeBaja = vehiculo?.estado.toLowerCase() == 'baja';

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: Text(
          _esEdicion ? 'Editar vehículo' : 'Nuevo vehículo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Center(
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
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Información del vehículo',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Completa los datos generales de la unidad.',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _campo(
                                controller: _placasController,
                                etiqueta: 'Placas',
                                icono: Icons.confirmation_number_outlined,
                                hint: 'Ej. ABC-123-A',
                                capitalizacion: TextCapitalization.characters,
                                validar: (valor) =>
                                    _validarObligatorio(valor, 'las placas'),
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                controller: _numeroEconomicoController,
                                etiqueta: 'Número económico',
                                icono: Icons.numbers_outlined,
                                validar: (valor) => _validarObligatorio(
                                  valor,
                                  'el número económico',
                                ),
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                controller: _marcaController,
                                etiqueta: 'Marca',
                                icono: Icons.factory_outlined,
                                validar: (valor) =>
                                    _validarObligatorio(valor, 'la marca'),
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                controller: _modeloController,
                                etiqueta: 'Modelo',
                                icono: Icons.local_shipping_outlined,
                                validar: (valor) =>
                                    _validarObligatorio(valor, 'el modelo'),
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                controller: _anioController,
                                etiqueta: 'Año',
                                icono: Icons.calendar_month_outlined,
                                tipoTeclado: TextInputType.number,
                                capitalizacion: TextCapitalization.none,
                                validar: _validarAnio,
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                controller: _intervaloPreventivoController,
                                etiqueta:
                                    'Intervalo de mantenimiento preventivo',
                                icono: Icons.build_circle_outlined,
                                tipoTeclado: TextInputType.number,
                                capitalizacion: TextCapitalization.none,
                                sufijo: 'km',
                                validar: _validarIntervalo,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Kilómetros entre cada servicio preventivo. '
                                'El valor inicial es 5,000 km y puedes ajustarlo.',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _estadoOperativo,
                                decoration: const InputDecoration(
                                  labelText: 'Estado operativo',
                                  prefixIcon:
                                      Icon(Icons.build_circle_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'operativo',
                                    child: Text('Operativo'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'en_taller',
                                    child: Text('En taller'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'servicio_proximo',
                                    child: Text('Servicio próximo'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'servicio_vencido',
                                    child: Text('Servicio vencido'),
                                  ),
                                ],
                                onChanged: (valor) {
                                  if (valor != null) {
                                    setState(() {
                                      _estadoOperativo = valor;
                                    });
                                  }
                                },
                              ),
                              if (vehiculo != null) ...[
                                const SizedBox(height: 14),
                                InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Kilometraje actual',
                                    prefixIcon: Icon(Icons.speed_outlined),
                                    filled: true,
                                    fillColor: AppTheme.roleSurface,
                                  ),
                                  child: Text(
                                    '${vehiculo.kilometrajeActual} km',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Este dato se actualiza desde el módulo de kilometraje.',
                                  style: TextStyle(
                                    color: AppTheme.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _guardando || _cambiandoEstado
                                    ? null
                                    : _guardar,
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
                                        _esEdicion ? Icons.check : Icons.add,
                                      ),
                                label: Text(
                                  _guardando
                                      ? 'Guardando…'
                                      : _esEdicion
                                          ? 'Guardar cambios'
                                          : 'Registrar vehículo',
                                ),
                              ),
                              if (_esEdicion) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: estaDeBaja
                                        ? AppTheme.cfeGreen
                                        : AppTheme.errorRed,
                                    side: BorderSide(
                                      color: estaDeBaja
                                          ? AppTheme.cfeGreen
                                          : AppTheme.errorRed,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  onPressed: _guardando || _cambiandoEstado
                                      ? null
                                      : _confirmarCambioEstado,
                                  icon: _cambiandoEstado
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.cfeGreen,
                                          ),
                                        )
                                      : Icon(
                                          estaDeBaja
                                              ? Icons.restore_outlined
                                              : Icons.delete_outline,
                                        ),
                                  label: Text(
                                    _cambiandoEstado
                                        ? 'Procesando…'
                                        : estaDeBaja
                                            ? 'Reactivar vehículo'
                                            : 'Dar de baja',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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