import 'package:flutter/material.dart';
import '../models/notificacion_model.dart';
import '../repositories/notificacion_repositorie.dart';

// Administra la información y el estado de las notificaciones.
class NotificacionViewmodel extends ChangeNotifier {
  final NotificacionRepositorie _repositorio =
      NotificacionRepositorie();

  List<NotificacionModel> _notificaciones = [];

  bool _cargando = false;
  String? _error;

  // Lista de notificaciones.
  List<NotificacionModel> get notificaciones => _notificaciones;

  // Indica si se están consultando las notificaciones.
  bool get cargando => _cargando;

  // Mensaje de error.
  String? get error => _error;

  // Cantidad total de notificaciones.
  int get totalNotificaciones => _notificaciones.length;

  // Cantidad de notificaciones que todavía no se han leído.
  int get totalNoLeidas => _notificaciones.where((notificacion) {
      return !notificacion.leida;
  }).length;

  // Cantidad de mantenimientos preventivos vencidos.
  int get totalVencidas => _notificaciones.where((notificacion) {
        return notificacion.esPreventivoVencido;
      }).length;

  // Cantidad de mantenimientos próximos.
  int get totalProximas => _notificaciones.where((notificacion) {
        return notificacion.esPreventivoProximo;
      }).length;

  // Cantidad de mantenimientos correctivos pendientes.
  int get totalCorrectivas => _notificaciones.where((notificacion) {
        return notificacion.esCorrectivoPendiente;
      }).length;

  // Consulta las notificaciones desde Firebase.
  Future<void> obtenerNotificaciones() async {
    _cargando = true;
    _error = null;

    notifyListeners();

    try {
      _notificaciones =
          await _repositorio.obtenerNotificaciones();
    } catch (e) {
      _error = _mensajeAmigable(e);
      _notificaciones = [];
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Actualiza la lista de notificaciones.
  Future<void> actualizarNotificaciones() async {
    await obtenerNotificaciones();
  }


  // Marca una notificación como leída.
  Future<void> marcarComoLeida(String notificacionUid) async {
    try {
      await _repositorio.marcarComoLeida(notificacionUid);

      // Actualiza el estado local de la notificación.
      _notificaciones = _notificaciones.map((notificacion) {
        if (notificacion.uid == notificacionUid) {
          return NotificacionModel(
            uid: notificacion.uid,
            vehiculoUid: notificacion.vehiculoUid,
            placas: notificacion.placas,
            numeroEconomico: notificacion.numeroEconomico,
            mantenimientoUid: notificacion.mantenimientoUid,
            tipoAlerta: notificacion.tipoAlerta,
            titulo: notificacion.titulo,
            descripcion: notificacion.descripcion,
            fechaProgramada: notificacion.fechaProgramada,
            kilometrajeProgramado: notificacion.kilometrajeProgramado,
            kilometrajeActual: notificacion.kilometrajeActual,
            diasRestantes: notificacion.diasRestantes,
            kilometrosRestantes: notificacion.kilometrosRestantes,
            leida: true,
          );
        }

        return notificacion;
      }).toList();

      notifyListeners();
    } catch (e) {
      _error = _mensajeAmigable(e);
      notifyListeners();
    }
  }

  // Marca todas las notificaciones como leídas.
  Future<void> marcarTodasComoLeidas() async {
    try {
      await _repositorio.marcarTodasComoLeidas(_notificaciones);

      _notificaciones = _notificaciones.map((notificacion) {
        return NotificacionModel(
          uid: notificacion.uid,
          vehiculoUid: notificacion.vehiculoUid,
          placas: notificacion.placas,
          numeroEconomico: notificacion.numeroEconomico,
          mantenimientoUid: notificacion.mantenimientoUid,
          tipoAlerta: notificacion.tipoAlerta,
          titulo: notificacion.titulo,
          descripcion: notificacion.descripcion,
          fechaProgramada: notificacion.fechaProgramada,
          kilometrajeProgramado: notificacion.kilometrajeProgramado,
          kilometrajeActual: notificacion.kilometrajeActual,
          diasRestantes: notificacion.diasRestantes,
          kilometrosRestantes: notificacion.kilometrosRestantes,
          leida: true,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      _error = _mensajeAmigable(e);
      notifyListeners();
    }
  }

  // Convierte los errores en mensajes comprensibles.
  String _mensajeAmigable(dynamic error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return 'Ocurrió un error al consultar las notificaciones.';
  }

  // Limpia el mensaje de error.
  void limpiarMensajes() {
    _error = null;
    notifyListeners();
  }
}
