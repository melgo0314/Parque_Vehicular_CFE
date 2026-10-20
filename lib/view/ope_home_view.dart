import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_theme.dart';

class OpeHomeView extends StatelessWidget {
  const OpeHomeView({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tarjetaUnidadAsignada(),
                    const SizedBox(height: 16),
                    _accionesRapidas(),
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
                    _modulos(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
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
                  style: TextStyle(
                    color: AppTheme.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Stack(
                children: [
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
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: AppTheme.errorRed,
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: AppTheme.pureWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Buen día,',
            style: TextStyle(
              color: AppTheme.pureWhite.withValues(alpha: 0.85),
              fontSize: 15,
            ),
          ),
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

  Widget _tarjetaUnidadAsignada() {
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ford Ranger 2020',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'MRL-517-B • CIV-02',
                        style: TextStyle(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppTheme.warningText,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Servicio próximo',
                        style: TextStyle(
                          color: AppTheme.warningText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.speed,
                        color: AppTheme.secondaryText,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '71,905 km',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 12),
            const Text(
              'Próximo servicio a los 72,500 km · faltan 595 km',
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accionesRapidas() {
    return Row(
      children: [
        Expanded(
          child: _botonAccionRapida(
            etiqueta: 'Cargar combustible',
            icono: Icons.local_gas_station,
            color: AppTheme.accentYellow,
            colorTexto: AppTheme.accentText,
            alTocar: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _botonAccionRapida(
            etiqueta: 'Registrar km',
            icono: Icons.speed,
            color: AppTheme.cfeGreen,
            colorTexto: AppTheme.pureWhite,
            alTocar: () {},
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
    required VoidCallback alTocar,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 90,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: colorTexto, size: 28),
                const SizedBox(height: 8),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorTexto,
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

  Widget _modulos() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _tarjetaModulo('Vehículos', Icons.local_shipping_outlined, () {}),
        _tarjetaModulo('Combustible', Icons.local_gas_station_outlined, () {}),
        _tarjetaModulo('Kilometraje', Icons.speed_outlined, () {}),
        _tarjetaModulo('Mantenimientos', Icons.build_circle_outlined, () {}),
        _tarjetaModulo('Inventario', Icons.inventory_2_outlined, () {}),
        _tarjetaModulo('Expedientes', Icons.folder_open_outlined, () {}),
      ],
    );
  }

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