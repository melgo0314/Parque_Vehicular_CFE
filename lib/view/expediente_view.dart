import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:p_vehicular/view/form_expediente.dart';

import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';
import '../models/documento_model.dart';
import '../models/expediente_model.dart';
import '../viewmodel/expediente_viewmodel.dart';
import '../viewmodel/mantenimiento_viewmodel.dart';
import 'widgets/expediente_web_viewer.dart';

bool _esArchivoImagen(ExpedienteModel expediente) {
  final mime = expediente.tipoMime.trim().toLowerCase();
  final extension = expediente.nombreArchivo
      .split('.')
      .last
      .trim()
      .toLowerCase();

  return mime.startsWith('image/') ||
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(extension);
}

bool _esArchivoPdf(ExpedienteModel expediente) {
  final mime = expediente.tipoMime.trim().toLowerCase();
  final extension = expediente.nombreArchivo
      .split('.')
      .last
      .trim()
      .toLowerCase();

  return mime == 'application/pdf' || extension == 'pdf';
}

class ExpedienteView extends StatefulWidget {
  const ExpedienteView({super.key, required List<dynamic> vehiculos});

  @override
  State<ExpedienteView> createState() => _ExpedienteViewState();
}

class _ExpedienteViewState extends State<ExpedienteView> {
  final ExpedienteViewModel _viewModel = ExpedienteViewModel();

  // ViewModel utilizado para obtener los vehículos,
  // igual que en el módulo de Mantenimientos.
  final MantenimientoViewModel _vehiculosViewModel = MantenimientoViewModel();

  final TextEditingController _busquedaController = TextEditingController();

  // Flujos y consulta del rol del usuario.
  late final Stream<List<VehiculoModel>> _vehiculosStream;
  late final Future<bool> _esOperadorFuture;

  String _busqueda = '';
  String _filtro = 'todos';

  // Guarda el UID del vehículo seleccionado.
  String? _vehiculoSeleccionadoUid;

  @override
  void initState() {
    super.initState();

    // Obtiene los vehículos según el rol del usuario.
    _vehiculosStream = _vehiculosViewModel.obtenerVehiculos();

    // Consulta si el usuario tiene el rol de operador.
    _esOperadorFuture = _consultarSiEsOperador();

    // Inicializa el catálogo de tipos de documentos.
    _viewModel.inicializarCatalogo();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _viewModel.dispose();
    _vehiculosViewModel.dispose();
    super.dispose();
  }

