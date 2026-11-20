import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';
import '../models/documento_model.dart';
import '../models/expediente_model.dart';
import '../viewmodel/expediente_viewmodel.dart';

// Formulario para registrar o editar documentos del expediente de un vehículo.
class FormExpedienteView extends StatefulWidget {
  // Vehículo al que pertenece el documento.
  final VehiculoModel vehiculo;

  // Catálogo de tipos de documentos disponibles.
  final List<DocumentoModel> documentos;

  // Documento que se editará; es null cuando se registra uno nuevo.
  final ExpedienteModel? expediente;

  // Crea el formulario y recibe los datos necesarios.
  const FormExpedienteView({
    super.key,
    required this.vehiculo,
    required this.documentos,
    this.expediente,
  });

  @override
  State<FormExpedienteView> createState() => _FormExpedienteViewState();
}

// Estado y comportamiento del formulario de expedientes.
class _FormExpedienteViewState extends State<FormExpedienteView> {
  // Llave para validar los campos del formulario.
  final _formKey = GlobalKey<FormState>();

  // ViewModel que registra y actualiza los expedientes.
  final _viewModel = ExpedienteViewModel();

  // Controlador para las observaciones.
  final _observacionesController = TextEditingController();

  // Tipo de documento seleccionado.
  String? _documentoUid;

  // Archivo seleccionado para registrar o reemplazar.
  PlatformFile? _archivoSeleccionado;

  // Bytes del archivo seleccionado.
  Uint8List? _archivoBytes;

  // Tipo MIME del archivo seleccionado.
  String? _tipoMime;

  // Fecha de vencimiento del documento.
  DateTime? _fechaVencimiento;

  // RPE del usuario que realiza el registro.
  String _rpeUsuario = '';

  // Indica si se está guardando la información.
  bool _guardando = false;

  // Indica si se está consultando el RPE del usuario.
  bool _cargandoUsuario = false;

  // Indica si el formulario está en modo edición.
  bool get _esEdicion => widget.expediente != null;

