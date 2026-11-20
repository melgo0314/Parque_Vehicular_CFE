import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../viewmodel/usuarios_viewmodel.dart';

// Formulario para crear o editar un usuario.
class FormUsuarioView extends StatefulWidget {
  // Usuario que se editará; es null cuando se registra uno nuevo.
  final UserModel? usuario;

  // Crea el formulario y recibe opcionalmente un usuario existente.
  // Entradas: key opcional y usuario opcional para el modo de edición.
  // Salida: una instancia de FormUsuarioView.
  const FormUsuarioView({
    super.key,
    this.usuario,
  });

  // Crea el estado asociado al formulario.
  // Entrada: ninguna.
  // Salida: el estado que administra los campos y las operaciones.
  @override
  State<FormUsuarioView> createState() => _FormUsuarioViewState();
}

// Estado y comportamiento del formulario de usuarios.
class _FormUsuarioViewState extends State<FormUsuarioView> {
  // Llave utilizada para validar los campos del formulario.
  final _formKey = GlobalKey<FormState>();

  // ViewModel que registra, actualiza y elimina usuarios.
  final _viewModel = UsuariosViewModel();

  // Controlador para el nombre completo.
  final _nombreController = TextEditingController();

  // Controlador para el correo electrónico.
  final _correoController = TextEditingController();

  // Controlador para la contraseña.
  final _contrasenaController = TextEditingController();

  // Controlador para el RPE.
  final _rpeController = TextEditingController();

  // Controlador para el teléfono.
  final _telefonoController = TextEditingController();

  // Rol seleccionado para el usuario.
  String _rol = 'operador';

  // Archivo de licencia seleccionado.
  PlatformFile? _archivoLicencia;

  // Contenido del archivo de licencia seleccionado.
  Uint8List? _bytesLicencia;

  // Indica si la contraseña se muestra en el campo.
  bool _mostrarContrasena = false;

  // Indica si se están guardando los datos.
  bool _guardando = false;

  // Indica si se está eliminando el usuario.
  bool _eliminando = false;

  // Indica si el formulario está editando un usuario existente.
  bool get _esEdicion => widget.usuario != null;

  // Inicializa el formulario con los datos del usuario existente.
  // Entrada: ninguna; consulta el usuario recibido por el widget.
  // Salida: ninguna; llena los campos con sus datos.
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

  // Libera los controladores al cerrar el formulario.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _rpeController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  // Separa un nombre completo en nombre y apellidos.
  // Entrada: nombreCompleto escrito por el usuario.
  // Salida: lista con nombre, primer apellido y segundo apellido.
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

  // Valida que un campo obligatorio tenga contenido.
  // Entradas: valor del campo y campo, nombre que se incluirá en el mensaje.
  // Salida: mensaje de error si el campo está vacío; de lo contrario, null.
  String? _validarObligatorio(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Escribe $campo.';
    }

    return null;
  }

  // Valida que el correo tenga un formato aceptable.
  // Entrada: valor escrito en el campo de correo.
  // Salida: mensaje de error si el correo no es válido; de lo contrario, null.
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

  // Valida la contraseña según se registre o edite un usuario.
  // Entrada: valor escrito en el campo de contraseña.
  // Salida: mensaje de error si falta o no alcanza la longitud requerida;
  // devuelve null si es válida o si se dejó vacía durante una edición.
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

  // Abre el selector de archivos y carga una licencia PDF o de imagen.
  // Entrada: ninguna.
  // Salida: ninguna; guarda el archivo y sus bytes, o muestra un mensaje de error.
  Future<void> _seleccionarLicencia() async {
    try {
      final archivo = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (archivo == null) return;

      final bytes = await archivo.readAsBytes();

      if (bytes.isEmpty) {
        _mostrarMensaje(
          'El archivo seleccionado está vacío.',
          error: true,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _archivoLicencia = archivo;
        _bytesLicencia = bytes;
      });
    } catch (error) {
      debugPrint('Error al seleccionar la licencia: $error');
      _mostrarMensaje(
        'No se pudo leer el archivo. Intenta seleccionarlo de nuevo.',
        error: true,
      );
    }
  }

  // Quita la licencia seleccionada y limpia sus datos de memoria.
  // Entrada: ninguna.
  // Salida: ninguna; limpia el archivo y sus bytes seleccionados.
  void _quitarLicencia() {
    setState(() {
      _archivoLicencia = null;
      _bytesLicencia = null;
    });
  }

  // Valida y guarda los datos del usuario.
  // Entrada: ninguna; utiliza los valores de los campos del formulario.
  // Salida: ninguna; muestra errores o cierra el formulario si se guarda.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_esEdicion &&
        _rol == 'operador' &&
        (_archivoLicencia == null || _bytesLicencia == null)) {
      _mostrarMensaje(
        'Selecciona el documento de licencia del operador.',
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
        archivoLicencia: _bytesLicencia,
        nombreArchivoLicencia: _archivoLicencia?.name,
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

  // Solicita confirmación antes de eliminar el usuario actual.
  // Entrada: ninguna; utiliza el usuario asociado al formulario.
  // Salida: ninguna; elimina el usuario si se confirma y muestra el resultado.
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

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: mensaje que se mostrará y error para determinar el color.
  // Salida: ninguna; presenta un SnackBar si la pantalla sigue activa.
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

  // Construye un campo de texto reutilizable para el formulario.
  // Entradas: controller, etiqueta, icono y opciones para teclado, ayuda,
  // validación, ocultación de texto y sufijo.
  // Salida: un TextFormField configurado con los valores recibidos.
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

  // Construye la vista previa del documento de licencia seleccionado.
  // Entrada: ninguna; consulta el archivo y sus bytes actuales.
  // Salida: vista previa PDF, imagen o widget vacío si no hay archivo.
  Widget _vistaDocumentoSeleccionado() {
    final archivo = _archivoLicencia;
    final bytes = _bytesLicencia;

    if (archivo == null || bytes == null) {
      return const SizedBox.shrink();
    }

    final extension = archivo.extension?.toLowerCase() ?? '';
    final esPdf = extension == 'pdf';

    if (esPdf) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf,
              color: Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                archivo.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Quitar documento',
              onPressed: _guardando ? null : _quitarLicencia,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 120,
                alignment: Alignment.center,
                color: AppTheme.roleSurface,
                child: const Text('No se pudo mostrar la imagen.'),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _guardando ? null : _quitarLicencia,
            icon: const Icon(Icons.close),
            label: const Text('Quitar imagen'),
          ),
        ),
      ],
    );
  }

  // Construye la interfaz de registro o edición de usuario.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets con los campos y acciones disponibles.
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
                          onChanged: _guardando
                              ? null
                              : (valor) {
                                  if (valor != null) {
                                    setState(() => _rol = valor);
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
                            'Documento de la licencia',
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Puedes seleccionar un archivo PDF, JPG o PNG.',
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 13,
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
                            onPressed:
                                _guardando ? null : _seleccionarLicencia,
                            icon: const Icon(Icons.file_upload_outlined),
                            label: Text(
                              _archivoLicencia == null
                                  ? 'Seleccionar documento'
                                  : 'Cambiar documento',
                            ),
                          ),
                          if (_archivoLicencia != null) ...[
                            const SizedBox(height: 12),
                            _vistaDocumentoSeleccionado(),
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