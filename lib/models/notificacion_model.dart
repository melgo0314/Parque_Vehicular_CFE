
class NotificacionModel {
  final String uid;
  final String vehiculoUid;
  final String placas;
  final String numeroEconomico;
  final String mantenimientoUid;

  // Tipo de alerta:
  // preventivo_proximo
  // preventivo_vencido
  // correctivo_pendiente
  final String tipoAlerta;

  final String titulo;
  final String descripcion;

  final DateTime? fechaProgramada;
  final int? kilometrajeProgramado;
  final int kilometrajeActual;

  final int? diasRestantes;
  final int? kilometrosRestantes;

  // Indica si la notificación ya fue leída.
  final bool leida;

  const NotificacionModel({
    required this.uid,
    required this.vehiculoUid,
    required this.placas,
    required this.numeroEconomico,
    required this.mantenimientoUid,
    required this.tipoAlerta,
    required this.titulo,
    required this.descripcion,
    this.fechaProgramada,
    this.kilometrajeProgramado,
    required this.kilometrajeActual,
    this.diasRestantes,
    this.kilometrosRestantes,
    this.leida = false,
  });

  // Identifica el tipo de alerta.
  bool get esPreventivoProximo =>
      tipoAlerta == 'preventivo_proximo';

  bool get esPreventivoVencido =>
      tipoAlerta == 'preventivo_vencido';

  bool get esCorrectivoPendiente =>
      tipoAlerta == 'correctivo_pendiente';
}
