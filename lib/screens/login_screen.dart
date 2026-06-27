import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  bool _recordarme = true;
  bool _verContrasena = false;
  String? _error;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    // Validacion de campos vacios antes de llamar a Firebase.
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y tu contrasena');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // setPersistence solo aplica en web; si falla no debe bloquear el login.
      try {
        await FirebaseAuth.instance.setPersistence(
          _recordarme ? Persistence.LOCAL : Persistence.SESSION,
        );
      } catch (_) {}

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      // Exito: el StreamBuilder de authStateChanges se encarga de navegar.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensajeError(e.code));
    } catch (_) {
      setState(() => _error = 'Ocurrio un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Traduce el codigo de error de Firebase a un mensaje claro en espanol.
  String _mensajeError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo no tiene un formato valido';
      case 'user-disabled':
        return 'Esta cuenta esta deshabilitada';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo';
      case 'network-request-failed':
        return 'Sin conexion a internet. Revisa tu red';
      default:
        return 'No se pudo iniciar sesion. Intenta de nuevo';
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.church, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Tesoreria Iglesia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inicia sesion para continuar',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electronico',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_verContrasena,
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _verContrasena ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _verContrasena = !_verContrasena),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _recordarme,
                          activeColor: Colors.indigo,
                          onChanged: (v) => setState(() => _recordarme = v!),
                        ),
                        const Text('Recordarme en este dispositivo'),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _cargando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Iniciar sesion', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}