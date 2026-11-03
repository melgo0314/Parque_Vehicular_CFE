import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';

// Pantalla principal del administrador.
class AdminHomeView extends StatelessWidget {
  // Crea la pantalla principal del administrador.
  // Entrada: key opcional para identificar el widget.
  // Salida: una instancia de AdminHomeView.
  const AdminHomeView({super.key});

  // Obtiene en tiempo real el documento del usuario autenticado.
  // Entrada: ninguna; utiliza el usuario actual de Firebase Authentication.
  // Salida: un flujo con el documento del usuario, o un flujo vacío si no hay sesión.
  Stream<DocumentSnapshot<Map<String, dynamic>>> _obtenerUsuario() {
    final usuarioActual = FirebaseAuth.instance.currentUser;

    if (usuarioActual == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('usuario')
        .doc(usuarioActual.uid)
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
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar la sesión. Intenta nuevamente.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // Construye la pantalla principal con el resumen y las tarjetas de módulos.
  // Entrada: context de la pantalla actual.
  // Salida: el árbol de widgets de la pantalla principal.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tarjetaEstadoParque(context),
                    const SizedBox(height: 20),
                    Text(
                      'Módulos',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final esCelular = constraints.maxWidth < 600;

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: esCelular ? 2 : 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: esCelular ? 1.7 : 2.5,
                          children: [
                            _tarjetaModulo(
                              context,
                              Icons.people_alt_outlined,
                              'Usuarios',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.usuarios,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.directions_car_outlined,
                              'Vehículos',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.vehiculos,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.swap_horiz,
                              'Asignaciones',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.asignaciones,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.local_gas_station_outlined,
                              'Combustible',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.combustible,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.speed_outlined,
                              'Kilometraje',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.kilometraje,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.build_circle_outlined,
                              'Mantenimientos',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.mantenimiento,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.layers_outlined,
                              'Inventario',
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.inventario,
                                );
                              },
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.folder_open_outlined,
                              'Expedientes',
                              () {},
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.analytics_outlined,
                              'Reportes',
                              () {},
                            ),
                            _tarjetaModulo(
                              context,
                              Icons.dns_outlined,
                              'Respaldo de BD',
                              () {},
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye el encabezado con el nombre del administrador y acciones.
  // Entrada: context de la pantalla actual.
  // Salida: un widget con el encabezado y los controles de la pantalla.
  Widget _encabezado(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: AppTheme.cfeGreen,
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: AppTheme.accentText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Parque Vehicular • Distribución Civac',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.pureWhite,
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
                  Icons.notifications_none,
                  color: AppTheme.pureWhite,
                  size: 26,
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
          const SizedBox(height: 24),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _obtenerUsuario(),
            builder: (context, snapshot) {
              var nombreUsuario = 'Administrador';

              if (snapshot.hasError) {
                nombreUsuario = 'No se pudo cargar el nombre';
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final datos = snapshot.data!.data();

                if (datos != null) {
                  final nombre = datos['nombre']?.toString().trim() ?? '';
                  final apellidoP =
                      datos['apellidoP']?.toString().trim() ?? '';
                  final apellidoM =
                      datos['apellidoM']?.toString().trim() ?? '';

                  final nombreCompleto = [
                    nombre,
                    apellidoP,
                    apellidoM,
                  ].where((parte) => parte.isNotEmpty).join(' ');

                  if (nombreCompleto.isNotEmpty) {
                    nombreUsuario = nombreCompleto;
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 136,
                    child: _RolAdministrador(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Construye la tarjeta que resume el estado del parque vehicular.
  // Entrada: context de la pantalla actual.
  // Salida: una tarjeta con indicadores de próximos, vencidos y vehículos en taller.
  Widget _tarjetaEstadoParque(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppTheme.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESTADO DEL PARQUE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.secondaryText,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _indicadorEstado(
                  context,
                  '-',
                  'Próximos',
                  AppTheme.alertOrange,
                ),
                _indicadorEstado(
                  context,
                  '-',
                  'Vencidos',
                  AppTheme.errorRed,
                ),
                _indicadorEstado(
                  context,
                  '-',
                  'En taller',
                  AppTheme.infoBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Construye un indicador con valor, etiqueta y color.
  // Entradas: context, valor a mostrar, etiqueta descriptiva y color del valor.
  // Salida: un widget con el valor y su etiqueta.
  Widget _indicadorEstado(
    BuildContext context,
    String valor,
    String etiqueta,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          valor,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }

  // Construye una tarjeta interactiva para abrir un módulo.
  // Entradas: context, icono, etiqueta y alTocar, acción que se ejecuta al pulsar.
  // Salida: una tarjeta que muestra el módulo y ejecuta su acción al tocarla.
  Widget _tarjetaModulo(
    BuildContext context,
    IconData icono,
    String etiqueta,
    VoidCallback alTocar,
  ) {
    return Card(
      elevation: 0,
      color: AppTheme.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                icono,
                color: AppTheme.cfeGreen,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.bold,
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

// Muestra la etiqueta del rol de administrador.
class _RolAdministrador extends StatelessWidget {
  // Crea la etiqueta del rol de administrador.
  // Entrada: ninguna.
  // Salida: una instancia de _RolAdministrador.
  const _RolAdministrador();

  // Construye el botón desactivado que identifica el rol.
  // Entrada: context de la pantalla actual.
  // Salida: un botón con el icono y el texto del rol.
  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        maximumSize: const Size(136, 48),
        disabledBackgroundColor: AppTheme.pureWhite.withValues(alpha: 0.15),
        disabledForegroundColor: AppTheme.pureWhite,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Administrador',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}