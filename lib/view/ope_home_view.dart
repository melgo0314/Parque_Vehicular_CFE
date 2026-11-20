
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';
import '../viewmodel/notificacion_viewmodel.dart';
import 'form_vehiculo_view.dart';

class OpeHomeView extends StatefulWidget {
  const OpeHomeView({super.key});

  @override
  State<OpeHomeView> createState() => _OpeHomeViewState();
}

class _OpeHomeViewState extends State<OpeHomeView> {
  final NotificacionViewmodel _notificacionViewmodel =
      NotificacionViewmodel();

  @override
  void initState() {
    super.initState();

    _notificacionViewmodel.addListener(_actualizarContador);
    _notificacionViewmodel.obtenerNotificaciones();
  }

  @override
  void dispose() {
    _notificacionViewmodel.removeListener(_actualizarContador);
    _notificacionViewmodel.dispose();

    super.dispose();
  }

  void _actualizarContador() {
    if (!mounted) return;

    setState(() {});
  }

  void _abrirNotificaciones(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.notificaciones,
    ).then((_) {
      if (mounted) {
        _notificacionViewmodel.obtenerNotificaciones();
      }
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _obtenerUsuario() {
    final usuarioActual = FirebaseAuth.instance.currentUser;

    if (usuarioActual == null) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('usuario')
        .doc(usuarioActual.uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _obtenerVehiculoAsignado() {
    final usuarioActual = FirebaseAuth.instance.currentUser;

    if (usuarioActual == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('vehiculo')
        .where('operadorUidActual', isEqualTo: usuarioActual.uid)
        .limit(2)
        .snapshots();
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar la sesión. Intenta nuevamente.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _obtenerVehiculoAsignado(),
                builder: (context, snapshot) {
                  VehiculoModel? vehiculo;
                  String? mensajeUnidad;

                  if (snapshot.hasError) {
                    mensajeUnidad =
                        'No se pudo consultar tu unidad. Intenta de nuevo.';
                  } else if (snapshot.hasData) {
                    final documentos = snapshot.data!.docs;

                    if (documentos.length == 1) {
                      final documento = documentos.first;
                      vehiculo = VehiculoModel.fromMap(
                        documento.data(),
                        documento.id,
                      );
                    } else if (documentos.isEmpty) {
                      mensajeUnidad =
                          'Aún no tienes un vehículo asignado. '
                          'Solicita al administrador que registre la asignación.';
                    } else {
                      mensajeUnidad =
                          'Hay más de un vehículo asignado a tu cuenta. '
                          'Contacta al administrador para corregirlo.';
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vehiculo != null)
                          _tarjetaUnidadAsignada(context, vehiculo)
                        else if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasError)
                          _tarjetaCargandoUnidad()
                        else
                          _tarjetaMensajeUnidad(
                            mensajeUnidad ?? 'No hay una unidad disponible.',
                            icono: Icons.local_shipping_outlined,
                          ),
                        const SizedBox(height: 16),
                        _accionesRapidas(
                          context,
                          vehiculo: vehiculo,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Módulos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _modulos(
                          context,
                          vehiculo: vehiculo,
                        ),
                      ],
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

  Widget _encabezado(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.cfeGreen,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: AppTheme.accentText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Parque Vehicular • Civac',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Campanita con contador de notificaciones no leídas.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notificaciones',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(
                      Icons.notifications_none,
                      color: AppTheme.pureWhite,
                      size: 26,
                    ),
                    onPressed: () => _abrirNotificaciones(context),
                  ),

                  if (_notificacionViewmodel.totalNoLeidas > 0)
                    Positioned(
                      right: 5,
                      top: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.pureWhite,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _notificacionViewmodel.totalNoLeidas > 99
                              ? '99+'
                              : '${_notificacionViewmodel.totalNoLeidas}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.pureWhite,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              IconButton(
                tooltip: 'Cerrar sesión',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                icon: const Icon(
                  Icons.logout,
                  color: AppTheme.pureWhite,
                  size: 24,
                ),
                onPressed: () => _cerrarSesion(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _obtenerUsuario(),
            builder: (context, snapshot) {
              var nombreUsuario = 'Usuario';

              if (snapshot.hasData && snapshot.data!.exists) {
                final datos = snapshot.data!.data();

                if (datos != null) {
                  nombreUsuario =
                      '${datos['nombre'] ?? ''} ${datos['apellidoP'] ?? ''}'
                          .trim();

                  if (nombreUsuario.isEmpty) {
                    nombreUsuario = 'Usuario';
                  }
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      nombreUsuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.pureWhite,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.pureWhite.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: AppTheme.pureWhite,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Operador',
                          style: TextStyle(
                            color: AppTheme.pureWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tarjetaUnidadAsignada(
    BuildContext context,
    VehiculoModel vehiculo,
  ) {
    final descripcion =
        '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}'.trim();

    return Card(
      color: AppTheme.pureWhite,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormVehiculoView(
                vehiculo: vehiculo,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MI UNIDAD ASIGNADA',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.secondaryText,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.avatarSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: AppTheme.cfeGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          descripcion.isEmpty ? 'Vehículo' : descripcion,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehiculo.placas} • ${vehiculo.numeroEconomico}',
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.speed,
                    color: AppTheme.secondaryText,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${vehiculo.kilometrajeActual} km',
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    vehiculo.estadoOperativo,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Toca aquí para editar la información de tu unidad.',
                style: TextStyle(
                  color: AppTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaMensajeUnidad(
    String mensaje, {
    required IconData icono,
  }) {
    return Card(
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icono, color: AppTheme.secondaryText, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: AppTheme.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaCargandoUnidad() {
    return Card(
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.cfeGreen,
          ),
        ),
      ),
    );
  }

  Widget _accionesRapidas(
    BuildContext context, {
    required VehiculoModel? vehiculo,
  }) {
    final habilitadas = vehiculo != null;

    return Row(
      children: [
        Expanded(
          child: _botonAccionRapida(
            etiqueta: 'Registrar combustible',
            icono: Icons.local_gas_station,
            color: AppTheme.accentYellow,
            colorTexto: AppTheme.accentText,
            habilitado: habilitadas,
            alTocar: () {
              Navigator.pushNamed(
                context,
                AppRoutes.combustible,
                arguments: vehiculo,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _botonAccionRapida(
            etiqueta: 'Registrar km',
            icono: Icons.speed,
            color: AppTheme.cfeGreen,
            colorTexto: AppTheme.pureWhite,
            habilitado: habilitadas,
            alTocar: () {
              Navigator.pushNamed(
                context,
                AppRoutes.kilometraje,
                arguments: vehiculo,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _botonAccionRapida({
    required String etiqueta,
    required IconData icono,
    required Color color,
    required Color colorTexto,
    required bool habilitado,
    required VoidCallback alTocar,
  }) {
    return Material(
      color: habilitado ? color : AppTheme.border,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: habilitado ? alTocar : null,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 90,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  color: habilitado ? colorTexto : AppTheme.secondaryText,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: habilitado ? colorTexto : AppTheme.secondaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modulos(
    BuildContext context, {
    required VehiculoModel? vehiculo,
  }) {
    final habilitados = vehiculo != null;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _tarjetaModulo(
          'Mantenimientos',
          Icons.build_circle_outlined,
          habilitado: habilitados,
          alTocar: () {
            Navigator.pushNamed(
              context,
              AppRoutes.mantenimiento,
              arguments: vehiculo,
            );
          },
        ),
        _tarjetaModulo(
          'Inventario',
          Icons.inventory_2_outlined,
          habilitado: habilitados,
          alTocar: () {
            Navigator.pushNamed(
              context,
              AppRoutes.inventario,
              arguments: vehiculo,
            );
          },
        ),
        _tarjetaModulo(
          'Expedientes',
          Icons.folder_open_outlined,
          habilitado: habilitados,
          alTocar: () {
            Navigator.pushNamed(
              context,
              AppRoutes.expediente,
              arguments: vehiculo,
            );
          },
        ),
      ],
    );
  }

  Widget _tarjetaModulo(
    String titulo,
    IconData icono, {
    required bool habilitado,
    required VoidCallback alTocar,
  }) {
    return Material(
      color: habilitado ? AppTheme.pureWhite : AppTheme.border,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: habilitado ? alTocar : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: const Border.fromBorderSide(
              BorderSide(color: AppTheme.border),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                color: habilitado
                    ? AppTheme.cfeGreen
                    : AppTheme.secondaryText,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: habilitado
                        ? AppTheme.primaryText
                        : AppTheme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
