import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../viewmodel/usuarios_viewmodel.dart';

class FormUsuarioView extends StatefulWidget {
  final UserModel? usuario;

  const FormUsuarioView({
    super.key,
    this.usuario,
  });

  @override
  State<FormUsuarioView> createState() => _FormUsuarioViewState();
}

class _FormUsuarioViewState extends State<FormUsuarioView> {
  final _formKey = GlobalKey<FormState>();
  final _viewModel = UsuariosViewModel();
  final _selectorImagen = ImagePicker();

  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _rpeController = TextEditingController();
  final _telefonoController = TextEditingController();

  String _rol = 'operador';
  File? _fotoLicencia;
  bool _mostrarContrasena = false;
  bool _guardando = false;
  bool _eliminando = false;

  bool get _esEdicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();

    final usuario = widget.usuario;

    if (usuario != null) {
      _nombreController.text = usuario.nombreCompleto;
      _correoController.text = usuario.correo;
      _rpeController.text = usuario.rpe;
      _telefonoController.text = usuario.telefono;
      _rol = usuario.rol.toLowerCase();
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _rpeController.dispose();
    _telefonoController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  List<String> _separarNombre(String nombreCompleto) {
    final partes = nombreCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.length >= 3) {
      return [
        partes.sublist(0, partes.length - 2).join(' '),
        partes[partes.length - 2],
        partes.last,
      ];
    }

    if (partes.length == 2) return [partes[0], partes[1], ''];
    if (partes.length == 1) return [partes[0], '', ''];

    return ['', '', ''];
  }

  String? _validarObligatorio(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe $campo.';
    }

