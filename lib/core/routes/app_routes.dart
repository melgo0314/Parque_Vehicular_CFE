import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/view/admin_home_view.dart';
import 'package:p_vehicular/view/asignaciones_view.dart';
import 'package:p_vehicular/view/combustible_view.dart';
import 'package:p_vehicular/view/inventario_view.dart';
import 'package:p_vehicular/view/kilometraje_view.dart';
import 'package:p_vehicular/view/login_view.dart';
import 'package:p_vehicular/view/mantenimiento_view.dart';
import 'package:p_vehicular/view/ope_home_view.dart';
import 'package:p_vehicular/view/super_home_view.dart';
import 'package:p_vehicular/view/usuarios_view.dart';
import 'package:p_vehicular/view/vehiculos_view.dart';

// Centraliza los nombres y la configuración de las rutas de la aplicación.
class AppRoutes {
  // Llave global para controlar la navegación de la aplicación.
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Llave global para mostrar mensajes desde cualquier pantalla.
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Nombres de las rutas disponibles en la aplicación.
  static const String login = '/login';
  static const String adminHome = '/admin_home';
  static const String operatorHome = '/ope_home';
  static const String superHome = '/super_home';
  static const String usuarios = '/usuarios';
  static const String vehiculos = '/vehiculos';
  static const String asignaciones = '/asignaciones';
  static const String combustible = '/combustible';
  static const String kilometraje = '/kilometraje';
  static const String mantenimiento = '/mantenimiento';
  static const String inventario = '/inventario';
  static const String expediente = '/expediente';
  static const String reporte = '/reporte';
  static const String bd = '/bd';

  // Genera la ruta solicitada y aplica protección según el rol cuando corresponde.
  // Entrada: settings contiene el nombre y los argumentos de la ruta solicitada.
  // Salida: una ruta configurada para la pantalla solicitada o una pantalla de error.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const LoginView(),
        );

      case adminHome:
        return _rutaProtegida(
          settings: settings,
          vista: const AdminHomeView(),
          rolesPermitidos: const ['administrador'],
        );

      case operatorHome:
        return _rutaProtegida(
          settings: settings,
          vista: const OpeHomeView(),
          rolesPermitidos: const ['operador'],
        );

      case superHome:
        return _rutaProtegida(
          settings: settings,
          vista: const SuperHomeView(),
          rolesPermitidos: const ['superusuario'],
        );

      case usuarios:
        return _rutaProtegida(
          settings: settings,
          vista: const UsuariosView(),
          rolesPermitidos: const ['administrador', 'superusuario'],
        );

      case vehiculos:
        return _rutaProtegida(
          settings: settings,
          vista: const VehiculosView(),
          rolesPermitidos: const [
            'administrador',
            'operador',
          ],
        );

      case asignaciones:
        return _rutaProtegida(
          settings: settings,
          vista: const AsignacionesView(),
          rolesPermitidos: const ['administrador'],
        );

      case combustible:
        return _rutaProtegida(
          settings: settings,
          vista: const CombustibleView(vehiculos: []),
          rolesPermitidos: const [
            'administrador',
            'operador',
          ],
        );

      case kilometraje:
        return _rutaProtegida(
          settings: settings,
          vista: const KilometrajeView(vehiculos: []),
          rolesPermitidos: const [
            'administrador',
            'operador',
          ],
        );

      case mantenimiento:
        return _rutaProtegida(
          settings: settings,
          vista: const MantenimientoView(vehiculos: []),
          rolesPermitidos: const [
            'administrador',
            'operador',
          ],
        );
      
      case inventario:
        return _rutaProtegida(
          settings: settings,
          vista: const InventarioView(vehiculos: [],),
          rolesPermitidos: const [
            'administrador',
            'operador',
          ],
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('No se encontró esta pantalla.'),
            ),
          ),
        );
    }
  }

  // Crea una ruta que comprueba los permisos antes de mostrar una pantalla.
  // Entradas: settings de la ruta, vista que se quiere mostrar y rolesPermitidos.
  // Salida: una ruta que muestra la vista solo si el usuario tiene autorización.
  static Route<dynamic> _rutaProtegida({
    required RouteSettings settings,
    required Widget vista,
    required List<String> rolesPermitidos,
  }) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        return _ProteccionRuta(
          vista: vista,
          rolesPermitidos: rolesPermitidos,
        );
      },
    );
  }
}

