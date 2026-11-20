
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/inventario_viewmodel.dart';
import 'form_articulo_view.dart';
import 'form_inventario_view.dart';

class InventarioView extends StatefulWidget {
  const InventarioView({super.key, required List<dynamic> vehiculos});

  @override
  State<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<InventarioView> {
  final InventarioViewModel _viewModel = InventarioViewModel();

  late final Stream<List<VehiculoModel>> _vehiculosStream;
  late final Stream<List<ArticuloModel>> _articulosStream;
  late final Future<String> _rolFuture;

  Stream<List<InventarioModel>>? _inventarioStream;
  VehiculoModel? _vehiculoSeleccionado;

  @override
  void initState() {
    super.initState();

    _vehiculosStream = _viewModel.obtenerVehiculosPermitidos();
    _articulosStream = _viewModel.obtenerArticulos();
    _rolFuture = _viewModel.obtenerRolUsuarioActual();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // Muestra mensajes verdes para operaciones exitosas
  // y rojos cuando ocurre algún error.
  void _mostrarMensaje(String mensaje, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor:
            esError ? AppTheme.errorRed : AppTheme.cfeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _esAdministrador(String rol) {
    return rol == 'administrador' || rol == 'superusuario';
  }

  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.numeroEconomico} · ${vehiculo.marca} '
        '${vehiculo.modelo} ${vehiculo.anio}';
  }

  void _seleccionarVehiculo(
    List<VehiculoModel> vehiculos,
    String? uid,
  ) {
    if (uid == null) return;

    for (final vehiculo in vehiculos) {
      if (vehiculo.uid == uid) {
        setState(() {
          _vehiculoSeleccionado = vehiculo;
          _inventarioStream =
              _viewModel.obtenerInventarioVehiculo(vehiculo.uid);
        });
        return;
      }
    }
  }

  Future<void> _abrirFormularioInventario({
    required List<VehiculoModel> vehiculos,
    InventarioModel? registro,
  }) async {
    if (vehiculos.isEmpty) return;

    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormInventarioView(
          vehiculos: vehiculos,
          vehiculoInicial: _vehiculoSeleccionado,
          registro: registro,
        ),
      ),
    );

