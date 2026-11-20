
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notificacion_model.dart';
import '../viewmodel/notificacion_viewmodel.dart';

// Pantalla que muestra las notificaciones del parque vehicular.
class NotificacionView extends StatelessWidget {
  const NotificacionView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificacionViewmodel()
        ..obtenerNotificaciones(),
      child: const _NotificacionContenido(),
    );
  }
}

class _NotificacionContenido extends StatelessWidget {
  const _NotificacionContenido();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFF008A45),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Consumer<NotificacionViewmodel>(
            builder: (context, viewmodel, _) {
              return TextButton(
                onPressed: viewmodel.totalNoLeidas == 0
                    ? null
                    : () async {
                        await viewmodel.marcarTodasComoLeidas();
                      },
                child: const Text(
                  'Marcar todas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificacionViewmodel>(
        builder: (context, viewmodel, _) {
          if (viewmodel.cargando) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF008A45),
              ),
            );
          }

          if (viewmodel.error != null) {
            return _construirError(context, viewmodel);
          }

          if (viewmodel.notificaciones.isEmpty) {
            return _construirVacio(context, viewmodel);
          }

          return RefreshIndicator(
            color: const Color(0xFF008A45),
            onRefresh: viewmodel.actualizarNotificaciones,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _construirResumen(viewmodel),
                const SizedBox(height: 20),

                const Text(
                  'Alertas registradas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ...viewmodel.notificaciones.map((notificacion) {
                  return _construirTarjeta(
                    notificacion,
                    viewmodel,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // Muestra el resumen de las notificaciones.
  Widget _construirResumen(NotificacionViewmodel viewmodel) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de alertas',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _construirIndicador(
                  'Vencidas',
                  viewmodel.totalVencidas,
                  Colors.red,
                ),
                _construirIndicador(
                  'Próximas',
                  viewmodel.totalProximas,
                  Colors.orange,
                ),
                _construirIndicador(
                  'Correctivas',
                  viewmodel.totalCorrectivas,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Construye cada indicador del resumen.
  Widget _construirIndicador(
    String titulo,
    int cantidad,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            cantidad.toString(),
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Construye la tarjeta de una notificación.
  Widget _construirTarjeta(
    NotificacionModel notificacion,
    NotificacionViewmodel viewmodel,
  ) {
    final color = _obtenerColor(notificacion.tipoAlerta);
    final icono = _obtenerIcono(notificacion.tipoAlerta);

    // Diferencia visualmente las notificaciones no leídas.
    final colorFondo = notificacion.leida
        ? Colors.white
        : const Color(0xFFE8F5EC);

    return Card(
      color: colorFondo,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),

        // Al tocar una notificación, se marca como leída.
        onTap: () {
          if (!notificacion.leida) {
            viewmodel.marcarComoLeida(notificacion.uid);
          }
        },

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notificacion.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: notificacion.leida
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!notificacion.leida)
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF008A45),
                      size: 10,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                notificacion.descripcion,
                style: const TextStyle(fontSize: 14),
              ),

              const Divider(height: 24),

              Text(
                'Vehículo: ${notificacion.placas}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Número económico: ${notificacion.numeroEconomico}',
                style: const TextStyle(fontSize: 13),
              ),

              const SizedBox(height: 5),

              Text(
                'Kilometraje actual: '
                '${notificacion.kilometrajeActual} km',
                style: const TextStyle(fontSize: 13),
              ),

              if (notificacion.fechaProgramada != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Fecha programada: '
                  '${_formatearFecha(notificacion.fechaProgramada!)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],

              if (notificacion.kilometrajeProgramado != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Kilometraje programado: '
                  '${notificacion.kilometrajeProgramado} km',
                  style: const TextStyle(fontSize: 13),
                ),
              ],

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _obtenerEtiqueta(notificacion.tipoAlerta),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Muestra un mensaje cuando no existen notificaciones.
  Widget _construirVacio(
    BuildContext context,
    NotificacionViewmodel viewmodel,
  ) {
    return RefreshIndicator(
      color: const Color(0xFF008A45),
      onRefresh: viewmodel.actualizarNotificaciones,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 150),
          Icon(
            Icons.notifications_none,
            size: 75,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No hay notificaciones pendientes.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Muestra el error de consulta.
  Widget _construirError(
    BuildContext context,
    NotificacionViewmodel viewmodel,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 55,
            ),
            const SizedBox(height: 12),
            Text(
              viewmodel.error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: viewmodel.obtenerNotificaciones,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // Determina el color de cada tipo de alerta.
  Color _obtenerColor(String tipo) {
    if (tipo == 'preventivo_vencido') {
      return Colors.red;
    }

    if (tipo == 'preventivo_proximo') {
      return Colors.orange;
    }

    return Colors.blue;
  }

  // Determina el icono de cada tipo de alerta.
  IconData _obtenerIcono(String tipo) {
    if (tipo == 'preventivo_vencido') {
      return Icons.warning_amber_rounded;
    }

    if (tipo == 'preventivo_proximo') {
      return Icons.event_available;
    }

    return Icons.build_circle_outlined;
  }

  // Determina la etiqueta que aparecerá en la tarjeta.
  String _obtenerEtiqueta(String tipo) {
    if (tipo == 'preventivo_vencido') {
      return 'VENCIDO';
    }

    if (tipo == 'preventivo_proximo') {
      return 'PRÓXIMO';
    }

    return 'PENDIENTE';
  }

  // Convierte la fecha a formato día/mes/año.
  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }
}
