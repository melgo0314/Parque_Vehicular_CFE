
import 'package:flutter/material.dart';
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
  // Respaldo seleccionado para restaurar.
  String? _respaldoSeleccionado;

  // Identificador del respaldo que se está restaurando.
  String? _restaurandoIdentificador;

  @override
  void initState() {
    super.initState();

    // Consulta el historial automáticamente al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<RespaldoViewmodel>().obtenerRespaldos();
    });
  }

  // Muestra mensajes en pantalla.
  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor:
            error ? AppTheme.errorRed : AppTheme.cfeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Inicia el proceso para generar un respaldo.
  Future<void> _generarRespaldo(
    RespaldoViewmodel viewmodel,
  ) async {
    final resultado = await viewmodel.generarRespaldo();

    if (!mounted) return;

    if (resultado) {
      _mostrarMensaje(
        'La solicitud de respaldo se inició correctamente. '
        'El respaldo aparecerá en el historial cuando termine el proceso.',
      );
    } else {
      _mostrarMensaje(
        viewmodel.error ?? 'No fue posible iniciar el respaldo.',
        error: true,
      );
    }
  }

  // Actualiza el historial de respaldos.
  Future<void> _actualizarHistorial(
    RespaldoViewmodel viewmodel,
  ) async {
    await viewmodel.obtenerRespaldos();

    if (!mounted) return;

    if (viewmodel.error != null) {
      _mostrarMensaje(
        viewmodel.error!,
        error: true,
      );
    } else {
      _mostrarMensaje('Historial de respaldos actualizado.');
    }
  }

  // Valida la selección y solicita confirmación.
  Future<void> _restaurarRespaldo(
    RespaldoViewmodel viewmodel,
  ) async {
    if (_respaldoSeleccionado == null) {
      _mostrarMensaje(
        'Selecciona un respaldo antes de continuar.',
        error: true,
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirmar restauración',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Esta operación restaurará la información en el '
            'proyecto p-vehicular. '
            'Los datos actuales podrían verse afectados. '
            '¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: AppTheme.secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _restaurandoIdentificador = _respaldoSeleccionado;
    });

    final resultado = await viewmodel.restaurarRespaldo(
      _respaldoSeleccionado!,
    );

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
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        title: const Text(
          'Respaldo y Restauración',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<RespaldoViewmodel>(
        builder: (context, viewmodel, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final esPantallaGrande = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _construirEncabezado(),

                        const SizedBox(height: 24),

                        if (viewmodel.error != null)
                          _construirMensajeError(viewmodel.error!),

                        if (esPantallaGrande)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _construirSeccionRespaldo(
                                  viewmodel,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _construirSeccionRestauracion(
                                  viewmodel,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _construirSeccionRespaldo(
                                viewmodel,
                              ),
                              const SizedBox(height: 20),
                              _construirSeccionRestauracion(
                                viewmodel,
                              ),
                            ],
                          ),
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

  // Encabezado general.
  Widget _construirEncabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administración de la base de datos',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Genera respaldos de la información y recupera '
          'los datos cuando sea necesario.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }

  // Mensaje de error.
  Widget _construirMensajeError(String mensaje) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sección para generar y consultar respaldos.
  Widget _construirSeccionRespaldo(
    RespaldoViewmodel viewmodel,
  ) {
    return _construirTarjeta(
      icono: Icons.cloud_upload_outlined,
      titulo: 'Respaldos',
      descripcion:
          'Crea una copia de seguridad de la información '
          'almacenada en el sistema.',
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
                icon: Icon(
                  Icons.refresh,
                  color: AppTheme.cfeGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (viewmodel.cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(),
              ),
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

  // Muestra los respaldos obtenidos desde Firestore.
  Widget _construirListaRespaldos(
    RespaldoViewmodel viewmodel,
  ) {
    return Column(
      children: viewmodel.respaldos.map((respaldo) {
        final seleccionado =
            _respaldoSeleccionado == respaldo.identificador;

        return _construirTarjetaRespaldo(
          respaldo,
          seleccionado,
          viewmodel,
        );
      }).toList(),
    );
  }

  // Tarjeta individual del historial.
  Widget _construirTarjetaRespaldo(
    RespaldoModel respaldo,
    bool seleccionado,
    RespaldoViewmodel viewmodel,
  ) {
    final estaCompletado = respaldo.estaCompletado;

    return InkWell(
      onTap: () {
        setState(() {
          _respaldoSeleccionado = respaldo.identificador;
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
            color: seleccionado
                ? AppTheme.cfeGreen
                : AppTheme.border,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup_outlined,
                  color: AppTheme.cfeGreen,
                  size: 22,
                ),
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
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText,
              ),
            ),

            const SizedBox(height: 3),

            SelectableText(
              respaldo.identificador,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryText,
              ),
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
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.errorRed,
                ),
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: estaCompletado &&
                          _restaurandoIdentificador == null
                      ? () => _restaurarRespaldo(viewmodel)
                      : null,
                  icon: _restaurandoIdentificador ==
                          respaldo.identificador
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.settings_backup_restore),
                  label: const Text('Restaurar este respaldo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(
                      color: AppTheme.errorRed,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Muestra un dato del respaldo con su icono.
  Widget _construirDatoRespaldo(
    IconData icono,
    String texto,
  ) {
    return Row(
      children: [
        Icon(
          icono,
          size: 16,
          color: AppTheme.secondaryText,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  // Sección para seleccionar y restaurar respaldos.
  Widget _construirSeccionRestauracion(
    RespaldoViewmodel viewmodel,
  ) {
    final respaldoSeleccionado = viewmodel.respaldos
        .where(
          (respaldo) =>
              respaldo.identificador == _respaldoSeleccionado,
        )
        .toList();

    final respaldo = respaldoSeleccionado.isNotEmpty
        ? respaldoSeleccionado.first
        : null;

    return _construirTarjeta(
      icono: Icons.cloud_download_outlined,
      titulo: 'Restauración',
      descripcion:
          'Selecciona un respaldo del historial para recuperar '
          'la información del sistema.',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destino de restauración',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.pearlWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: AppTheme.cfeGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proyecto de producción',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'p-vehicular',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Respaldo seleccionado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),

          const SizedBox(height: 8),

          if (respaldo == null)
            _construirEstadoVacio(
              icono: Icons.backup_outlined,
              mensaje: 'Ningún respaldo seleccionado.',
              descripcion:
                  'Selecciona un respaldo del historial para continuar.',
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.pearlWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.cfeGreen,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.cfeGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Respaldo seleccionado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cfeGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    respaldo.identificador,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estado: ${respaldo.estado}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  Text(
                    'Fecha: ${respaldo.fechaFormateada}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          _construirBotonPrincipal(
            texto: _restaurandoIdentificador != null
                ? 'Iniciando restauración...'
                : 'Restaurar respaldo',
            icono: Icons.settings_backup_restore,
            onPressed: respaldo != null &&
                    respaldo.estaCompletado &&
                    _restaurandoIdentificador == null
                ? () => _restaurarRespaldo(viewmodel)
                : null,
            color: AppTheme.errorRed,
            cargando: _restaurandoIdentificador != null,
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.alertOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La restauración modifica información del '
                  'proyecto. Verifica el respaldo '
                  'seleccionado antes de continuar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tarjeta reutilizable para cada sección.
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
        border: Border.all(
          color: AppTheme.border,
        ),
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
                child: Icon(
                  icono,
                  color: AppTheme.cfeGreen,
                  size: 26,
                ),
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
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryText,
            ),
          ),

          const SizedBox(height: 20),

          contenido,
        ],
      ),
    );
  }

  // Botón principal reutilizable.
  Widget _construirBotonPrincipal({
    required String texto,
    required IconData icono,
    required VoidCallback? onPressed,
    Color? color,
    bool cargando = false,
  }) {
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
        label: Text(
          texto,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.cfeGreen,
          foregroundColor: AppTheme.pureWhite,
          disabledBackgroundColor:
              (color ?? AppTheme.cfeGreen).withValues(alpha: 0.45),
          disabledForegroundColor: AppTheme.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Mensaje reutilizable cuando todavía no hay información.
  Widget _construirEstadoVacio({
    required IconData icono,
    required String mensaje,
    required String descripcion,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: AppTheme.pearlWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icono,
            size: 34,
            color: AppTheme.secondaryText,
          ),
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
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
