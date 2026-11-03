import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/inventario_viewmodel.dart';
import 'form_inventario_view.dart';

// Pantalla que presenta el inventario asociado a los vehículos registrados.
class InventarioView extends StatefulWidget {
  // Entrada: lista de vehículos recibida por la pantalla.
  // Salida: una instancia de InventarioView.
  const InventarioView({super.key, required List<dynamic> vehiculos});

  // Crea el estado que administra la pantalla.
  // Entrada: ninguna.
  // Salida: el estado de tipo _InventarioViewState.
  @override
  State<InventarioView> createState() => _InventarioViewState();
}

// Estado de la pantalla y administración de sus datos de inventario.
class _InventarioViewState extends State<InventarioView> {
  // ViewModel que obtiene y modifica los datos del inventario.
  final InventarioViewModel _viewModel = InventarioViewModel();

  // Flujos que mantienen actualizadas las listas de vehículos y artículos.
  late final Stream<List<VehiculoModel>> _vehiculosStream;
  late final Stream<List<ArticuloModel>> _articulosStream;

  // Flujo del inventario correspondiente al vehículo seleccionado.
  Stream<List<InventarioModel>>? _inventarioStream;

  // Vehículo seleccionado actualmente en la pantalla.
  VehiculoModel? _vehiculoSeleccionado;

  // Inicializa los flujos de vehículos y artículos.
  // Entrada: ninguna.
  // Salida: ninguna; prepara los datos que utilizará la pantalla.
  @override
  void initState() {
    super.initState();
    _vehiculosStream = _viewModel.obtenerVehiculos();
    _articulosStream = _viewModel.obtenerArticulos();
  }

  // Libera los recursos del ViewModel al cerrar la pantalla.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // Construye el nombre visible de un vehículo.
  // Entrada: un objeto VehiculoModel.
  // Salida: una cadena con el número económico, marca, modelo y año.
  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.numeroEconomico} · ${vehiculo.marca} '
        '${vehiculo.modelo} ${vehiculo.anio}';
  }

  // Selecciona un vehículo y carga el flujo de su inventario.
  // Entrada: la lista de vehículos y el UID seleccionado, que puede ser nulo.
  // Salida: ninguna; actualiza el vehículo y el inventario mostrados.
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

  // Abre el formulario para registrar o editar un artículo del inventario.
  // Entrada: lista de vehículos y registro opcional para editar.
  // Salida: ninguna; muestra un aviso si el formulario confirma la operación.
  Future<void> _abrirFormulario({
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventario actualizado correctamente.'),
        ),
      );
    }
  }

  // Solicita confirmación y retira un artículo del inventario del vehículo.
  // Entrada: el artículo y el registro de inventario que se eliminará.
  // Salida: ninguna; muestra el resultado de la operación en pantalla.
  Future<void> _confirmarEliminar(
    ArticuloModel articulo,
    InventarioModel registro,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar artículo'),
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
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          eliminado
              ? 'Artículo retirado del inventario.'
              : _viewModel.mensajeError ?? 'No se pudo eliminar el artículo.',
        ),
      ),
    );
  }

  // Construye la estructura visual principal de la pantalla.
  // Entrada: el contexto de Flutter.
  // Salida: un widget Scaffold con selector, lista y botón para agregar.
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
                    child: Text('No hay vehículos registrados.'),
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
                      value: _vehiculoSeleccionado!.uid,
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
                    const SizedBox(height: 16),
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
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () => _abrirFormulario(
              vehiculos: snapshot.data!,
            ),
            backgroundColor: AppTheme.accentYellow,
            foregroundColor: Colors.black87,
            icon: const Icon(Icons.add),
            label: const Text(
              'Agregar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  // Construye la lista de artículos y sus registros para un vehículo.
  // Entrada: la lista de vehículos disponible para el formulario.
  // Salida: un widget que muestra estados de carga, errores o artículos.
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
            child: Text('Todavía no hay artículos en el catálogo.'),
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
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _abrirFormulario(
                            vehiculos: vehiculos,
                            registro: registro,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.errorRed,
                          ),
                          onPressed: registro == null
                              ? null
                              : () => _confirmarEliminar(
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