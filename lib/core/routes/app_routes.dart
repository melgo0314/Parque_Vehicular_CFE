import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/view/admin_home_view.dart';
import 'package:p_vehicular/view/asignaciones_view.dart';
import 'package:p_vehicular/view/combustible_view.dart';
import 'package:p_vehicular/view/inventario_view.dart';
import 'package:p_vehicular/view/kilometraje_view.dart';
import 'package:p_vehicular/view/login_view.dart';
import 'package:p_vehicular/view/mantenimiento_view.dart';
import 'package:p_vehicular/view/notificacion_view.dart';
import 'package:p_vehicular/view/ope_home_view.dart';
import 'package:p_vehicular/view/reportes_view.dart';
import 'package:p_vehicular/view/respaldo_view.dart';
import 'package:p_vehicular/view/super_home_view.dart';
import 'package:p_vehicular/view/usuarios_view.dart';
import 'package:p_vehicular/view/vehiculos_view.dart';
import 'package:p_vehicular/view/expediente_view.dart';
import 'package:p_vehicular/viewmodel/respaldo_viewmodel.dart';
import 'package:provider/provider.dart';


class AppRoutes {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

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
  static const String notificaciones = '/notificaciones';

  static List<VehiculoModel> _vehiculosDeRuta(RouteSettings settings) {
    final argumentos = settings.arguments;

    if (argumentos is List<VehiculoModel>) {
      return argumentos;
    }

    if (argumentos is VehiculoModel) {
      return [argumentos];
    }

    return <VehiculoModel>[];

  }

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
          vista: const SizedBox.shrink(),
          vistaPorRol: (rol) {
            if (rol == 'operador') {
              return VehiculosView(
                vehiculosAsignados: _vehiculosDeRuta(settings),
              );
            }

            return const VehiculosView();
          },
          rolesPermitidos: const [
            'administrador',
            'operador',
            'superusuario',
          ],
        );

      case asignaciones:
        return _rutaProtegida(
          settings: settings,
          vista: const AsignacionesView(),
          rolesPermitidos: const ['administrador', 'superusuario'],
        );

      case combustible:
        return _rutaProtegida(
          settings: settings,
          vista: CombustibleView(
            vehiculos: _vehiculosDeRuta(settings),
          ),
          rolesPermitidos: const [
            'administrador',
            'operador',
            'superusuario',
          ],
        );

      case kilometraje:
        return _rutaProtegida(
          settings: settings,
          vista: KilometrajeView(
            vehiculos: _vehiculosDeRuta(settings),
          ),
          rolesPermitidos: const [
            'administrador',
            'operador',
            'superusuario',
          ],
        );

      case mantenimiento:
        return _rutaProtegida(
          settings: settings,
          vista: MantenimientoView(
            vehiculos: _vehiculosDeRuta(settings),
          ),
          rolesPermitidos: const [
            'administrador',
            'operador',
            'superusuario',
          ],
        );

      case inventario:
        return _rutaProtegida(
          settings: settings,
          vista: const InventarioView(vehiculos: [],),
          rolesPermitidos: const [
            'administrador',
            'operador',
            'superusuario',
          ],
        );
        case expediente:
          return _rutaProtegida(
            settings: settings,
            vista: const ExpedienteView(vehiculos: [],),
            rolesPermitidos: const [
              'administrador',
              'operador',
            ],
        );
        case reporte:
          return _rutaProtegida(
            settings: settings,
            vista: const ReportesView(vehiculos: [],),
            rolesPermitidos: const [
              'administrador',
              'operador',
            ],
          );
        case bd:
          return _rutaProtegida(
            settings: settings,
            vista: ChangeNotifierProvider(
              create: (_) => RespaldoViewmodel()
                ..obtenerRespaldos(),
              child: const RespaldoView(),
            ),
            rolesPermitidos: const ['administrador'],
         );   
         
        case notificaciones:
          return _rutaProtegida(
            settings: settings,
            vista: const NotificacionView(),
            rolesPermitidos: const [
              'administrador',
              'operador',
              'superusuario',
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

  static Route<dynamic> _rutaProtegida({
    required RouteSettings settings,
    required Widget vista,
    Widget Function(String rol)? vistaPorRol,
    required List<String> rolesPermitidos,
  }) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        return _ProteccionRuta(
          vista: vista,
          vistaPorRol: vistaPorRol,
          rolesPermitidos: rolesPermitidos,
        );
      },
    );
  }
}

class _ProteccionRuta extends StatefulWidget {
  final Widget vista;
  final Widget Function(String rol)? vistaPorRol;
  final List<String> rolesPermitidos;

  const _ProteccionRuta({
    required this.vista,
    this.vistaPorRol,
    required this.rolesPermitidos,
  });

  @override
  State<_ProteccionRuta> createState() => _ProteccionRutaState();
}

class _ProteccionRutaState extends State<_ProteccionRuta> {
  late Future<String?> _consultaRol;

  @override
  void initState() {
    super.initState();
    _consultaRol = _obtenerRol();
  }

  Future<String?> _obtenerRol() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return null;

    final documento = await FirebaseFirestore.instance
        .collection('usuario')
        .doc(usuario.uid)
        .get();

    if (!documento.exists) return null;

    final datos = documento.data();
    return datos?['rol']?.toString().trim().toLowerCase();
  }

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
          final rutaInicio = rol == 'operador'
              ? AppRoutes.operatorHome
              : rol == 'superusuario'
                  ? AppRoutes.superHome
                  : AppRoutes.adminHome;

          return _vistaBloqueada(
            'Tu cuenta no tiene permiso para abrir esta pantalla.',
            rutaInicio,
          );
        }

        return widget.vistaPorRol?.call(rol) ?? widget.vista;
      },
    );
  }

  Widget _vistaBloqueada(String mensaje, String rutaInicio) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso restringido'),
        backgroundColor: Colors.green,
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