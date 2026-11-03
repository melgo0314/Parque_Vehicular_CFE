import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/combustible_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/combustible_viewmodel.dart';

// Proyecto: Sistema de gestión vehicular
// Módulo: Formulario de combustible
// Autor: [Escribe aquí tu nombre]
// Descripción: Permite registrar y editar cargas de combustible.

// Formulario para registrar o editar una carga de combustible.
class FormCombustibleView extends StatefulWidget {
  // Lista de vehículos disponibles para asociar con la carga.
  final List<VehiculoModel> vehiculos;

  // Carga existente; null cuando se registra una carga nueva.
  final CombustibleModel? carga;

  // Crea el formulario con los vehículos y la carga opcional.
  // Entradas: key opcional, vehiculos requeridos y carga opcional para editar.
  // Salida: una instancia de FormCombustibleView.
  const FormCombustibleView({
    super.key,
    required this.vehiculos,
    this.carga,
  });

  // Crea el estado asociado a este formulario.
  // Entrada: ninguna.
  // Salida: el estado que administra el formulario.
  @override
  State<FormCombustibleView> createState() => _FormCombustibleViewState();
}

// Administra el formulario y las operaciones de combustible.
class _FormCombustibleViewState extends State<FormCombustibleView> {
  // Llave utilizada para validar los campos del formulario.
  final _formKey = GlobalKey<FormState>();

  // ViewModel que registra, actualiza y consulta las cargas.
  final _viewModel = CombustibleViewModel();

  // Controlador para el campo de litros.
  final _litrosController = TextEditingController();

  // Controlador para el campo del importe.
  final _importeController = TextEditingController();

  // Controlador para el campo de kilometraje.
  final _kilometrajeController = TextEditingController();

  // Controlador para el campo de observaciones.
  final _observacionesController = TextEditingController();

  // Suscripción a las cargas anteriores del vehículo seleccionado.
  StreamSubscription<List<CombustibleModel>>? _suscripcionCargas;

  // Identificador del vehículo seleccionado.
  String? _vehiculoUid;
  String? _tipoCombustible;

  // Fecha de la carga.
  DateTime _fechaCarga = DateTime.now();

  // Kilometraje de la carga anterior, si existe.
  int? _ultimoKilometraje;

  // Indica si se está guardando el formulario.
  bool _guardando = false;

  // Indica si el formulario está editando una carga existente.
  bool get _esEdicion => widget.carga != null;

  // Tipos de combustible disponibles en el selector.
  static const List<String> _tiposCombustible = [
    'Magna',
    'Premium',
    'Diésel',
  ];

  // Inicializa el formulario con los datos existentes o el vehículo único.
  // Entrada: ninguna.
  // Salida: ninguna; prepara los campos y escucha el kilometraje anterior.
  @override
  void initState() {
    super.initState();

    final carga = widget.carga;

    if (carga != null) {
      _vehiculoUid = carga.vehiculoUid;
      _tipoCombustible = carga.tipoCombustible;
      _fechaCarga = carga.fechaCarga;
      _litrosController.text = carga.litros.toString();
      _importeController.text = carga.importe.toStringAsFixed(2);
      _kilometrajeController.text = carga.kilometraje.toString();
      _observacionesController.text = carga.observaciones;
    } else if (widget.vehiculos.length == 1) {
      _vehiculoUid = widget.vehiculos.first.uid;
    }

    _escucharUltimoKilometraje();
  }

