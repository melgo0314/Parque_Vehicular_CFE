import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';

import '../core/theme/app_theme.dart';
import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/inventario_viewmodel.dart';

class FormInventarioView extends StatefulWidget {
  final List<VehiculoModel> vehiculos;
  final VehiculoModel? vehiculoInicial;
  final InventarioModel? registro;

  const FormInventarioView({
    super.key,
    required this.vehiculos,
    this.vehiculoInicial,
    this.registro,
  });

  @override
  State<FormInventarioView> createState() => _FormInventarioViewState();
}

class _FormInventarioViewState extends State<FormInventarioView> {
  final InventarioViewModel _viewModel = InventarioViewModel();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final Stream<List<ArticuloModel>> _articulosStream;

  VehiculoModel? _vehiculoSeleccionado;
  String? _articuloUid;

  int _cantidad = 1;
  String _estado = 'bueno';

  bool _articuloSeleccionadoInicializado = false;
  bool _guardando = false;

  final TextEditingController _observacionesController =
      TextEditingController();

  bool get _esEdicion => widget.registro != null;

  @override
  void initState() {
    super.initState();

    // Esta consulta debe devolver solo los artículos activos.
    _articulosStream = _viewModel.obtenerArticulos();

    if (widget.vehiculos.isNotEmpty) {
      if (widget.registro != null) {
        _vehiculoSeleccionado = widget.vehiculos.firstWhere(
          (vehiculo) => vehiculo.uid == widget.registro!.vehiculoUid,
          orElse: () => widget.vehiculos.first,
        );
      } else {
        final vehiculoInicial = widget.vehiculoInicial;

        if (vehiculoInicial != null &&
            widget.vehiculos.any(
              (vehiculo) => vehiculo.uid == vehiculoInicial.uid,
            )) {
          _vehiculoSeleccionado = vehiculoInicial;
        } else {
          _vehiculoSeleccionado = widget.vehiculos.first;
        }
      }
    }

    final registro = widget.registro;
    if (registro != null) {
      _articuloUid = registro.articuloUid;
      _cantidad = registro.cantidad;
      _estado = registro.estado.toLowerCase();
      _observacionesController.text = registro.observaciones;
    }
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.numeroEconomico} · ${vehiculo.marca} '
        '${vehiculo.modelo} ${vehiculo.anio}';
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final articuloUid = _articuloUid;
    final vehiculo = _vehiculoSeleccionado;

    if (articuloUid == null || vehiculo == null) return;

    setState(() => _guardando = true);

    final registro = InventarioModel(
      uid: widget.registro?.uid ?? '',
      vehiculoUid: vehiculo.uid,
      articuloUid: articuloUid,
      cantidad: _cantidad,
      existe: _cantidad > 0,
      estado: _estado,
      observaciones: _observacionesController.text.trim(),
      usuarioUid: '',
      rpeUsuario: '',
      actualizadoEn: DateTime.now(),
    );

    final guardado = await _viewModel.guardarRegistro(registro);

    if (!mounted) return;

    setState(() => _guardando = false);