    return null;
  }

  String? _validarCorreo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe el correo electrónico.';
    }

    final correoValido =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor.trim());

    if (!correoValido) {
      return 'Escribe un correo válido.';
    }

    return null;
  }

  String? _validarContrasena(String? valor) {
    if (_esEdicion && (valor == null || valor.isEmpty)) {
      return null;
    }

    if (valor == null || valor.isEmpty) {
      return 'Escribe una contraseña.';
    }

    if (valor.length < 8) {
      return 'Usa al menos 8 caracteres.';
    }

    return null;
  }

  Future<void> _seleccionarLicencia() async {
    try {
      final imagen = await _selectorImagen.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (imagen != null && mounted) {
        setState(() {
          _fotoLicencia = File(imagen.path);
        });
      }
    } catch (error) {
      debugPrint('No se pudo abrir la cámara: $error');

      _mostrarMensaje(
        'No se pudo abrir la cámara. Revisa los permisos del dispositivo.',
        error: true,
      );
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_esEdicion && _rol == 'operador' && _fotoLicencia == null) {
      _mostrarMensaje(
        'Toma una fotografía de la licencia del operador.',
        error: true,
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    final nombre = _separarNombre(_nombreController.text);
    bool guardado;

    if (_esEdicion) {
      final usuarioActualizado = widget.usuario!.copyWith(
        nombre: nombre[0],
        apellidoP: nombre[1],
        apellidoM: nombre[2],
        correo: _correoController.text.trim().toLowerCase(),
        rol: _rol,
        rpe: _rpeController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );

      guardado = await _viewModel.actualizarUsuarioCompleto(
        usuario: usuarioActualizado,
        nuevaContrasena: _contrasenaController.text.isEmpty
            ? null
            : _contrasenaController.text,
      );
    } else {
      guardado = await _viewModel.registrarUsuario(
        nombre: nombre[0],
        apellidoP: nombre[1],
        apellidoM: nombre[2],
        correo: _correoController.text.trim().toLowerCase(),
        contrasena: _contrasenaController.text,
        rol: _rol,
        rpe: _rpeController.text.trim(),
        telefono: _telefonoController.text.trim(),
        fotoLicencia: _fotoLicencia,
      );
    }

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (!guardado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudieron guardar los datos.',
        error: true,
      );
      return;
    }

    _mostrarMensaje(
      _esEdicion
          ? 'Los cambios se guardaron correctamente.'
          : 'El usuario se registró correctamente.',
      error: false,
    );

    Navigator.of(context).pop(true);
  }

  Future<void> _confirmarEliminacion() async {
    final usuario = widget.usuario;

    if (usuario == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.alertOrange,
        ),
        title: const Text('¿Eliminar usuario?'),
        content: Text(
          'Se eliminará la cuenta de ${usuario.nombreCompleto}. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: AppTheme.pureWhite,
              minimumSize: const Size(100, 48),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _eliminando = true;
    });

    final eliminado = await _viewModel.eliminarUsuario(usuario.uid);

    if (!mounted) return;

    setState(() {
      _eliminando = false;
    });

    if (!eliminado) {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo eliminar el usuario.',
        error: true,
      );
      return;
    }

    _mostrarMensaje('El usuario se eliminó correctamente.', error: false);
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

  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    String? hint,
    String? helper,
    TextInputType tipoTeclado = TextInputType.text,
    String? Function(String?)? validar,
    bool ocultar = false,
    Widget? sufijo,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: tipoTeclado,
      textCapitalization: tipoTeclado == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      obscureText: ocultar,
      validator: validar,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: hint,
        helperText: helper,
        prefixIcon: Icon(icono),
        suffixIcon: sufijo,
        filled: true,
        fillColor: AppTheme.pureWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esEdicion ? 'Editar usuario' : 'Nuevo usuario';

    return Scaffold(
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Completa los datos del usuario.',
                          style: TextStyle(color: AppTheme.secondaryText),
                        ),
                        const SizedBox(height: 20),
                        _campo(
                          controller: _nombreController,
                          etiqueta: 'Nombre completo',
                          icono: Icons.person_outline,
                          hint: 'Nombre y apellidos',
                          validar: (valor) =>
                              _validarObligatorio(valor, 'el nombre completo'),
                        ),
                        const SizedBox(height: 14),
                        _campo(
                          controller: _correoController,
                          etiqueta: 'Correo electrónico',
                          icono: Icons.email_outlined,
                          hint: 'nombre@ejemplo.mx',
                          tipoTeclado: TextInputType.emailAddress,
                          validar: _validarCorreo,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _rol,
                          decoration: const InputDecoration(
                            labelText: 'Rol',
                            prefixIcon: Icon(Icons.shield_outlined),
                            filled: true,
                            fillColor: AppTheme.pureWhite,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'operador',
                              child: Text('Operador'),
                            ),
                            DropdownMenuItem(
                              value: 'administrador',
                              child: Text('Administrador'),
                            ),
                            DropdownMenuItem(
                              value: 'superusuario',
                              child: Text('Superusuario'),
                            ),
                          ],
                          onChanged: (valor) {
                            if (valor != null) {
                              setState(() {
                                _rol = valor;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        _campo(
                          controller: _contrasenaController,
                          etiqueta: _esEdicion
                              ? 'Nueva contraseña (opcional)'
                              : 'Contraseña',
                          icono: Icons.lock_outline,
                          hint: _esEdicion
                              ? 'Déjala en blanco para conservar la actual'
                              : 'Mínimo 8 caracteres',
                          helper: _esEdicion
                              ? 'Déjala en blanco para conservar la contraseña actual.'
                              : 'La contraseña debe tener al menos 8 caracteres.',
                          ocultar: !_mostrarContrasena,
                          validar: _validarContrasena,
                          sufijo: IconButton(
                            tooltip: _mostrarContrasena
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () {
                              setState(() {
                                _mostrarContrasena = !_mostrarContrasena;
                              });
                            },
                            icon: Icon(
                              _mostrarContrasena
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _campo(
                          controller: _rpeController,
                          etiqueta: 'RPE',
                          icono: Icons.badge_outlined,
                          validar: (valor) =>
                              _validarObligatorio(valor, 'el RPE'),
                        ),
                        const SizedBox(height: 14),
                        _campo(
                          controller: _telefonoController,
                          etiqueta: 'Teléfono',
                          icono: Icons.phone_outlined,
                          tipoTeclado: TextInputType.phone,
                          validar: (valor) =>
                              _validarObligatorio(valor, 'el teléfono'),
                        ),
                        if (!_esEdicion && _rol == 'operador') ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Fotografía de la licencia',
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              foregroundColor: AppTheme.cfeGreen,
                              side: const BorderSide(
                                color: AppTheme.cfeGreen,
                              ),
                            ),
                            onPressed: _seleccionarLicencia,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              _fotoLicencia == null
                                  ? 'Tomar fotografía'
                                  : 'Cambiar fotografía',
                            ),
                          ),
                          if (_fotoLicencia != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _fotoLicencia!,
                                height: 160,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: AppTheme.cfeGreen,
                            foregroundColor: AppTheme.pureWhite,
                          ),
                          onPressed:
                              _guardando || _eliminando ? null : _guardar,
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
                                  _esEdicion
                                      ? Icons.check
                                      : Icons.person_add_alt_1,
                                ),
                          label: Text(
                            _guardando
                                ? 'Guardando…'
                                : _esEdicion
                                    ? 'Guardar cambios'
                                    : 'Registrar usuario',
                          ),
                        ),
                        if (_esEdicion) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              foregroundColor: AppTheme.errorRed,
                              side: const BorderSide(
                                color: AppTheme.errorRed,
                              ),
                            ),
                            onPressed: _guardando || _eliminando
                                ? null
                                : _confirmarEliminacion,
                            icon: _eliminando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.errorRed,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                            label: Text(
                              _eliminando
                                  ? 'Eliminando…'
                                  : 'Eliminar usuario',
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
      ),
    );
  }
}