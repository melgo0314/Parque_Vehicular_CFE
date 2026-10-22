import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../viewmodel/auth_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _viewModel = AuthViewModel();

  bool _ocultarContrasena = true;

  final RegExp _emailRegExp = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final rol = await _viewModel.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    String? ruta;

    if (rol == 'administrador' || rol == 'superusuario') {
      ruta = AppRoutes.adminHome;
    } else if (rol == 'operador') {
      ruta = AppRoutes.operatorHome;
    }

    if (ruta == null) {
      _mostrarMensaje(
        'No se pudo iniciar sesión. Verifica tus datos y el rol asignado.',
        esError: true,
      );
      return;
    }

    Navigator.pushReplacementNamed(context, ruta);
  }

  Future<void> _recuperarContrasena() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _mostrarMensaje(
        'Escribe tu correo para enviarte el enlace de recuperación.',
        esError: true,
      );
      return;
    }

    if (!_emailRegExp.hasMatch(email)) {
      _mostrarMensaje(
        'Escribe un correo electrónico válido.',
        esError: true,
      );
      return;
    }

    final enviado = await _viewModel.sendPasswordReset(email);

    if (!mounted) return;

    if (enviado) {
      _mostrarMensaje('Enlace enviado. Revisa tu correo.');
    } else {
      _mostrarMensaje(
        'No se pudo enviar el enlace. Verifica que el correo esté registrado.',
        esError: true,
      );
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? AppTheme.errorRed : AppTheme.cfeGreen,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pearlWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, limites) {
            final margenHorizontal = limites.maxWidth >= 700 ? 48.0 : 20.0;
            final altoMinimo = (limites.maxHeight - 48)
                .clamp(0.0, double.infinity)
                .toDouble();

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: margenHorizontal,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: altoMinimo),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      color: AppTheme.pureWhite,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'PARQUE VEHICULAR',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: AppTheme.cfeGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Distribución Civac - Zona Morelos',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.secondaryText,
                                    ),
                              ),
                              const SizedBox(height: 32),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Correo institucional',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (valor) {
                                  if (valor == null ||
                                      valor.trim().isEmpty) {
                                    return 'El correo es obligatorio.';
                                  }

                                  if (!_emailRegExp.hasMatch(valor.trim())) {
                                    return 'Escribe un correo válido.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _ocultarContrasena,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.password,
                                ],
                                onFieldSubmitted: (_) => _iniciarSesion(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _ocultarContrasena
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    onPressed: () {
                                      setState(() {
                                        _ocultarContrasena =
                                            !_ocultarContrasena;
                                      });
                                    },
                                    icon: Icon(
                                      _ocultarContrasena
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (valor) {
                                  if (valor == null || valor.isEmpty) {
                                    return 'La contraseña es obligatoria.';
                                  }

                                  if (valor.length < 6) {
                                    return 'Debe tener al menos 6 caracteres.';
                                  }

                                  return null;
                                },
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _viewModel.isLoading
                                      ? null
                                      : _recuperarContrasena,
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              ListenableBuilder(
                                listenable: _viewModel,
                                builder: (context, child) {
                                  return SizedBox(
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: _viewModel.isLoading
                                          ? null
                                          : _iniciarSesion,
                                      icon: _viewModel.isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.pureWhite,
                                              ),
                                            )
                                          : const Icon(Icons.login),
                                      label: Text(
                                        _viewModel.isLoading
                                            ? 'Iniciando sesión...'
                                            : 'Iniciar sesión',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
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