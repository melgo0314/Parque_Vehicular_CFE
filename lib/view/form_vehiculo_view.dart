import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/vehiculos_viewmodel.dart';

class FormVehiculoView extends StatefulWidget {
  final VehiculoModel? vehiculo;

  const FormVehiculoView({
    super.key,
    this.vehiculo,
  });

  @override
  State<FormVehiculoView> createState() => _FormVehiculoViewState();
}

class _FormVehiculoViewState extends State<FormVehiculoView> {
  final _formKey = GlobalKey<FormState>();
  final _viewModel = VehiculosViewModel();

  final _placasController = TextEditingController();
  final _numeroEconomicoController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();

  String _estadoOperativo = 'operativo';
  bool _guardando = false;
  bool _cambiandoEstado = false;

  bool get _esEdicion => widget.vehiculo != null;

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
    }
  }

  @override
  void dispose() {
    _placasController.dispose();
    _numeroEconomicoController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String? _validarObligatorio(String? valor, String nombreCampo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe $nombreCampo.';
    }

    return null;
  }

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

  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    required String? Function(String?) validar,
    TextInputType tipoTeclado = TextInputType.text,
    String? hint,
    TextCapitalization capitalizacion = TextCapitalization.words,
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
      ),
    );
  }

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