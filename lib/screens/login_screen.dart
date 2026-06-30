import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

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

  // Lee una sola vez el nombre y el logo de la iglesia (configuracion).
  final _configFuture = FirebaseFirestore.instance
      .collection('configuracion')
      .doc('iglesia')
      .get();

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y tu contrasena');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      try {
        await FirebaseAuth.instance.setPersistence(
          _recordarme ? Persistence.LOCAL : Persistence.SESSION,
        );
      } catch (_) {}

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensajeError(e.code));
    } catch (_) {
      setState(() => _error = 'Ocurrio un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.brand, AppColors.brandDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: _configFuture,
                      builder: (context, snap) {
                        String? logo;
                        String nombre = 'Tesoreria Iglesia';
                        if (snap.hasData && snap.data!.exists) {
                          final data = snap.data!.data() as Map<String, dynamic>;
                          logo = data['logo'];
                          nombre = (data['nombre'] ?? 'Tesoreria Iglesia').toString();
                        }
                        return Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4), width: 2),
                                image: logo != null
                                    ? DecorationImage(
                                        image: MemoryImage(base64Decode(logo)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: logo == null
                                  ? const Icon(Icons.church, size: 48, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Text(
                              'Tesorería',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              nombre,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Inicia sesion para continuar',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              labelText: 'Correo electronico',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _passCtrl,
                            obscureText: !_verContrasena,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _cargando ? null : _login(),
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Contrasena',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _verContrasena ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () => setState(() => _verContrasena = !_verContrasena),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Checkbox(
                                value: _recordarme,
                                activeColor: AppColors.brand,
                                onChanged: (v) => setState(() => _recordarme = v!),
                              ),
                              const Expanded(
                                child: Text(
                                  'Recordarme en este dispositivo',
                                  style: TextStyle(color: Colors.black87, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.egreso.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AppColors.egreso.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.egreso, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(_error!, style: const TextStyle(color: AppColors.egreso)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _cargando ? null : _login,
                              child: _cargando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
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
          ),
        ),
      ),
    );
  }
}
