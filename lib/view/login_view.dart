import 'package:flutter/material.dart';
import '../viewmodel/auth_viewmodel.dart';
import '../core/routes/app_routes.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Manejo de validaciones del formulario 
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthViewModel _viewModel = AuthViewModel();
  
  bool _obscurePassword = true;

  // RegEx para validación del formato de correo electrónico
  final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Envío del Formulario con Validación de Credenciales 
  Future<void> _submit() async {
  // Validar los campos antes de consultar Firebase.
  if (!_formKey.currentState!.validate()) {
    return;
  }

  final String correo = _emailController.text.trim();
  final String contrasena = _passwordController.text;

  final String? rol = await _viewModel.login(
    correo,
    contrasena,
  );

  if (!mounted) return;

  if (rol == 'administrador') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inicio de sesión correcto.'),
      ),
    );

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.adminHome,
    );
  } else if (rol == 'operador') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inicio de sesión correcto.'),
      ),
    );

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.operatorHome,
    );
  } else if (rol == 'superusuario') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inicio de sesión correcto.'),
      ),
    );

    // Temporalmente utiliza la pantalla del administrador.
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.adminHome,
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No se pudo iniciar sesión. Verifica tus credenciales y el rol asignado.',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

  // Opción "Olvidé mi contraseña" requerida por FN.1
  void _recoverPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escribe tu correo en el campo superior para enviarte el enlace.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_emailRegExp.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, ingresa un formato de correo electrónico válido.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    bool sent = await _viewModel.sendPasswordReset(email);
    
    if (!mounted) return;

    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Enlace enviado! Revisa tu bandeja de entrada.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al enviar el enlace. Verifica que el correo esté registrado.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey, // Motor de validación activo
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PARQUE VEHICULAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).colorScheme.primary, // Heredado de AppTheme
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Distribución Civac - Zona Morelos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                // Campo Correo Institucional
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Institucional', 
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El correo institucional es obligatorio.';
                    }
                    if (!_emailRegExp.hasMatch(value.trim())) {
                      return 'Introduce un formato de correo válido (ejemplo@dominio.com).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña', 
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es obligatoria.';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                
                // Opción Olvidé mi Contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _recoverPassword,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Botón Ingresar
                ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, child) {
                    return _viewModel.isLoading
                     ? const Center(
                        child: CircularProgressIndicator(),
                      )
                      : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Ingresar'),
                      );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
