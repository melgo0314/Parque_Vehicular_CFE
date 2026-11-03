import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/articulo_model.dart';
import '../models/inventario_model.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/inventario_viewmodel.dart';

// Formulario para administrar artículos del inventario de vehículos.
class FormInventarioView extends StatefulWidget {
  // Lista de vehículos disponibles.
  final List<VehiculoModel> vehiculos;

  // Vehículo que se seleccionará inicialmente, si se proporciona.
  final VehiculoModel? vehiculoInicial;

  // Registro de inventario que se editará; null si se crea uno nuevo.
  final InventarioModel? registro;

  // Crea el formulario con los vehículos y datos opcionales.
  // Entradas: key opcional, vehiculos requeridos, vehiculoInicial y registro opcionales.
  // Salida: una instancia de FormInventarioView.
  const FormInventarioView({
    super.key,
    required this.vehiculos,
    this.vehiculoInicial,
    this.registro,
  });

  // Crea el estado asociado al formulario.
  // Entrada: ninguna.
  // Salida: estado que administra los campos y operaciones del inventario.
  @override
  State<FormInventarioView> createState() => _FormInventarioViewState();
}

// Estado y comportamiento del formulario de inventario.
class _FormInventarioViewState extends State<FormInventarioView> {
  // ViewModel que consulta y administra los registros de inventario.
  final InventarioViewModel _viewModel = InventarioViewModel();

  // Llave global para validar los campos del formulario.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Flujo de artículos activos del catálogo.
  late final Stream<List<ArticuloModel>> _articulosStream;

  // Vehículo seleccionado para el registro.
  VehiculoModel? _vehiculoSeleccionado;

  // Identificador del artículo seleccionado.
  String? _articuloUid;

  // Cantidad del artículo.
  int _cantidad = 1;

  // Estado seleccionado para el artículo.
  String _estado = 'bueno';

  // Indica si ya se inicializó la selección del artículo.
  bool _articuloSeleccionadoInicializado = false;

  // Indica si se está guardando o eliminando un registro.
  bool _guardando = false;

  // Controlador para las observaciones.
  final TextEditingController _observacionesController =
      TextEditingController();

  // Indica si el formulario está editando un registro existente.
  bool get _esEdicion => widget.registro != null;

  // Inicializa el flujo y establece los valores iniciales del formulario.
  // Entrada: ninguna.
  // Salida: ninguna; selecciona el vehículo y carga los datos del registro si existe.
  @override
  void initState() {
    super.initState();

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

    if (widget.registro != null) {
      _articuloUid = widget.registro!.articuloUid;
      _cantidad = widget.registro!.cantidad;
      _estado = widget.registro!.estado.toLowerCase();
      _observacionesController.text = widget.registro!.observaciones;
    }
  }