  // Cancela la suscripción y libera los controladores y el ViewModel.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _suscripcionCargas?.cancel();
    _litrosController.dispose();
    _importeController.dispose();
    _kilometrajeController.dispose();
    _observacionesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // Escucha las cargas del vehículo y obtiene el kilometraje anterior más reciente.
  // Entrada: ninguna; consulta el vehículo seleccionado actualmente.
  // Salida: ninguna; actualiza _ultimoKilometraje con los datos recibidos.
  void _escucharUltimoKilometraje() {
    _suscripcionCargas?.cancel();

    final vehiculoUid = _vehiculoUid;
    if (vehiculoUid == null || vehiculoUid.isEmpty) {
      _ultimoKilometraje = null;
      return;
    }

    _suscripcionCargas = _viewModel
        .obtenerCargas(vehiculoUid: vehiculoUid)
        .listen(
      (cargas) {
        final cargasAnteriores = cargas
            .where((carga) => carga.uid != widget.carga?.uid)
            .toList()
          ..sort((a, b) => b.fechaCarga.compareTo(a.fechaCarga));

        if (!mounted) return;

        setState(() {
          _ultimoKilometraje = cargasAnteriores.isEmpty
              ? null
              : cargasAnteriores.first.kilometraje;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _ultimoKilometraje = null);
      },
    );
  }

  // Abre el selector para elegir la fecha de la carga.
  // Entrada: ninguna.
  // Salida: ninguna; actualiza _fechaCarga si se selecciona una fecha.
  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaCarga,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Selecciona la fecha de carga',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fecha != null && mounted) {
      setState(() => _fechaCarga = fecha);
    }
  }

  // Valida y guarda una carga nueva o actualiza una existente.
  // Entrada: ninguna; utiliza los valores actuales del formulario.
  // Salida: ninguna; cierra el formulario si se guarda o muestra un error.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final litros = _parsearDecimal(_litrosController.text);
    final importe = _parsearDecimal(_importeController.text);
    final kilometraje = int.tryParse(_kilometrajeController.text.trim());

    if (litros == null || importe == null || kilometraje == null) return;
    if (_vehiculoUid == null || _tipoCombustible == null) return;

    if (!_esEdicion &&
        _ultimoKilometraje != null &&
        kilometraje <= _ultimoKilometraje!) {
      _mostrarMensaje(
        'El kilometraje debe ser mayor que el último registro '
        '($_ultimoKilometraje km).',
        esError: true,
      );
      return;
    }

    final carga = CombustibleModel(
      uid: widget.carga?.uid ?? '',
      vehiculoUid: _vehiculoUid!,
      // Al editar, conserva el RPE original.
      // En un registro nuevo, el repositorio asigna el RPE de la sesión.
      rpeUsuario: widget.carga?.rpeUsuario ?? '',
      fechaCarga: _fechaCarga,
      litros: litros,
      tipoCombustible: _tipoCombustible!,
      kilometraje: kilometraje,
      importe: importe,
      observaciones: _observacionesController.text.trim(),
    );

    setState(() => _guardando = true);

    final resultado = _esEdicion
        ? await _viewModel.actualizarCarga(carga)
        : await _viewModel.registrarCarga(carga);

    if (!mounted) return;

    setState(() => _guardando = false);

    if (resultado) {
      Navigator.of(context).pop(true);
      return;
    }

    _mostrarMensaje(
      _viewModel.mensajeError ?? 'No se pudo guardar la carga.',
      esError: true,
    );
  }

  // Convierte texto con punto o coma decimal en un número.
  // Entrada: valor de texto que se desea convertir.
  // Salida: número decimal o null si el texto no es válido.
  double? _parsearDecimal(String valor) {
    return double.tryParse(valor.trim().replaceAll(',', '.'));
  }

  // Valida que el campo contenga un número decimal mayor que cero.
  // Entradas: valor escrito y campo, nombre utilizado en el mensaje.
  // Salida: mensaje de error si el valor no es válido; de lo contrario, null.
  String? _validarDecimal(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa $campo.';
    }

    final numero = _parsearDecimal(valor);
    if (numero == null || numero <= 0) {
      return '$campo debe ser mayor que cero.';
    }

    return null;
  }

  // Da formato a una fecha para mostrarla en el formulario.
  // Entrada: fecha que se desea presentar.
  // Salida: fecha con día, mes abreviado y año.
  String _fechaFormateada(DateTime fecha) {
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

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: mensaje que se presentará y esError para determinar el color.
  // Salida: ninguna; muestra un SnackBar en la pantalla.
  void _mostrarMensaje(String mensaje, {required bool esError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // Construye una etiqueta de texto para los campos del formulario.
  // Entrada: texto que se mostrará.
  // Salida: widget de texto con el estilo definido.
  Widget _etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryText,
      ),
    );
  }

  // Construye la pantalla que se muestra cuando no hay vehículos.
  // Entrada: ninguna.
  // Salida: widget informativo con una acción para volver.
  Widget _vistaSinVehiculos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              size: 48,
              color: AppTheme.cfeGreen,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay vehículos disponibles para registrar una carga.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye los campos y las acciones del formulario.
  // Entrada: lista de vehículos que aparecerán en el selector.
  // Salida: widget Form con los datos de la carga.
  Widget _contenidoFormulario(List<VehiculoModel> vehiculos) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _esEdicion ? 'Editar carga de combustible' : 'Datos de la carga',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 20),

          _etiqueta('Vehículo'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: vehiculos.any((v) => v.uid == _vehiculoUid)
                ? _vehiculoUid
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            hint: const Text('Selecciona un vehículo'),
            items: vehiculos.map((vehiculo) {
              return DropdownMenuItem<String>(
                value: vehiculo.uid,
                child: Text(
                  '${vehiculo.numeroEconomico} • '
                  '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _guardando
                ? null
                : (valor) {
                    setState(() {
                      _vehiculoUid = valor;
                      _ultimoKilometraje = null;
                    });
                    _escucharUltimoKilometraje();
                  },
            validator: (valor) =>
                valor == null ? 'Selecciona un vehículo.' : null,
          ),

          const SizedBox(height: 16),
          _etiqueta('Fecha de la carga'),
          const SizedBox(height: 6),
          InkWell(
            onTap: _guardando ? null : _seleccionarFecha,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(_fechaFormateada(_fechaCarga)),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Litros'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _litrosController,
                      enabled: !_guardando,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*([.,]\d{0,2})?$'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        suffixText: 'L',
                      ),
                      validator: (valor) =>
                          _validarDecimal(valor, 'los litros'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Importe'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _importeController,
                      enabled: !_guardando,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*([.,]\d{0,2})?$'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        prefixText: '\$ ',
                      ),
                      validator: (valor) =>
                          _validarDecimal(valor, 'el importe'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _etiqueta('Tipo de combustible'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _tipoCombustible,
            isExpanded: true,
            decoration: const InputDecoration(),
            hint: const Text('Selecciona el tipo'),
            items: _tiposCombustible.map((tipo) {
              return DropdownMenuItem<String>(
                value: tipo,
                child: Text(tipo),
              );
            }).toList(),
            onChanged: _guardando
                ? null
                : (valor) => setState(() => _tipoCombustible = valor),
            validator: (valor) => valor == null
                ? 'Selecciona el tipo de combustible.'
                : null,
          ),

          const SizedBox(height: 16),
          _etiqueta('Kilometraje al cargar'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _kilometrajeController,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: 'km',
            ),
            validator: (valor) {
              if (valor == null || valor.trim().isEmpty) {
                return 'Ingresa el kilometraje.';
              }

              final km = int.tryParse(valor.trim());
              if (km == null || km < 0) {
                return 'Ingresa un kilometraje válido.';
              }

              return null;
            },
          ),
          const SizedBox(height: 6),
          Text(
            _ultimoKilometraje == null
                ? 'Aún no hay cargas anteriores para este vehículo.'
                : 'Último registro: $_ultimoKilometraje km',
            style: const TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _observacionesController,
            enabled: !_guardando,
            minLines: 2,
            maxLines: 4,
            maxLength: 250,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              hintText: 'Agrega algún detalle de la carga',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
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
                    ? 'Guardando...'
                    : _esEdicion
                        ? 'Guardar cambios'
                        : 'Guardar carga',
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

  // Construye la pantalla del formulario o el aviso de que no hay vehículos.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets para registrar o editar una carga.
  @override
  Widget build(BuildContext context) {
    final vehiculos = widget.vehiculos
        .where((vehiculo) => vehiculo.uid.trim().isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar carga' : 'Registrar carga'),
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
      ),
      body: SafeArea(
        child: vehiculos.isEmpty
            ? _vistaSinVehiculos()
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
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
                        child: _contenidoFormulario(vehiculos),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}