// Widget que verifica si el rol actual puede acceder a una vista.
class _ProteccionRuta extends StatefulWidget {
  // Pantalla que se mostrará cuando el acceso esté autorizado.
  final Widget vista;

  // Lista de roles que tienen permiso para abrir la pantalla.
  final List<String> rolesPermitidos;

  // Crea el control de acceso para la vista indicada.
  // Entradas: vista que se protegerá y rolesPermitidos que pueden acceder.
  // Salida: una instancia de _ProteccionRuta.
  const _ProteccionRuta({
    required this.vista,
    required this.rolesPermitidos,
  });

  // Crea el estado que consulta y valida el rol del usuario.
  // Entrada: ninguna.
  // Salida: el estado asociado a este widget.
  @override
  State<_ProteccionRuta> createState() => _ProteccionRutaState();
}

// Estado que obtiene el rol y decide qué pantalla mostrar.
class _ProteccionRutaState extends State<_ProteccionRuta> {
  // Consulta asíncrona del rol del usuario autenticado.
  late Future<String?> _consultaRol;

  // Inicia la consulta del rol cuando se crea el estado.
  // Entrada: ninguna.
  // Salida: ninguna; guarda el Future que devolverá el rol del usuario.
  @override
  void initState() {
    super.initState();
    _consultaRol = _obtenerRol();
  }

  // Consulta en Firestore el rol del usuario autenticado.
  // Entrada: ninguna; utiliza el usuario actual de Firebase Authentication.
  // Salida: el rol normalizado del usuario o null si no hay usuario o perfil.
  Future<String?> _obtenerRol() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return null;
    }

    final documento = await FirebaseFirestore.instance
        .collection('usuario')
        .doc(usuario.uid)
        .get();

    if (!documento.exists) {
      return null;
    }

    final datos = documento.data();
    return datos?['rol']?.toString().trim().toLowerCase();
  }

  // Construye la pantalla según el resultado de la consulta y los permisos.
  // Entrada: context, contexto actual del widget.
  // Salida: indicador de carga, pantalla de acceso restringido o vista solicitada.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _consultaRol,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _vistaBloqueada(
            'No se pudieron verificar tus permisos. '
            'Revisa tu conexión e inténtalo nuevamente.',
            AppRoutes.login,
          );
        }

        final rol = snapshot.data;

        if (rol == null || rol.isEmpty) {
          return _vistaBloqueada(
            'Inicia sesión con una cuenta válida para continuar.',
            AppRoutes.login,
          );
        }

        if (!widget.rolesPermitidos.contains(rol)) {
          final String rutaInicio;

          if (rol == 'operador') {
            rutaInicio = AppRoutes.operatorHome;
          } else if (rol == 'superusuario') {
            rutaInicio = AppRoutes.superHome;
          } else {
            rutaInicio = AppRoutes.adminHome;
          }

          return _vistaBloqueada(
            'Tu cuenta no tiene permiso para abrir esta pantalla.',
            rutaInicio,
          );
        }

        return widget.vista;
      },
    );
  }

  // Construye una pantalla que informa que el usuario no tiene acceso.
  // Entradas: mensaje que explica la restricción y rutaInicio a la que regresará.
  // Salida: una pantalla con el aviso y un botón para volver a la página de inicio.
  Widget _vistaBloqueada(String mensaje, String rutaInicio) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso restringido'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                mensaje,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    rutaInicio,
                    (route) => false,
                  );
                },
                child: const Text('Regresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}