import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/respaldo_model.dart';
import '../viewmodel/respaldo_viewmodel.dart';

class RespaldoView extends StatefulWidget {
  const RespaldoView({super.key});

  @override
  State<RespaldoView> createState() => _RespaldoViewState();
}

class _RespaldoViewState extends State<RespaldoView> {
  String? _respaldoSeleccionado;
  String? _restaurandoIdentificador;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RespaldoViewmodel>().obtenerRespaldos();
    });
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
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

  Future<void> _generarRespaldo(RespaldoViewmodel viewmodel) async {
    final resultado = await viewmodel.generarRespaldo();

    if (!mounted) return;

    if (resultado) {
      _mostrarMensaje(
        'La solicitud de respaldo se inició correctamente. '
        'Aparecerá en el historial cuando termine.',
      );
    } else {
      _mostrarMensaje(
        viewmodel.error ?? 'No fue posible iniciar el respaldo.',
        error: true,
      );
    }
  }

  Future<void> _actualizarHistorial(RespaldoViewmodel viewmodel) async {
    await viewmodel.obtenerRespaldos();

    if (!mounted) return;

    if (viewmodel.error != null) {
      _mostrarMensaje(viewmodel.error!, error: true);
    } else {
      _mostrarMensaje('Historial de respaldos actualizado.');
    }
  }

  Future<void> _restaurarRespaldo(
    RespaldoViewmodel viewmodel,
    RespaldoModel respaldo,
  ) async {
    if (!respaldo.estaCompletado) {
      _mostrarMensaje(
        'Solo puedes restaurar respaldos completados.',
        error: true,
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar restauración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se restaurará la información del proyecto p-vehicular '
          'usando este respaldo:\n\n'
          '${respaldo.identificador}\n\n'
          'Los datos actuales podrían verse afectados. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.secondaryText),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: AppTheme.pureWhite,
              minimumSize: const Size(120, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _restaurandoIdentificador = respaldo.identificador;
    });

    final resultado = await viewmodel.restaurarRespaldo(respaldo.identificador);

    if (!mounted) return;

    setState(() {
      _restaurandoIdentificador = null;
    });

    if (resultado) {
      _mostrarMensaje(
        'La solicitud de restauración se inició correctamente. '
        'El proceso continúa en el servidor.',
      );
    } else {
      _mostrarMensaje(
        viewmodel.error ?? 'No fue posible iniciar la restauración.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const InicioFooter(),
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        title: const Text(
          'Respaldos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<RespaldoViewmodel>(
        builder: (context, viewmodel, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (viewmodel.error != null)
                          _construirMensajeError(viewmodel.error!),
                        _construirSeccionRespaldos(viewmodel),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _construirMensajeError(String mensaje) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: AppTheme.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionRespaldos(RespaldoViewmodel viewmodel) {
    return _construirTarjeta(
      icono: Icons.cloud_upload_outlined,
      titulo: 'Respaldos',
      descripcion:
          'Genera copias de seguridad y consulta el historial. '
          'Para restaurar, selecciona un respaldo completado.',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirBotonPrincipal(
            texto: viewmodel.generandoRespaldo
                ? 'Iniciando respaldo...'
                : 'Generar respaldo',
            icono: Icons.add_circle_outline,
            onPressed: viewmodel.generandoRespaldo
                ? null
                : () => _generarRespaldo(viewmodel),
            cargando: viewmodel.generandoRespaldo,
          ),
          const SizedBox(height: 24),
          Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historial de respaldos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar historial',
                onPressed: viewmodel.cargando
                    ? null
                    : () => _actualizarHistorial(viewmodel),
                icon: Icon(Icons.refresh, color: AppTheme.cfeGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (viewmodel.cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (viewmodel.respaldos.isEmpty)
            _construirEstadoVacio(
              icono: Icons.folder_open_outlined,
              mensaje: 'No hay respaldos para mostrar.',
              descripcion:
                  'Los respaldos generados aparecerán en esta sección.',
            )
          else
            _construirListaRespaldos(viewmodel),
        ],
      ),
    );
  }

  Widget _construirListaRespaldos(RespaldoViewmodel viewmodel) {
    return Column(
      children: viewmodel.respaldos.map((respaldo) {
        final seleccionado = _respaldoSeleccionado == respaldo.identificador;

        return _construirTarjetaRespaldo(
          respaldo: respaldo,
          seleccionado: seleccionado,
          viewmodel: viewmodel,
        );
      }).toList(),
    );
  }

  Widget _construirTarjetaRespaldo({
    required RespaldoModel respaldo,
    required bool seleccionado,
    required RespaldoViewmodel viewmodel,
  }) {
    final estaCompletado = respaldo.estaCompletado;
    final estaRestaurando = _restaurandoIdentificador == respaldo.identificador;
    final hayRestauracionEnCurso = _restaurandoIdentificador != null;

    return InkWell(
      onTap: () {
        setState(() {
          _respaldoSeleccionado = seleccionado ? null : respaldo.identificador;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppTheme.cfeGreen.withValues(alpha: 0.07)
              : AppTheme.pearlWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? AppTheme.cfeGreen : AppTheme.border,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined, color: AppTheme.cfeGreen, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    respaldo.tipo.isEmpty
                        ? 'Respaldo'
                        : 'Respaldo ${respaldo.tipo}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: estaCompletado
                        ? AppTheme.cfeGreen.withValues(alpha: 0.10)
                        : AppTheme.alertOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    respaldo.estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estaCompletado
                          ? AppTheme.cfeGreen
                          : AppTheme.alertOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Identificador:',
              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 3),
            SelectableText(
              respaldo.identificador,
              style: TextStyle(fontSize: 12, color: AppTheme.primaryText),
            ),
            const SizedBox(height: 10),
            _construirDatoRespaldo(
              Icons.calendar_today_outlined,
              'Fecha: ${respaldo.fechaFormateada}',
            ),
            const SizedBox(height: 6),
            _construirDatoRespaldo(
              Icons.people_outline,
              'Usuarios: ${respaldo.cantidadUsuarios}',
            ),
            const SizedBox(height: 6),
            _construirDatoRespaldo(
              Icons.folder_outlined,
              'Archivos Storage: ${respaldo.cantidadArchivosStorage}',
            ),
            if (respaldo.error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Error: ${respaldo.error}',
                style: TextStyle(fontSize: 12, color: AppTheme.errorRed),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    seleccionado
                        ? 'Respaldo seleccionado'
                        : 'Seleccionar respaldo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: seleccionado
                          ? AppTheme.cfeGreen
                          : AppTheme.secondaryText,
                    ),
                  ),
                ),
                Icon(
                  seleccionado
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: seleccionado
                      ? AppTheme.cfeGreen
                      : AppTheme.secondaryText,
                ),
              ],
            ),
            if (seleccionado) ...[
              const SizedBox(height: 12),
              _construirBotonPrincipal(
                texto: estaRestaurando
                    ? 'Iniciando restauración...'
                    : 'Restaurar este respaldo',
                icono: Icons.settings_backup_restore,
                onPressed: estaCompletado && !hayRestauracionEnCurso
                    ? () => _restaurarRespaldo(viewmodel, respaldo)
                    : null,
                color: AppTheme.errorRed,
                cargando: estaRestaurando,
              ),
              if (!estaCompletado) ...[
                const SizedBox(height: 8),
                Text(
                  'Este respaldo aún no está completado y no se puede '
                  'restaurar.',
                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirDatoRespaldo(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, size: 16, color: AppTheme.secondaryText),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjeta({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required Widget contenido,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cfeGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: AppTheme.cfeGreen, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            descripcion,
            style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 20),
          contenido,
        ],
      ),
    );
  }

  Widget _construirBotonPrincipal({
    required String texto,
    required IconData icono,
    required VoidCallback? onPressed,
    Color? color,
    bool cargando = false,
  }) {
    final colorBoton = color ?? AppTheme.cfeGreen;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: cargando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icono),
        label: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorBoton,
          foregroundColor: AppTheme.pureWhite,
          disabledBackgroundColor: colorBoton.withValues(alpha: 0.45),
          disabledForegroundColor: AppTheme.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _construirEstadoVacio({
    required IconData icono,
    required String mensaje,
    required String descripcion,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.pearlWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 34, color: AppTheme.secondaryText),
          const SizedBox(height: 10),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}
