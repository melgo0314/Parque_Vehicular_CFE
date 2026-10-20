import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/asignacion_model.dart';
import '../viewmodel/asignacion_viewmodel.dart';
import 'form_asignacion_view.dart';

class AsignacionesView extends StatefulWidget {
  const AsignacionesView({super.key});

  @override
  State<AsignacionesView> createState() => _AsignacionesViewState();
}

class _AsignacionesViewState extends State<AsignacionesView> {
  final AsignacionViewModel _viewModel = AsignacionViewModel();

  late Stream<List<AsignacionModel>> _asignacionesStream;
  String? _uidFinalizando;

  @override
  void initState() {
    super.initState();
    _crearStream();
  }

  void _crearStream() {
    _asignacionesStream = _viewModel.obtenerAsignaciones();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  String _mesAbreviado(int mes) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    return meses[mes - 1];
  }

  String _fechaCompleta(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    return '$dia ${_mesAbreviado(fecha.month)} ${fecha.year}';
  }

  String _textoFechas(AsignacionModel asignacion) {
    if (asignacion.estado == 'finalizada') {
      final fechaFin = asignacion.fechaFin;
      if (fechaFin == null) {
        return 'Desde ${_fechaCompleta(asignacion.fechaInicio)} · Finalizada';
      }

      return '${_fechaCompleta(asignacion.fechaInicio)} – '
          '${_fechaCompleta(fechaFin)}';
    }

    if (asignacion.esTemporal) {
      final fechaFin = asignacion.fechaFin;
      final motivo = asignacion.motivoTemporal.trim();

      if (fechaFin == null) {
        return 'Desde ${_fechaCompleta(asignacion.fechaInicio)}'
            '${motivo.isEmpty ? '' : ' · $motivo'}';
      }

      String intervalo;
      if (asignacion.fechaInicio.month == fechaFin.month &&
          asignacion.fechaInicio.year == fechaFin.year) {
        intervalo =
            '${asignacion.fechaInicio.day.toString().padLeft(2, '0')}–'
            '${fechaFin.day.toString().padLeft(2, '0')} '
            '${_mesAbreviado(fechaFin.month)} ${fechaFin.year}';
      } else {
        intervalo = '${_fechaCompleta(asignacion.fechaInicio)} – '
            '${_fechaCompleta(fechaFin)}';
      }

      return motivo.isEmpty ? intervalo : '$intervalo · $motivo';
    }

    return 'Desde ${_fechaCompleta(asignacion.fechaInicio)}';
  }

  String _etiquetaEstado(AsignacionModel asignacion) {
    if (asignacion.estado == 'finalizada') return 'Finalizada';
    if (asignacion.esTemporal) return 'Temporal';
    return 'Vigente';
  }

  Color _colorFondoEstado(AsignacionModel asignacion) {
    if (asignacion.estado == 'finalizada') {
      return AppTheme.roleSurface;
    }
    if (asignacion.esTemporal) {
      return AppTheme.infoSurface;
    }
    return AppTheme.operationalSurface;
  }

  Color _colorTextoEstado(AsignacionModel asignacion) {
    if (asignacion.estado == 'finalizada') {
      return AppTheme.primaryText;
    }
    if (asignacion.esTemporal) {
      return AppTheme.infoBlue;
    }
    return AppTheme.operationalText;
  }

  IconData _iconoEstado(AsignacionModel asignacion) {
    if (asignacion.estado == 'finalizada') {
      return Icons.check_circle_outline;
    }
    if (asignacion.esTemporal) {
      return Icons.swap_horiz;
    }
    return Icons.check;
  }

  Future<void> _abrirFormulario({AsignacionModel? asignacion}) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormAsignacionView(asignacion: asignacion),
      ),
    );

    if (resultado == true && mounted) {
      _mostrarMensaje(
        asignacion == null
            ? 'La asignación se creó correctamente.'
            : 'La asignación se actualizó correctamente.',
        error: false,
      );
    }
  }

  Future<void> _confirmarFinalizacion(AsignacionModel asignacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.assignment_return_outlined,
            color: AppTheme.alertOrange,
            size: 32,
          ),
          title: const Text('¿Finalizar asignación?'),
          content: Text(
            'La asignación de ${asignacion.operadorNombre} '
            'con el vehículo ${asignacion.vehiculoPlacas} '
            'pasará al historial como finalizada.',
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
                backgroundColor: AppTheme.cfeGreen,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() => _uidFinalizando = asignacion.uid);

    final finalizada =
        await _viewModel.finalizarAsignacion(asignacion.uid);

    if (!mounted) return;
    setState(() => _uidFinalizando = null);

    _mostrarMensaje(
      finalizada
          ? (_viewModel.mensajeExito ??
              'La asignación se finalizó correctamente.')
          : (_viewModel.mensajeError ??
              'No se pudo finalizar la asignación.'),
      error: !finalizada,
    );
  }

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

  Widget _distintivoEstado(AsignacionModel asignacion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _colorFondoEstado(asignacion),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconoEstado(asignacion),
            size: 15,
            color: _colorTextoEstado(asignacion),
          ),
          const SizedBox(width: 4),
          Text(
            _etiquetaEstado(asignacion),
            style: TextStyle(
              color: _colorTextoEstado(asignacion),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAsignacion(AsignacionModel asignacion) {
    final finalizando = _uidFinalizando == asignacion.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: asignacion.estaActiva
            ? () => _abrirFormulario(asignacion: asignacion)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.avatarSurface,
                child: Text(
                  _iniciales(asignacion.operadorNombre),
                  style: const TextStyle(
                    color: AppTheme.avatarText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asignacion.operadorNombre.isEmpty
                          ? 'Operador sin nombre'
                          : asignacion.operadorNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${asignacion.vehiculoTipo} · '
                      '${asignacion.vehiculoPlacas}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _textoFechas(asignacion),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _distintivoEstado(asignacion),
                  if (asignacion.estaActiva) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: finalizando
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.cfeGreen,
                              ),
                            )
                          : PopupMenuButton<String>(
                              tooltip: 'Acciones de asignación',
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppTheme.secondaryText,
                              ),
                              onSelected: (accion) {
                                if (accion == 'editar') {
                                  _abrirFormulario(asignacion: asignacion);
                                } else if (accion == 'finalizar') {
                                  _confirmarFinalizacion(asignacion);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'editar',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar'),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'finalizar',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.assignment_return_outlined,
                                    ),
                                    title: Text('Finalizar'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 52,
              color: AppTheme.secondaryText,
            ),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay asignaciones registradas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usa “Nueva asignación” para asignar un vehículo a un operador.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Asignaciones',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: AppTheme.accentText,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva asignación',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: StreamBuilder<List<AsignacionModel>>(
              stream: _asignacionesStream,
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
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No se pudieron cargar las asignaciones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.primaryText),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () {
                              setState(_crearStream);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cfeGreen,
                    ),
                  );
                }

                final asignaciones = snapshot.data ?? [];

                if (asignaciones.isEmpty) {
                  return _estadoVacio();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: asignaciones.length,
                  itemBuilder: (context, index) {
                    return _tarjetaAsignacion(asignaciones[index]);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}