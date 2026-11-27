import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pie de pantalla común para volver al inicio correspondiente al rol actual.
class InicioFooter extends StatefulWidget {
  const InicioFooter({super.key});

  @override
  State<InicioFooter> createState() => _InicioFooterState();
}

class _InicioFooterState extends State<InicioFooter> {
  bool _navegando = false;

  Future<void> _irAlInicio() async {
    if (_navegando) return;
    setState(() => _navegando = true);

    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }

      final documento = await FirebaseFirestore.instance
          .collection('usuario')
          .doc(usuario.uid)
          .get();
      final rol = documento.data()?['rol']?.toString().trim().toLowerCase();

      final ruta = switch (rol) {
        'administrador' => '/admin_home',
        'operador' => '/ope_home',
        'superusuario' => '/super_home',
        _ => null,
      };

      if (!mounted) return;

      if (ruta == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo identificar el inicio de tu cuenta.'),
          ),
        );
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(ruta, (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el inicio. Revisa tu conexión.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _navegando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppTheme.pureWhite,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Center(
            child: InkWell(
              onTap: _navegando ? null : _irAlInicio,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _navegando ? Icons.hourglass_top : Icons.home_outlined,
                      color: AppTheme.cfeGreen,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Inicio',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
