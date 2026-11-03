import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../viewmodel/usuarios_viewmodel.dart';
import 'form_usuario_view.dart';

// Pantalla para consultar y administrar usuarios.
class UsuariosView extends StatefulWidget {
  // Crea la pantalla de usuarios.
  // Entrada: key opcional para identificar el widget.
  // Salida: una instancia de UsuariosView.
  const UsuariosView({super.key});

  // Crea el estado asociado a la pantalla.
  // Entrada: ninguna.
  // Salida: el estado que administra la búsqueda, filtros y acciones.
  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

// Estado y comportamiento de la pantalla de usuarios.
class _UsuariosViewState extends State<UsuariosView> {
  // ViewModel que consulta y administra usuarios.
  final UsuariosViewModel _viewModel = UsuariosViewModel();

  // Controlador del campo de búsqueda.
  final TextEditingController _busquedaController = TextEditingController();

  // Texto escrito en el campo de búsqueda.
  String _busqueda = '';

  // Rol seleccionado para filtrar la lista.
  String _rolFiltro = 'todos';

  // Identificador del usuario que se está eliminando.
  String? _uidEliminando;

  // Libera el controlador y el ViewModel al cerrar la pantalla.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _busquedaController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // Convierte el identificador interno de un rol en una etiqueta legible.
  // Entrada: rol guardado en el perfil del usuario.
  // Salida: nombre del rol para mostrar en la interfaz.
  String _nombreRol(String rol) {
    switch (rol.trim().toLowerCase()) {
      case 'administrador':
        return 'Administrador';
      case 'operador':
        return 'Operador';
      case 'superusuario':
        return 'Superusuario';
      default:
        return rol;
    }
  }

  // Obtiene las iniciales del nombre y primer apellido del usuario.
  // Entrada: usuario del que se obtendrán las iniciales.
  // Salida: iniciales en mayúsculas o un signo de interrogación si no hay nombre.
  String _iniciales(UserModel usuario) {
    final nombre = usuario.nombre.trim();
    final apellido = usuario.apellidoP.trim();

    final inicialNombre = nombre.isEmpty ? '' : nombre[0].toUpperCase();
    final inicialApellido = apellido.isEmpty ? '' : apellido[0].toUpperCase();

    if (inicialNombre.isEmpty && inicialApellido.isEmpty) {
      return '?';
    }

    return '$inicialNombre$inicialApellido';
  }

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: mensaje que se presentará y error para determinar el color.
  // Salida: ninguna; muestra un SnackBar si la pantalla sigue activa.
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

  // Abre el formulario para crear o editar un usuario.
  // Entrada: usuario opcional; si se proporciona, se abrirá en modo edición.
  // Salida: ninguna; el flujo de Firestore actualiza la lista automáticamente.
  Future<void> _abrirFormulario({UserModel? usuario}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormUsuarioView(usuario: usuario),
      ),
    );

    // El flujo de Firestore actualiza la lista automáticamente.
  }

  // Solicita confirmación y elimina el usuario seleccionado.
  // Entrada: usuario que se desea eliminar.
  // Salida: ninguna; muestra el resultado de la eliminación.
  Future<void> _confirmarEliminacion(UserModel usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.alertOrange,
            size: 32,
          ),
          title: const Text('¿Eliminar usuario?'),
          content: Text(
            'Se eliminará la cuenta de ${usuario.nombreCompleto}. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 48),
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(100, 48),
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() => _uidEliminando = usuario.uid);

    final eliminado = await _viewModel.eliminarUsuario(usuario.uid);

    if (!mounted) return;

    setState(() => _uidEliminando = null);

    _mostrarMensaje(
      eliminado
          ? (_viewModel.mensajeExito ?? 'Usuario eliminado correctamente.')
          : (_viewModel.mensajeError ?? 'No se pudo eliminar el usuario.'),
      error: !eliminado,
    );
  }

  // Construye la tarjeta con los datos y acciones de un usuario.
  // Entrada: usuario que se mostrará.
  // Salida: una tarjeta con sus datos, rol y botones para editar o eliminar.
  Widget _tarjetaUsuario(UserModel usuario) {
    final eliminando = _uidEliminando == usuario.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.avatarSurface,
              child: Text(
                _iniciales(usuario),
                style: const TextStyle(
                  color: AppTheme.avatarText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    usuario.correo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.roleSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _nombreRol(usuario.rol),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Editar ${usuario.nombreCompleto}',
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              onPressed:
                  eliminando ? null : () => _abrirFormulario(usuario: usuario),
              icon: const Icon(Icons.edit_outlined),
              color: AppTheme.cfeGreen,
            ),
            IconButton(
              tooltip: 'Eliminar ${usuario.nombreCompleto}',
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              onPressed:
                  eliminando ? null : () => _confirmarEliminacion(usuario),
              icon: eliminando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              color: AppTheme.errorRed,
            ),
          ],
        ),
      ),
    );
  }

  // Construye el selector para filtrar usuarios por rol.
  // Entrada: ninguna; utiliza y actualiza el rol seleccionado.
  // Salida: un campo desplegable con las opciones de rol.
  Widget _filtroRol() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DropdownButtonFormField<String>(
        initialValue: _rolFiltro,
        decoration: const InputDecoration(
          labelText: 'Filtrar por rol',
          prefixIcon: Icon(Icons.filter_list),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'todos',
            child: Text('Todos los roles'),
          ),
          DropdownMenuItem(
            value: 'administrador',
            child: Text('Administrador'),
          ),
          DropdownMenuItem(
            value: 'operador',
            child: Text('Operador'),
          ),
          DropdownMenuItem(
            value: 'superusuario',
            child: Text('Superusuario'),
          ),
        ],
        onChanged: (valor) {
          if (valor != null) {
            setState(() => _rolFiltro = valor);
          }
        },
      ),
    );
  }

  // Construye la pantalla con búsqueda, filtro y lista de usuarios.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets de la pantalla de usuarios.
  @override
  Widget build(BuildContext context) {
    final String? rol = _rolFiltro == 'todos' ? null : _rolFiltro;

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Usuarios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: AppTheme.accentText,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo usuario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: TextField(
                    controller: _busquedaController,
                    textInputAction: TextInputAction.search,
                    onChanged: (valor) {
                      setState(() => _busqueda = valor);
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o correo',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busqueda.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: () {
                                _busquedaController.clear();
                                setState(() => _busqueda = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: AppTheme.pureWhite,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: AppTheme.cfeGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                _filtroRol(),
                Expanded(
                  child: StreamBuilder<List<UserModel>>(
                    stream: _viewModel.obtenerUsuarios(
                      busqueda: _busqueda,
                      rol: rol,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorRed,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No se pudieron cargar los usuarios.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.cfeGreen,
                          ),
                        );
                      }

                      final usuarios = snapshot.data ?? [];

                      if (usuarios.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: AppTheme.secondaryText,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _busqueda.isEmpty && _rolFiltro == 'todos'
                                      ? 'Todavía no hay usuarios registrados.'
                                      : 'No se encontraron usuarios con esos criterios.',
                                  textAlign: TextAlign.center,
                                ),
                                if (_busqueda.isEmpty &&
                                    _rolFiltro == 'todos') ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => _abrirFormulario(),
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text('Registrar usuario'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: usuarios.length,
                        itemBuilder: (context, index) {
                          return _tarjetaUsuario(usuarios[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}