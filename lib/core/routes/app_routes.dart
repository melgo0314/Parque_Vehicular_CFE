
import 'package:flutter/material.dart';
import 'package:p_vehicular/view/asignaciones_view.dart';

import 'package:p_vehicular/view/ope_home_view.dart';
import 'package:p_vehicular/view/login_view.dart';
import 'package:p_vehicular/view/admin_home_view.dart';
import 'package:p_vehicular/view/usuarios_view.dart';
import 'package:p_vehicular/view/vehiculos_view.dart';

class AppRoutes {
  static const String login = '/login';
  static const String adminHome = '/admin_home';
  static const String operatorHome = '/ope_home';
  static const String usuarios = '/usuarios';
  static const String vehiculos = '/vehiculos';
  static const String asignaciones = '/asignaciones';
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginView(),
        adminHome: (context) => const AdminHomeView(),
        operatorHome: (context) => const OpeHomeView(),
        usuarios: (context) => const UsuariosView(),
        vehiculos: (context) => const VehiculosView(),
        asignaciones: (context) => const AsignacionesView(),
      };
}