  // Consulta el rol del usuario en Firestore.
  // El filtrado de vehículos ya lo realiza MantenimientoRepositorie.
  Future<bool> _consultarSiEsOperador() async {
    final usuarioActual = FirebaseAuth.instance.currentUser;

    if (usuarioActual == null) {
      return true;
    }

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(usuarioActual.uid)
          .get();

      final rol =
          documento.data()?['rol']?.toString().trim().toLowerCase() ?? '';

      return rol != 'administrador' && rol != 'superusuario';
    } catch (_) {
      // Si no se puede comprobar el rol, se oculta el selector.
      return true;
    }
  }

  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}'.trim();
  }

  Future<void> _verDocumento(ExpedienteModel expediente) async {
    final archivo = kIsWeb ? null : _viewModel.descargarArchivo(expediente);
    final url = kIsWeb
        ? expediente.archivoUrl.trim().isNotEmpty
              ? Future<String>.value(expediente.archivoUrl.trim())
              : _viewModel.obtenerUrlVisualizacion(expediente)
        : null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VisorDocumentoDialog(
        expediente: expediente,
        archivo: archivo,
        url: url,
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    return '$dia/$mes/$anio';
  }

  String _nombreDocumento(
    ExpedienteModel expediente,
    List<DocumentoModel> documentos,
  ) {
    for (final documento in documentos) {
      if (documento.uid == expediente.documentoUid) {
        return documento.nombre;
      }
    }

    return expediente.nombreArchivo;
  }

  bool _coincideBusqueda(
    ExpedienteModel expediente,
    List<DocumentoModel> documentos,
  ) {
    final nombre = _nombreDocumento(expediente, documentos);
    final archivo = expediente.nombreArchivo;

    return nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
        archivo.toLowerCase().contains(_busqueda.toLowerCase());
  }

  bool _coincideFiltro(ExpedienteModel expediente) {
    if (_filtro == 'todos') {
      return true;
    }

    final vencimiento = expediente.fechaVencimiento;

    if (vencimiento == null) {
      return _filtro == 'sin_vencimiento';
    }

    final hoy = DateTime.now();
    final fechaActual = DateTime(hoy.year, hoy.month, hoy.day);
    final fechaDocumento = DateTime(
      vencimiento.year,
      vencimiento.month,
      vencimiento.day,
    );

    if (_filtro == 'vencidos') {
      return fechaDocumento.isBefore(fechaActual);
    }

    if (_filtro == 'vigentes') {
      return !fechaDocumento.isBefore(fechaActual);
    }

    if (_filtro == 'sin_vencimiento') {
      return false;
    }

    return true;
  }

  String _estadoDocumento(ExpedienteModel expediente) {
    if (expediente.fechaVencimiento == null) {
      return 'Sin vencimiento';
    }

    final hoy = DateTime.now();
    final fechaActual = DateTime(hoy.year, hoy.month, hoy.day);
    final vencimiento = expediente.fechaVencimiento!;

    final fechaDocumento = DateTime(
      vencimiento.year,
      vencimiento.month,
      vencimiento.day,
    );

    if (fechaDocumento.isBefore(fechaActual)) {
      return 'Vencido';
    }

    return 'Vigente';
  }

  Color _colorEstado(ExpedienteModel expediente) {
    if (expediente.fechaVencimiento == null) {
      return AppTheme.secondaryText;
    }

    if (_estadoDocumento(expediente) == 'Vencido') {
      return AppTheme.errorRed;
    }

    return AppTheme.operationalText;
  }

  IconData _iconoArchivo(ExpedienteModel expediente) {
    if (_esArchivoPdf(expediente)) {
      return Icons.picture_as_pdf_outlined;
    }

    return Icons.image_outlined;
  }

  Future<void> _abrirFormulario({
    required VehiculoModel vehiculo,
    required List<DocumentoModel> documentos,
    ExpedienteModel? expediente,
  }) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormExpedienteView(
          vehiculo: vehiculo,
          documentos: documentos,
          expediente: expediente,
        ),
      ),
    );

    if (resultado == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmarEliminacion(ExpedienteModel expediente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.pureWhite,
          title: const Text(
            'Eliminar documento',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este documento? '
            'También se eliminará el archivo almacenado.',
            style: TextStyle(color: AppTheme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 48),
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && mounted) {
      final resultado = await _viewModel.eliminarExpediente(expediente.uid);

      if (!mounted) return;

      _mostrarMensaje(
        resultado ? _viewModel.mensajeExito : _viewModel.mensajeError,
        resultado,
      );

      setState(() {});
    }
  }

  void _mostrarMensaje(String? mensaje, bool correcto) {
    if (mensaje == null || mensaje.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: correcto
              ? AppTheme.operationalText
              : AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _chipFiltro(String valor, String etiqueta) {
    final seleccionado = _filtro == valor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(etiqueta),
        selected: seleccionado,
        showCheckmark: seleccionado,
        onSelected: (_) {
          setState(() {
            _filtro = valor;
          });
        },
        selectedColor: AppTheme.cfeGreen,
        backgroundColor: AppTheme.pureWhite,
        labelStyle: TextStyle(
          color: seleccionado ? AppTheme.pureWhite : AppTheme.primaryText,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: seleccionado ? AppTheme.cfeGreen : AppTheme.border,
        ),
      ),
    );
  }

  Widget _tarjetaExpediente(
    ExpedienteModel expediente,
    List<DocumentoModel> documentos,
    VehiculoModel vehiculo,
  ) {
    final estado = _estadoDocumento(expediente);
    final colorEstado = _colorEstado(expediente);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.avatarSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconoArchivo(expediente),
                color: AppTheme.avatarText,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombreDocumento(expediente, documentos),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    expediente.nombreArchivo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          estado,
                          style: TextStyle(
                            color: colorEstado,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppTheme.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            expediente.fechaVencimiento == null
                                ? 'Sin fecha de vencimiento'
                                : 'Vence: ${_formatearFecha(expediente.fechaVencimiento!)}',
                            style: const TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _verDocumento(expediente),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver documento'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.cfeGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones del documento',
              icon: const Icon(Icons.more_vert, color: AppTheme.secondaryText),
              onSelected: (opcion) {
                if (opcion == 'editar') {
                  _abrirFormulario(
                    vehiculo: vehiculo,
                    documentos: documentos,
                    expediente: expediente,
                  );
                } else if (opcion == 'eliminar') {
                  _confirmarEliminacion(expediente);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AppTheme.cfeGreen),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.errorRed),
                      SizedBox(width: 8),
                      Text('Eliminar'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajeVacio(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 45),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 55,
              color: AppTheme.secondaryText.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Selector de vehículos.
  // El operador no puede cambiar de vehículo desde esta pantalla.
  Widget _selectorVehiculo(
    List<VehiculoModel> vehiculos,
    VehiculoModel vehiculoSeleccionado,
    bool esOperador,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: vehiculoSeleccionado.uid,
          hint: const Text('Selecciona un vehículo'),
          items: vehiculos.map((vehiculo) {
            return DropdownMenuItem<String>(
              value: vehiculo.uid,
              child: Text(
                '${vehiculo.numeroEconomico} · ${_nombreVehiculo(vehiculo)}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: esOperador
              ? null
              : (uid) {
                  setState(() {
                    _vehiculoSeleccionadoUid = uid;
                    _busqueda = '';
                    _busquedaController.clear();
                    _filtro = 'todos';
                  });
                },
        ),
      ),
    );
  }

  Widget _contenidoExpedientes(
    VehiculoModel vehiculo,
    List<DocumentoModel> documentos,
  ) {
    return StreamBuilder<List<ExpedienteModel>>(
      stream: _viewModel.obtenerExpedientes(vehiculo.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(35),
              child: CircularProgressIndicator(color: AppTheme.cfeGreen),
            ),
          );
        }

        if (snapshot.hasError) {
          return _mensajeVacio(
            'No fue posible consultar los documentos del vehículo.',
          );
        }

        final expedientes = snapshot.data ?? [];

        final filtrados = expedientes.where((expediente) {
          return _coincideBusqueda(expediente, documentos) &&
              _coincideFiltro(expediente);
        }).toList();

        if (expedientes.isEmpty) {
          return _mensajeVacio(
            'Este vehículo todavía no tiene documentos registrados.',
          );
        }

        if (filtrados.isEmpty) {
          return _mensajeVacio(
            'No se encontraron documentos con los criterios seleccionados.',
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtrados.length,
          itemBuilder: (context, index) {
            return _tarjetaExpediente(filtrados[index], documentos, vehiculo);
          },
        );
      },
    );
  }

  // Construye el contenido del expediente con los vehículos recibidos.
  Widget _construirContenido({
    required bool esOperador,
    required List<VehiculoModel> vehiculos,
  }) {
    if (vehiculos.isEmpty) {
      return _mensajeVacio(
        esOperador
            ? 'No tienes un vehículo asignado para consultar su expediente.'
            : 'No hay vehículos registrados para consultar su expediente.',
      );
    }

    // Mantiene el mismo comportamiento que Mantenimientos.
    if (esOperador && vehiculos.length > 1) {
      return _mensajeVacio(
        'Tu cuenta tiene más de un vehículo asignado. '
        'Contacta al administrador para corregirlo.',
      );
    }

    // Busca el vehículo seleccionado por su UID.
    // Si no existe una selección válida, utiliza el primero.
    VehiculoModel? vehiculoSeleccionado;

    for (final vehiculo in vehiculos) {
      if (vehiculo.uid == _vehiculoSeleccionadoUid) {
        vehiculoSeleccionado = vehiculo;
        break;
      }
    }

    vehiculoSeleccionado ??= vehiculos.first;

    return StreamBuilder<List<DocumentoModel>>(
      stream: _viewModel.obtenerDocumentos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.cfeGreen),
          );
        }

        if (snapshot.hasError) {
          return _mensajeVacio(
            'No fue posible cargar los tipos de documentos.',
          );
        }

        final documentos = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selección del vehículo.
              const Text(
                'Vehículo',
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _selectorVehiculo(vehiculos, vehiculoSeleccionado!, esOperador),
              const SizedBox(height: 18),
              // Botón para registrar un documento.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: documentos.isEmpty
                      ? null
                      : () {
                          _abrirFormulario(
                            vehiculo: vehiculoSeleccionado!,
                            documentos: documentos,
                          );
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar documento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cfeGreen,
                    foregroundColor: AppTheme.pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Documentos registrados',
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Búsqueda de documentos.
              TextField(
                controller: _busquedaController,
                onChanged: (valor) {
                  setState(() {
                    _busqueda = valor.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar documento...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.secondaryText,
                  ),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() {
                              _busqueda = '';
                            });
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Filtros por vigencia.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chipFiltro('todos', 'Todos'),
                    _chipFiltro('vigentes', 'Vigentes'),
                    _chipFiltro('vencidos', 'Vencidos'),
                    _chipFiltro('sin_vencimiento', 'Sin vencimiento'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _contenidoExpedientes(vehiculoSeleccionado, documentos),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _esOperadorFuture,
      builder: (context, rolSnapshot) {
        final esOperador = rolSnapshot.data ?? true;

        return StreamBuilder<List<VehiculoModel>>(
          stream: _vehiculosStream,
          builder: (context, vehiculosSnapshot) {
            final vehiculos = vehiculosSnapshot.data ?? [];

            return Scaffold(
              bottomNavigationBar: const InicioFooter(),
              backgroundColor: AppTheme.pearlWhite,
              appBar: AppBar(
                title: const Text('Expediente digital'),
                backgroundColor: AppTheme.cfeGreen,
                foregroundColor: AppTheme.pureWhite,
                iconTheme: const IconThemeData(color: AppTheme.pureWhite),
                elevation: 0,
              ),

              body: SafeArea(
                child:
                    rolSnapshot.connectionState == ConnectionState.waiting ||
                        (vehiculosSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !vehiculosSnapshot.hasData)
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.cfeGreen,
                        ),
                      )
                    : vehiculosSnapshot.hasError
                    ? _mensajeVacio(
                        'No se pudieron cargar los vehículos. '
                        'Revisa tu conexión o los permisos de tu cuenta.',
                      )
                    : _construirContenido(
                        esOperador: esOperador,
                        vehiculos: vehiculos,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VisorDocumentoDialog extends StatelessWidget {
  const _VisorDocumentoDialog({
    required this.expediente,
    required this.archivo,
    required this.url,
  });

  final ExpedienteModel expediente;
  final Future<Uint8List>? archivo;
  final Future<String>? url;

  Widget _mensajeError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height * 0.84;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: AppTheme.pureWhite,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1100, maxHeight: altura),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
              decoration: const BoxDecoration(
                color: AppTheme.cfeGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Icon(
                    _esArchivoPdf(expediente)
                        ? Icons.picture_as_pdf_outlined
                        : _esArchivoImagen(expediente)
                        ? Icons.image_outlined
                        : Icons.description_outlined,
                    color: AppTheme.pureWhite,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      expediente.nombreArchivo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar visor',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.pureWhite),
                  ),
                ],
              ),
            ),
            Expanded(
              child: kIsWeb
                  ? FutureBuilder<String>(
                      future: url,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.cfeGreen,
                            ),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _mensajeError(
                            'No se pudo obtener el enlace del archivo en '
                            'Firebase Storage: ${snapshot.error ?? 'sin detalle'}',
                          );
                        }
                        return crearExpedienteWebViewer(
                          snapshot.data!,
                          esImagen: _esArchivoImagen(expediente),
                        );
                      },
                    )
                  : FutureBuilder<Uint8List>(
                      future: archivo,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.cfeGreen,
                            ),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          final error = snapshot.error;
                          final mensaje = error is StateError
                              ? error.message.toString()
                              : 'No se pudo descargar el archivo. Comprueba '
                                    'la conexión y los permisos de Firebase Storage.';

                          return _mensajeError(mensaje);
                        }

                        final bytes = snapshot.data!;

                        if (_esArchivoPdf(expediente)) {
                          return PdfViewer.data(
                            bytes,
                            sourceName:
                                '${expediente.uid}_${expediente.nombreArchivo}',
                          );
                        }

                        if (_esArchivoImagen(expediente)) {
                          return InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Center(
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Text(
                                  'No se pudo interpretar la imagen.',
                                ),
                              ),
                            ),
                          );
                        }

                        return const Center(
                          child: Text(
                            'El formato de este archivo no tiene visor.',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