    if (resultado == true && mounted) {
      _mostrarMensaje(
        'Inventario actualizado correctamente.',
        esError: false,
      );
    }
  }

  Future<void> _abrirCatalogo() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => const _CatalogoArticulosView(),
      ),
    );
  }

  Future<void> _confirmarEliminar(
    ArticuloModel articulo,
    InventarioModel registro,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Retirar artículo'),
          content: Text(
            '¿Quieres retirar "${articulo.nombre}" del inventario '
            'de este vehículo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 48),
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retirar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    final eliminado = await _viewModel.eliminarRegistro(
      vehiculoUid: registro.vehiculoUid,
      articuloUid: registro.articuloUid,
    );

    if (!mounted) return;

    _mostrarMensaje(
      eliminado
          ? 'Artículo retirado del inventario.'
          : _viewModel.mensajeError ?? 'No se pudo retirar el artículo.',
      esError: !eliminado,
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
          'Inventario del vehículo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<List<VehiculoModel>>(
              stream: _vehiculosStream,
              builder: (context, vehiculosSnapshot) {
                if (vehiculosSnapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los vehículos.'),
                  );
                }

                if (!vehiculosSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final vehiculos = vehiculosSnapshot.data!;

                if (vehiculos.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tienes vehículos asignados o no hay '
                      'vehículos registrados.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final seleccionValida = vehiculos.any(
                  (vehiculo) =>
                      vehiculo.uid == _vehiculoSeleccionado?.uid,
                );

                if (!seleccionValida) {
                  _vehiculoSeleccionado = vehiculos.first;
                  _inventarioStream =
                      _viewModel.obtenerInventarioVehiculo(
                    _vehiculoSeleccionado!.uid,
                  );
                }

                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _vehiculoSeleccionado!.uid,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vehículo',
                        prefixIcon: Icon(
                          Icons.local_shipping_outlined,
                        ),
                      ),
                      items: vehiculos.map((vehiculo) {
                        return DropdownMenuItem<String>(
                          value: vehiculo.uid,
                          child: Text(
                            _nombreVehiculo(vehiculo),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (uid) =>
                          _seleccionarVehiculo(vehiculos, uid),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<String>(
                      future: _rolFuture,
                      builder: (context, rolSnapshot) {
                        if (!rolSnapshot.hasData ||
                            !_esAdministrador(rolSnapshot.data!)) {
                          return const SizedBox.shrink();
                        }

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _abrirCatalogo,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Administrar artículos'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.cfeGreen,
                              side: const BorderSide(
                                color: AppTheme.cfeGreen,
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _construirLista(vehiculos),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<List<VehiculoModel>>(
        stream: _vehiculosStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.data!.isEmpty ||
              _vehiculoSeleccionado == null) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () => _abrirFormularioInventario(
              vehiculos: snapshot.data!,
            ),
            backgroundColor: AppTheme.accentYellow,
            foregroundColor: Colors.black87,
            icon: const Icon(Icons.add),
            label: const Text(
              'Registrar artículo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Widget _construirLista(List<VehiculoModel> vehiculos) {
    return StreamBuilder<List<ArticuloModel>>(
      stream: _articulosStream,
      builder: (context, articulosSnapshot) {
        if (articulosSnapshot.hasError) {
          return const Center(
            child: Text('No se pudo cargar la lista de artículos.'),
          );
        }

        if (!articulosSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final articulos = articulosSnapshot.data!;

        if (articulos.isEmpty) {
          return const Center(
            child: Text(
              'Todavía no hay artículos activos en el catálogo.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return StreamBuilder<List<InventarioModel>>(
          stream: _inventarioStream,
          builder: (context, inventarioSnapshot) {
            if (inventarioSnapshot.hasError) {
              return const Center(
                child: Text('No se pudo cargar el inventario del vehículo.'),
              );
            }

            if (!inventarioSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final registros = inventarioSnapshot.data!;

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: articulos.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final articulo = articulos[index];
                InventarioModel? registro;

                for (final item in registros) {
                  if (item.articuloUid == articulo.uid) {
                    registro = item;
                    break;
                  }
                }

                return Card(
                  color: AppTheme.pureWhite,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: ListTile(
                    title: Text(
                      articulo.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      registro == null
                          ? 'Sin registrar'
                          : 'Cantidad: ${registro.cantidad}'
                              '${registro.observaciones.isEmpty ? '' : ' · ${registro.observaciones}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: registro == null
                        ? null
                        : Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _abrirFormularioInventario(
                                  vehiculos: vehiculos,
                                  registro: registro,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Retirar del vehículo',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.errorRed,
                                ),
                                onPressed: () => _confirmarEliminar(
                                  articulo,
                                  registro!,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CatalogoArticulosView extends StatefulWidget {
  const _CatalogoArticulosView();

  @override
  State<_CatalogoArticulosView> createState() =>
      _CatalogoArticulosViewState();
}

class _CatalogoArticulosViewState extends State<_CatalogoArticulosView> {
  final InventarioViewModel _viewModel = InventarioViewModel();
  late final Stream<List<ArticuloModel>> _articulosStream;

  @override
  void initState() {
    super.initState();
    _articulosStream = _viewModel.obtenerArticulos();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // Muestra mensajes verdes para operaciones exitosas
  // y rojos cuando ocurre algún error.
  void _mostrarMensaje(String mensaje, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor:
            esError ? AppTheme.errorRed : AppTheme.cfeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _abrirFormulario([ArticuloModel? articulo]) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormArticuloView(articulo: articulo),
      ),
    );

    if (resultado == true && mounted) {
      _mostrarMensaje(
        'Catálogo actualizado correctamente.',
        esError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: const Text(
          'Administrar artículos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<ArticuloModel>>(
            stream: _articulosStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('No se pudo cargar el catálogo.'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final articulos = snapshot.data!;

              if (articulos.isEmpty) {
                return const Center(
                  child: Text('Aún no hay artículos en el catálogo.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: articulos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final articulo = articulos[index];

                  return Card(
                    color: AppTheme.pureWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: ListTile(
                      title: Text(
                        articulo.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(articulo.categoria),
                      trailing: IconButton(
                        tooltip: 'Editar artículo',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _abrirFormulario(articulo),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppTheme.accentYellow,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo artículo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
