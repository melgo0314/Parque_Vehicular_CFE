import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:p_vehicular/core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../models/vehiculos_model.dart';

// Pantalla principal para usuarios con rol de operador.
class OpeHomeView extends StatelessWidget {
  // Crea la pantalla principal del operador.
  // Entrada: key opcional para identificar el widget.
  // Salida: una instancia de OpeHomeView.
  const OpeHomeView({super.key});

  // Obtiene en tiempo real el documento del usuario autenticado.
  // Entrada: ninguna; utiliza la sesión actual de Firebase Authentication.
  // Salida: flujo con el documento del usuario o vacío si no hay sesión.
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

  // Obtiene los vehículos asignados al usuario autenticado.
  // Entrada: ninguna; utiliza el identificador del usuario actual.
  // Salida: flujo con los vehículos asignados o vacío si no hay sesión.
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

  // Cierra la sesión y redirige a la pantalla de inicio de sesión.
  // Entrada: context de la pantalla actual.
  // Salida: ninguna; navega al inicio de sesión o muestra un mensaje si falla.
  Future<void> _logout(BuildContext context) async {
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

  // Construye la pantalla con la unidad asignada, acciones y módulos.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets de la pantalla principal del operador.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _obtenerVehiculoAsignado(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _tarjetaMensajeUnidad(
                            'No se pudo consultar tu unidad. Intenta de nuevo.',
                            icono: Icons.error_outline,
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return _tarjetaCargandoUnidad();
                        }

                        final documentos = snapshot.data?.docs ?? [];

                        if (documentos.isEmpty) {
                          return _tarjetaMensajeUnidad(
                            'Aún no tienes un vehículo asignado. '
                            'Solicita al administrador que registre la asignación.',
                            icono: Icons.local_shipping_outlined,
                          );
                        }

                        if (documentos.length > 1) {
                          return _tarjetaMensajeUnidad(
                            'Hay más de un vehículo asignado a tu cuenta. '
                            'Contacta al administrador para corregirlo.',
                            icono: Icons.warning_amber_outlined,
                          );
                        }

                        final documento = documentos.first;
                        final vehiculo = VehiculoModel.fromMap(
                          documento.data(),
                          documento.id,
                        );

                        return _tarjetaUnidadAsignada(vehiculo);
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _obtenerVehiculoAsignado(),
                      builder: (context, snapshot) {
                        final tieneVehiculo =
                            snapshot.hasData && snapshot.data!.docs.length == 1;

                        return _accionesRapidas(
                          context,
                          habilitadas: tieneVehiculo,
                        );
                      },
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
                    _modulos(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye el encabezado con el nombre y el rol del usuario.
  // Entrada: context de la pantalla actual.
  // Salida: un widget con identidad del sistema, notificaciones y cierre de sesión.
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
              IconButton(
                tooltip: 'Notificaciones',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: AppTheme.pureWhite,
                  size: 28,
                ),
                onPressed: () {},
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
                onPressed: () => _logout(context),
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

  // Construye la tarjeta con los datos del vehículo asignado.
  // Entrada: vehiculo cuyos datos se mostrarán.
  // Salida: tarjeta con descripción, placas, número económico y kilometraje.
  Widget _tarjetaUnidadAsignada(VehiculoModel vehiculo) {
    final descripcion =
        '${vehiculo.marca} ${vehiculo.modelo} ${vehiculo.anio}'.trim();

    return Card(
      color: AppTheme.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MI UNIDAD ASIGNADA',
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
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
          ],
        ),
      ),
    );
  }

  // Construye una tarjeta para informar el estado de la unidad.
  // Entradas: mensaje que se presentará e icono que lo acompañará.
  // Salida: una tarjeta con el mensaje indicado.
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
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye la tarjeta que se muestra mientras se consulta la unidad.
  // Entrada: ninguna.
  // Salida: una tarjeta con un indicador de progreso.
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
          child: CircularProgressIndicator(color: AppTheme.cfeGreen),
        ),
      ),
    );
  }

  // Construye las acciones rápidas para registrar combustible o kilometraje.
  // Entradas: context de navegación y habilitadas según la asignación del vehículo.
  // Salida: una fila con los botones de acción rápida.
  Widget _accionesRapidas(
    BuildContext context, {
    required bool habilitadas,
  }) {
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
              Navigator.pushNamed(context, AppRoutes.combustible);
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
              Navigator.pushNamed(context, AppRoutes.kilometraje);
            },
          ),
        ),
      ],
    );
  }

  // Construye un botón de acción rápida con su estilo y comportamiento.
  // Entradas: etiqueta, icono, colores, estado habilitado y función alTocar.
  // Salida: un botón táctil para ejecutar la acción indicada.
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

  // Construye la cuadrícula de módulos disponibles para el operador.
  // Entrada: context de navegación.
  // Salida: cuadrícula con accesos a vehículos, mantenimientos e información.
  Widget _modulos(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _tarjetaModulo(
          'Vehículos',
          Icons.local_shipping_outlined,
          () => Navigator.pushNamed(context, AppRoutes.vehiculos),
        ),
        _tarjetaModulo(
          'Mantenimientos',
          Icons.build_circle_outlined,
          () => Navigator.pushNamed(context, AppRoutes.mantenimiento),
        ),
        _tarjetaModulo(
          'Inventario',
          Icons.inventory_2_outlined,
          () => Navigator.pushNamed(context, AppRoutes.inventario),
        ),
        _tarjetaModulo(
          'Expedientes',
          Icons.folder_open_outlined,
          () {},
        ),
      ],
    );
  }

  // Construye una tarjeta de acceso a un módulo.
  // Entradas: titulo del módulo, icono y función alTocar.
  // Salida: una tarjeta que ejecuta la acción indicada al tocarla.
  Widget _tarjetaModulo(
    String titulo,
    IconData icono,
    VoidCallback alTocar,
  ) {
    return Material(
      color: AppTheme.pureWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: alTocar,
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
              Icon(icono, color: AppTheme.cfeGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primaryText,
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