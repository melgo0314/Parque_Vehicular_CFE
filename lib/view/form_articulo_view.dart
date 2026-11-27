import 'package:flutter/material.dart';
import 'package:p_vehicular/core/widgets/inicio_footer.dart';

import '../core/theme/app_theme.dart';
import '../models/articulo_model.dart';
import '../viewmodel/inventario_viewmodel.dart';

class FormArticuloView extends StatefulWidget {
  final ArticuloModel? articulo;

  const FormArticuloView({super.key, this.articulo});

  @override
  State<FormArticuloView> createState() => _FormArticuloViewState();
}

class _FormArticuloViewState extends State<FormArticuloView> {
  final InventarioViewModel _viewModel = InventarioViewModel();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;

  String? _categoria;
  bool _activo = true;
  bool _guardando = false;

  bool get _esEdicion => widget.articulo != null;

  final List<Map<String, String>> _categorias = const [
    {'valor': 'herramienta', 'texto': 'Herramienta'},
    {'valor': 'accesorio', 'texto': 'Accesorio'},
    {'valor': 'equipo_auxilio', 'texto': 'Equipo de auxilio'},
    {'valor': 'kit_seguridad', 'texto': 'Kit de seguridad'},
  ];

  @override
  void initState() {
    super.initState();

    _nombreController = TextEditingController(
      text: widget.articulo?.nombre ?? '',
    );
    _categoria = widget.articulo?.categoria;
    _activo = widget.articulo?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
    });

    final articulo = ArticuloModel(
      uid: widget.articulo?.uid ?? '',
      nombre: _nombreController.text.trim(),
      categoria: _categoria!,
      activo: _activo,
    );

    final resultado = _esEdicion
        ? await _viewModel.actualizarArticulo(articulo)
        : await _viewModel.registrarArticulo(articulo);

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    if (resultado) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _viewModel.mensajeError ?? 'No se pudo guardar el artículo.',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
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
          _esEdicion ? 'Editar artículo' : 'Agregar artículo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Nombre del artículo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Extintor',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Escribe el nombre del artículo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Categoría',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categorias.map((categoria) {
                    return DropdownMenuItem<String>(
                      value: categoria['valor'],
                      child: Text(categoria['texto']!),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    setState(() {
                      _categoria = valor;
                    });
                  },
                  validator: (valor) {
                    if (valor == null || valor.isEmpty) {
                      return 'Selecciona una categoría.';
                    }
                    return null;
                  },
                ),
                if (_esEdicion) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Artículo activo'),
                    subtitle: const Text(
                      'Si lo desactivas, no aparecerá en nuevos checklists.',
                    ),
                    value: _activo,
                    onChanged: (valor) {
                      setState(() {
                        _activo = valor;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
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
                    _esEdicion ? 'Guardar cambios' : 'Guardar artículo',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