    if (guardado) {
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar el artículo.',
        esError: true,
      );
    }
  }

  Future<void> _eliminar() async {
    final registro = widget.registro;
    if (registro == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar artículo'),
          content: const Text(
            '¿Quieres retirar este artículo del inventario del vehículo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);

    final eliminado = await _viewModel.eliminarRegistro(
      vehiculoUid: registro.vehiculoUid,
      articuloUid: registro.articuloUid,
    );

    if (!mounted) return;

    setState(() => _guardando = false);

    if (eliminado) {
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo eliminar el artículo.',
        esError: true,
      );
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _botonCantidad({
    required IconData icono,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.cfeGreen,
        minimumSize: const Size(52, 52),
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Icon(icono),
    );
  }

  Widget _opcionEstado(String valor, String texto) {
    final seleccionado = _estado == valor;

    return Expanded(
      child: ElevatedButton(
        onPressed: _guardando ? null : () => setState(() => _estado = valor),
        style: ElevatedButton.styleFrom(
          backgroundColor: seleccionado
              ? AppTheme.cfeGreen
              : AppTheme.pureWhite,
          foregroundColor: seleccionado
              ? AppTheme.pureWhite
              : AppTheme.primaryText,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: Text(texto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const InicioFooter(),
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: Text(
          _esEdicion ? 'Editar artículo' : 'Registrar artículo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 650,
                    maxHeight: constraints.maxHeight * 0.96,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: AppTheme.pureWhite,
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      child: widget.vehiculos.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No hay vehículos registrados.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : StreamBuilder<List<ArticuloModel>>(
                              stream: _articulosStream,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'No se pudo cargar el catálogo '
                                        'de artículos.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.cfeGreen,
                                    ),
                                  );
                                }

                                final articulos = snapshot.data!;

                                if (!_articuloSeleccionadoInicializado &&
                                    articulos.isNotEmpty) {
                                  _articuloSeleccionadoInicializado = true;

                                  final estaEnCatalogo = articulos.any(
                                    (articulo) => articulo.uid == _articuloUid,
                                  );

                                  if (!estaEnCatalogo) {
                                    _articuloUid = articulos.first.uid;
                                  }
                                }

                                return Container(
                                  width: double.infinity,
                                  color: AppTheme.pureWhite,
                                  child: Form(
                                    key: _formKey,
                                    child: ListView(
                                      padding: const EdgeInsets.all(20),
                                      children: [
                                        _etiqueta('Vehículo'),
                                        DropdownButtonFormField<String>(
                                          initialValue:
                                              _vehiculoSeleccionado?.uid,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            prefixIcon: Icon(
                                              Icons.local_shipping_outlined,
                                            ),
                                          ),
                                          items: widget.vehiculos.map((
                                            vehiculo,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: vehiculo.uid,
                                              child: Text(
                                                _nombreVehiculo(vehiculo),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _esEdicion || _guardando
                                              ? null
                                              : (uid) {
                                                  if (uid == null) return;

                                                  for (final vehiculo
                                                      in widget.vehiculos) {
                                                    if (vehiculo.uid == uid) {
                                                      setState(() {
                                                        _vehiculoSeleccionado =
                                                            vehiculo;
                                                      });
                                                      break;
                                                    }
                                                  }
                                                },
                                          validator: (uid) {
                                            if (uid == null || uid.isEmpty) {
                                              return 'Selecciona un vehículo.';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _etiqueta('Artículo'),
                                        DropdownButtonFormField<String>(
                                          initialValue:
                                              articulos.any(
                                                (articulo) =>
                                                    articulo.uid ==
                                                    _articuloUid,
                                              )
                                              ? _articuloUid
                                              : null,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            prefixIcon: Icon(
                                              Icons.inventory_2_outlined,
                                            ),
                                          ),
                                          items: articulos.map((articulo) {
                                            return DropdownMenuItem<String>(
                                              value: articulo.uid,
                                              child: Text(
                                                articulo.nombre,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _esEdicion || _guardando
                                              ? null
                                              : (valor) {
                                                  setState(() {
                                                    _articuloUid = valor;
                                                  });
                                                },
                                          validator: (valor) {
                                            if (valor == null ||
                                                valor.isEmpty) {
                                              return 'Selecciona un artículo.';
                                            }
                                            return null;
                                          },
                                        ),
                                        if (articulos.isEmpty) ...[
                                          const SizedBox(height: 8),
                                          const Text(
                                            'No hay artículos activos '
                                            'en el catálogo.',
                                            style: TextStyle(
                                              color: AppTheme.errorRed,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        _etiqueta('Cantidad'),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _botonCantidad(
                                              icono: Icons.remove,
                                              onPressed:
                                                  !_guardando && _cantidad > 0
                                                  ? () => setState(
                                                      () => _cantidad--,
                                                    )
                                                  : null,
                                            ),
                                            Text(
                                              '$_cantidad',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            _botonCantidad(
                                              icono: Icons.add,
                                              onPressed: _guardando
                                                  ? null
                                                  : () => setState(
                                                      () => _cantidad++,
                                                    ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _etiqueta('Estado'),
                                        Row(
                                          children: [
                                            _opcionEstado('bueno', 'Bueno'),
                                            const SizedBox(width: 8),
                                            _opcionEstado('regular', 'Regular'),
                                            const SizedBox(width: 8),
                                            _opcionEstado('danado', 'Dañado'),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _etiqueta('Observaciones (opcional)'),
                                        TextFormField(
                                          controller: _observacionesController,
                                          maxLines: 3,
                                          maxLength: 250,
                                          enabled: !_guardando,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Agrega detalles si son '
                                                'necesarios',
                                            alignLabelWithHint: true,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed:
                                              _guardando || articulos.isEmpty
                                              ? null
                                              : _guardar,
                                          icon: _guardando
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            AppTheme.pureWhite,
                                                      ),
                                                )
                                              : const Icon(Icons.check),
                                          label: Text(
                                            _esEdicion
                                                ? 'Guardar cambios'
                                                : 'Guardar artículo',
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: _guardando
                                              ? null
                                              : () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                          icon: const Icon(Icons.close),
                                          label: const Text('Cancelar'),
                                        ),
                                        if (_esEdicion) ...[
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: _guardando
                                                ? null
                                                : _eliminar,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.errorRed,
                                              side: const BorderSide(
                                                color: AppTheme.errorRed,
                                              ),
                                              minimumSize:
                                                  const Size.fromHeight(52),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            label: const Text(
                                              'Eliminar artículo',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
