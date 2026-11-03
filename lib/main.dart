import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/utils/session_listener.dart'; 

// Inicio de la aplicación
void main() async {
  //Inicializa la aplicación antes de conectar con los servicios externos
  WidgetsFlutterBinding.ensureInitialized();
  // Conecta la aplicación con la base de datos de Firebase con la configuración automática
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Muestra la pantalla principal de la aplicación
  runApp(const MyApp());
}

// Configuracion general de la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

 // Control global para mostrar información
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Control global para navegar por las pantallas
      navigatorKey: AppRoutes.navigatorKey,
      // Control global para mostrar mensajes en la aplicación
      scaffoldMessengerKey: AppRoutes.messengerKey,
      title: 'Parque Vehicular',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Define la primera pantalla que ve el usuario
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        // Envuelve la aplicación en un protector que cierra la sesión si pasan 5 min. de inactividad
        return SessionTimeoutListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