  // Libera el controlador y el ViewModel al cerrar el formulario.
  // Entrada: ninguna.
  // Salida: ninguna.
  @override
  void dispose() {
    _observacionesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // Construye el nombre descriptivo de un vehículo.
  // Entrada: vehiculo cuyos datos se combinarán.
  // Salida: número económico, marca, modelo y año en un texto.
  String _nombreVehiculo(VehiculoModel vehiculo) {
    return '${vehiculo.numeroEconomico} · ${vehiculo.marca} '
        '${vehiculo.modelo} ${vehiculo.anio}';
  }

  // Valida y guarda el registro de inventario.
  // Entrada: ninguna; utiliza los valores seleccionados en el formulario.
  // Salida: ninguna; cierra el formulario si se guarda o muestra un error.
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final articuloUid = _articuloUid;
    final vehiculo = _vehiculoSeleccionado;

    if (articuloUid == null || vehiculo == null) return;

    setState(() {
      _guardando = true;
    });

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

    setState(() {
      _guardando = false;
    });

    if (guardado) {
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo guardar el artículo.',
        esError: true,
      );
    }
  }

  // Solicita confirmación y elimina el registro de inventario.
  // Entrada: ninguna; utiliza el registro asociado al formulario.
  // Salida: ninguna; elimina el registro si se confirma y muestra el resultado.
  Future<void> _eliminar() async {
    final registro = widget.registro;
    if (registro == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar artículo'),
          content: const Text(
            '¿Quieres retirar este artículo del inventario del vehículo?',
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

    setState(() {
      _guardando = true;
    });

    final eliminado = await _viewModel.eliminarRegistro(
      vehiculoUid: registro.vehiculoUid,
      articuloUid: registro.articuloUid,
    );

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (eliminado) {
      Navigator.pop(context, true);
    } else {
      _mostrarMensaje(
        _viewModel.mensajeError ?? 'No se pudo eliminar el artículo.',
        esError: true,
      );
    }
  }

  // Muestra un mensaje flotante de éxito o error.
  // Entradas: mensaje que se presentará y esError para indicar el tipo de mensaje.
  // Salida: ninguna; muestra un SnackBar en la pantalla.
  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
      ),
    );
  }

  // Construye la interfaz del formulario y el catálogo de artículos.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets para registrar o editar el inventario.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.cfeGreen,
        foregroundColor: AppTheme.pureWhite,
        title: Text(
          _esEdicion ? 'Editar artículo' : 'Registrar artículo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: widget.vehiculos.isEmpty
              ? const Center(
                  child: Text('No hay vehículos registrados.'),
                )
              : StreamBuilder<List<ArticuloModel>>(
                  stream: _articulosStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'No se pudo cargar el catálogo de artículos.',
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
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

                    return Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _etiqueta('Vehículo'),
                          DropdownButtonFormField<String>(
                            value: _vehiculoSeleccionado?.uid,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.local_shipping_outlined,
                              ),
                            ),
                            items: widget.vehiculos.map((vehiculo) {
                              return DropdownMenuItem<String>(
                                value: vehiculo.uid,
                                child: Text(
                                  _nombreVehiculo(vehiculo),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _esEdicion
                                ? null
                                : (uid) {
                                    if (uid == null) return;

                                    for (final vehiculo
                                        in widget.vehiculos) {
                                      if (vehiculo.uid == uid) {
                                        setState(() {
                                          _vehiculoSeleccionado = vehiculo;
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
                            value: articulos.any(
                              (articulo) => articulo.uid == _articuloUid,
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
                            onChanged: _esEdicion
                                ? null
                                : (valor) {
                                    setState(() {
                                      _articuloUid = valor;
                                    });
                                  },
                            validator: (valor) {
                              if (valor == null || valor.isEmpty) {
                                return 'Selecciona un artículo.';
                              }
                              return null;
                            },
                          ),
                          if (articulos.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'No hay artículos activos en el catálogo.',
                              style: TextStyle(color: AppTheme.errorRed),
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
                                onPressed: _cantidad > 0
                                    ? () => setState(() => _cantidad--)
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
                                onPressed: () =>
                                    setState(() => _cantidad++),
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
                            decoration: const InputDecoration(
                              hintText: 'Agrega detalles si son necesarios',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            onPressed: _guardando || articulos.isEmpty
                                ? null
                                : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.pureWhite,
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
                                : () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                            label: const Text('Cancelar'),
                          ),

                          if (_esEdicion) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _guardando ? null : _eliminar,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorRed,
                                side: const BorderSide(
                                  color: AppTheme.errorRed,
                                ),
                                minimumSize: const Size.fromHeight(52),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar artículo'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // Construye una etiqueta de campo con espaciado y estilo uniforme.
  // Entrada: texto que se mostrará como etiqueta.
  // Salida: un widget de texto con el estilo aplicado.
  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // Construye un botón para aumentar o reducir la cantidad.
  // Entradas: icono que se mostrará y función onPressed, que puede ser null.
  // Salida: un botón con el estilo definido para cambiar la cantidad.
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Icon(icono),
    );
  }

  // Construye una opción para elegir el estado del artículo.
  // Entradas: valor interno del estado y texto que verá el usuario.
  // Salida: un botón que actualiza el estado seleccionado.
  Widget _opcionEstado(String valor, String texto) {
    final seleccionado = _estado == valor;

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _estado = valor;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              seleccionado ? AppTheme.cfeGreen : AppTheme.pureWhite,
          foregroundColor:
              seleccionado ? AppTheme.pureWhite : AppTheme.primaryText,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: Text(texto),
      ),
    );
  }
}