  @override
  void initState() {
    super.initState();

    // Recupera los datos cuando se está editando un documento.
    if (_esEdicion) {
      _cargarDatosExpediente();
    }

    // Obtiene el RPE del usuario que inició sesión.
    _obtenerRpeUsuario();
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // Recupera la información del documento que se editará.
  void _cargarDatosExpediente() {
    final expediente = widget.expediente!;

    _documentoUid = expediente.documentoUid;
    _fechaVencimiento = expediente.fechaVencimiento;

    _observacionesController.text = expediente.observaciones;
  }

  // Obtiene el RPE del usuario desde Firestore.
  Future<void> _obtenerRpeUsuario() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    setState(() {
      _cargandoUsuario = true;
    });

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(usuario.uid)
          .get();

      if (!mounted) return;

      if (documento.exists) {
        setState(() {
          _rpeUsuario = documento.data()?['rpe']?.toString() ?? '';
        });
      }
    } catch (_) {
      // El formulario puede continuar aunque no se obtenga el RPE.
    } finally {
      if (mounted) {
        setState(() {
          _cargandoUsuario = false;
        });
      }
    }
  }

  // Permite seleccionar un archivo PDF o una imagen.
  Future<void> _seleccionarArchivo() async {
    try {
      final archivo = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      // Si el usuario cancela la selección, no realiza cambios.
      if (archivo == null) {
        return;
      }

      // Obtiene los bytes del archivo seleccionado.
      final bytes = await archivo.readAsBytes();

      if (bytes.isEmpty) {
        _mostrarMensaje(
          'No fue posible leer el archivo seleccionado.',
          false,
        );
        return;
      }

      final extension = archivo.extension?.toLowerCase();

      String tipoMime;

      if (extension == 'pdf') {
        tipoMime = 'application/pdf';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        tipoMime = 'image/jpeg';
      } else if (extension == 'png') {
        tipoMime = 'image/png';
      } else {
        _mostrarMensaje(
          'El formato del archivo no es válido.',
          false,
        );
        return;
      }

      setState(() {
        _archivoSeleccionado = archivo;
        _archivoBytes = bytes;
        _tipoMime = tipoMime;
      });
    } catch (error) {
      _mostrarMensaje(
        'Ocurrió un error al seleccionar el archivo.',
        false,
      );
    }
  }

  // Permite seleccionar la fecha de vencimiento.
  Future<void> _seleccionarFecha() async {
    final fechaActual = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? fechaActual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha de vencimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.cfeGreen,
                  onPrimary: AppTheme.pureWhite,
                  surface: AppTheme.pureWhite,
                ),
          ),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      setState(() {
        _fechaVencimiento = fecha;
      });
    }
  }

  // Convierte una fecha al formato día/mes/año.
  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    return '$dia/$mes/$anio';
  }

  // Elimina la selección del archivo.
  void _quitarArchivo() {
    setState(() {
      _archivoSeleccionado = null;
      _archivoBytes = null;
      _tipoMime = null;
    });
  }

  // Muestra mensajes de éxito o error.
  void _mostrarMensaje(String? mensaje, bool correcto) {
    if (mensaje == null || mensaje.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: correcto
              ? AppTheme.operationalText
              : AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // Registra o actualiza la información del expediente.
  Future<void> _guardarExpediente() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Al registrar es obligatorio seleccionar un archivo.
    if (!_esEdicion && _archivoBytes == null) {
      _mostrarMensaje(
        'Selecciona el archivo del documento.',
        false,
      );
      return;
    }

    if (_documentoUid == null || _documentoUid!.isEmpty) {
      _mostrarMensaje(
        'Selecciona el tipo de documento.',
        false,
      );
      return;
    }

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      _mostrarMensaje(
        'No se encontró una sesión de usuario activa.',
        false,
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    // Recupera los datos anteriores cuando se está editando.
    final expedienteAnterior = widget.expediente;

    // Construye el modelo con los datos del formulario.
    final expediente = ExpedienteModel(
      uid: expedienteAnterior?.uid ?? '',
      vehiculoUid: widget.vehiculo.uid,
      documentoUid: _documentoUid!,
      nombreArchivo: _archivoSeleccionado?.name ??
          expedienteAnterior?.nombreArchivo ??
          '',
      archivoUrl: expedienteAnterior?.archivoUrl ?? '',
      rutaStorage: expedienteAnterior?.rutaStorage ?? '',
      tipoMime: _tipoMime ??
          expedienteAnterior?.tipoMime ??
          '',
      fechaCarga:
          expedienteAnterior?.fechaCarga ?? DateTime.now(),
      fechaVencimiento: _fechaVencimiento,
      observaciones: _observacionesController.text.trim(),
      usuarioUid: expedienteAnterior?.usuarioUid ?? usuario.uid,
      rpeUsuario: expedienteAnterior?.rpeUsuario ?? _rpeUsuario,
    );

    bool resultado;

    if (_esEdicion) {
      // Actualiza los datos y, si se seleccionó uno nuevo,
      // también reemplaza el archivo almacenado.
      resultado = await _viewModel.actualizarExpediente(
        expediente: expediente,
        archivoBytes: _archivoBytes,
      );
    } else {
      // Registra un expediente nuevo.
      resultado = await _viewModel.registrarExpediente(
        expediente: expediente,
        archivoBytes: _archivoBytes!,
      );
    }

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (resultado) {
      _mostrarMensaje(
        _viewModel.mensajeExito,
        true,
      );

      // Regresa a la vista anterior e indica que hubo cambios.
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError,
        false,
      );
    }
  }

  // Campo para seleccionar el tipo de documento.
  Widget _campoTipoDocumento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de documento',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _documentoUid,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Selecciona un tipo de documento',
            prefixIcon: Icon(Icons.description_outlined),
          ),
          items: widget.documentos.map((documento) {
            return DropdownMenuItem<String>(
              value: documento.uid,
              child: Text(
                documento.nombre,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _esEdicion
              ? null
              : (valor) {
                  setState(() {
                    _documentoUid = valor;
                  });
                },
          validator: (valor) {
            if (valor == null || valor.isEmpty) {
              return 'Selecciona un tipo de documento.';
            }

            return null;
          },
        ),
        if (_esEdicion)
          const Padding(
            padding: EdgeInsets.only(top: 5, left: 4),
            child: Text(
              'El tipo de documento no se puede modificar durante la edición.',
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // Campo para seleccionar y mostrar el archivo.
  Widget _campoArchivo() {
    final nombreArchivo = _archivoSeleccionado?.name ??
        (_esEdicion ? widget.expediente!.nombreArchivo : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Archivo del documento',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _guardando ? null : _seleccionarArchivo,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  nombreArchivo == null
                      ? Icons.cloud_upload_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 38,
                  color: AppTheme.cfeGreen,
                ),
                const SizedBox(height: 10),
                Text(
                  nombreArchivo ?? 'Seleccionar archivo',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Formatos permitidos: PDF, JPG, JPEG y PNG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
                if (_esEdicion && _archivoSeleccionado == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Selecciona otro archivo únicamente si deseas reemplazarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_archivoSeleccionado != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _guardando ? null : _quitarArchivo,
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorRed,
              ),
              label: const Text(
                'Quitar archivo',
                style: TextStyle(
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Campo para seleccionar la fecha de vencimiento.
  Widget _campoFechaVencimiento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha de vencimiento',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _guardando ? null : _seleccionarFecha,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppTheme.cfeGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fechaVencimiento == null
                        ? 'Seleccionar fecha (opcional)'
                        : _formatearFecha(_fechaVencimiento!),
                    style: TextStyle(
                      color: _fechaVencimiento == null
                          ? AppTheme.secondaryText
                          : AppTheme.primaryText,
                    ),
                  ),
                ),
                if (_fechaVencimiento != null)
                  IconButton(
                    onPressed: _guardando
                        ? null
                        : () {
                            setState(() {
                              _fechaVencimiento = null;
                            });
                          },
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.secondaryText,
                    ),
                    tooltip: 'Quitar fecha',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Campo para capturar observaciones.
  Widget _campoObservaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _observacionesController,
          enabled: !_guardando,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Escribe alguna observación del documento...',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 55),
              child: Icon(Icons.notes_outlined),
            ),
          ),
        ),
      ],
    );
  }

  // Muestra la información del vehículo relacionado.
  Widget _informacionVehiculo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.avatarSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_outlined,
            color: AppTheme.avatarText,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.vehiculo.marca} ${widget.vehiculo.modelo}',
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Núm. económico: ${widget.vehiculo.numeroEconomico}',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Placas: ${widget.vehiculo.placas}',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
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
        title: Text(
          _esEdicion ? 'Editar documento' : 'Agregar documento',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 650,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _esEdicion
                            ? 'Actualizar expediente'
                            : 'Registrar expediente',
                        style: const TextStyle(
                          color: AppTheme.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _esEdicion
                            ? 'Modifica la información del documento seleccionado.'
                            : 'Completa la información y adjunta el archivo correspondiente al vehículo.',
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Información del vehículo.
                      _informacionVehiculo(),

                      const SizedBox(height: 22),

                      // Tipo de documento.
                      _campoTipoDocumento(),

                      const SizedBox(height: 20),

                      // Archivo PDF o imagen.
                      _campoArchivo(),

                      const SizedBox(height: 20),

                      // Fecha de vencimiento.
                      _campoFechaVencimiento(),

                      const SizedBox(height: 20),

                      // Observaciones.
                      _campoObservaciones(),

                      const SizedBox(height: 24),

                      // Botón para guardar la información.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _guardando || _cargandoUsuario
                              ? null
                              : _guardarExpediente,
                          icon: _guardando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.pureWhite,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _guardando
                                ? 'Guardando...'
                                : _esEdicion
                                    ? 'Guardar cambios'
                                    : 'Registrar documento',
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botón para cancelar y regresar.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _guardando
                              ? null
                              : () {
                                  Navigator.pop(context, false);
                                },
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}