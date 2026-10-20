import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class SessionTimeoutListener extends StatefulWidget {
  final Widget child;

  const SessionTimeoutListener({
    super.key,
    required this.child,
  });

  @override
  State<SessionTimeoutListener> createState() =>
      _SessionTimeoutListenerState();
}

class _SessionTimeoutListenerState extends State<SessionTimeoutListener>
    with WidgetsBindingObserver {
  static const Duration _tiempoInactividad = Duration(minutes: 5);

  Timer? _timer;
  StreamSubscription<User?>? _suscripcionAuth;
  DateTime? _ultimaActividad;
  bool _cerrandoSesion = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _suscripcionAuth = FirebaseAuth.instance.authStateChanges().listen(
      (usuario) {
        if (usuario == null) {
          _cancelarTemporizador();
          _ultimaActividad = null;
          return;
        }

        // El conteo empieza cuando Firebase confirma la autenticación.
        _registrarActividad();
      },
      onError: (Object error) {
        debugPrint('Error al escuchar el estado de autenticación: $error');
      },
    );
  }

  void _registrarActividad() {
    if (FirebaseAuth.instance.currentUser == null || _cerrandoSesion) {
      return;
    }

    _ultimaActividad = DateTime.now();
    _programarCierre(_tiempoInactividad);
  }

  void _programarCierre(Duration tiempoRestante) {
    _timer?.cancel();

    if (FirebaseAuth.instance.currentUser == null || _cerrandoSesion) {
      return;
    }

    _timer = Timer(tiempoRestante, _comprobarTiempoInactivo);
  }

  void _cancelarTemporizador() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _comprobarTiempoInactivo() async {
    if (!mounted || _cerrandoSesion) return;

    if (FirebaseAuth.instance.currentUser == null) {
      _cancelarTemporizador();
      return;
    }

    final ultimaActividad = _ultimaActividad;

    if (ultimaActividad == null) {
      _registrarActividad();
      return;
    }

    final transcurrido = DateTime.now().difference(ultimaActividad);

    if (transcurrido < _tiempoInactividad) {
      _programarCierre(_tiempoInactividad - transcurrido);
      return;
    }

    debugPrint('Tiempo de inactividad vencido. Cerrando sesión.');
    await _cerrarSesionPorInactividad();
  }

  Future<void> _cerrarSesionPorInactividad() async {
    if (!mounted ||
        _cerrandoSesion ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }

    _cerrandoSesion = true;
    _cancelarTemporizador();

    try {
      await FirebaseAuth.instance.signOut();

      final navigator = AppRoutes.navigatorKey.currentState;
      if (navigator == null) {
        throw StateError('No está disponible el navegador de la aplicación.');
      }

      navigator.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRoutes.messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Sesión cerrada automáticamente por '
              '${_textoTiempoInactividad()}.',
            ),
          ),
        );
      });
    } catch (error) {
      debugPrint('Error al cerrar la sesión por inactividad: $error');

      // Si Firebase todavía mantiene la sesión, se vuelve a intentar después.
      if (FirebaseAuth.instance.currentUser != null) {
        _ultimaActividad = DateTime.now();
        _programarCierre(_tiempoInactividad);
      }
    } finally {
      _cerrandoSesion = false;
    }
  }

  String _textoTiempoInactividad() {
    final minutos = _tiempoInactividad.inMinutes;

    if (minutos == 1) {
      return '1 minuto de inactividad';
    }

    return '$minutos minutos de inactividad';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Comprueba el tiempo transcurrido mientras la app estuvo en segundo plano.
      _comprobarTiempoInactivo();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Conserva la última actividad; se verifica al volver a la app.
      _cancelarTemporizador();
    }
  }

  @override
  void dispose() {
    _cancelarTemporizador();
    _suscripcionAuth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registrarActividad(),
      child: widget.child,
    );
  }
}