import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:html' as html;
import '../main.dart';
import '../services/permisos.dart';
import '../theme/app_theme.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _nombreCtrl = TextEditingController();
  final _folioIngresoCtrl = TextEditingController();
  final _folioEgresoCtrl = TextEditingController();
  String _moneda = 'CLP';
  final List<String> _monedas = ['CLP', 'USD', 'EUR', 'ARS', 'MXN'];
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _logoBase64;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    final doc = await _db.collection('configuracion').doc('iglesia').get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nombreCtrl.text = data['nombre'] ?? 'Iglesia Eben-Ezer';
        _moneda = data['moneda'] ?? 'CLP';
        _folioIngresoCtrl.text = (data['folioInicialIngreso'] ?? 1).toString();
        _folioEgresoCtrl.text = (data['folioInicialEgreso'] ?? 1).toString();
        _logoBase64 = data['logo'];
        _cargando = false;
      });
    } else {
      setState(() {
        _nombreCtrl.text = 'Iglesia Eben-Ezer';
        _folioIngresoCtrl.text = '1';
        _folioEgresoCtrl.text = '1';
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    await _db.collection('configuracion').doc('iglesia').set({
      'nombre': _nombreCtrl.text,
      'moneda': _moneda,
      'folioInicialIngreso': int.tryParse(_folioIngresoCtrl.text) ?? 1,
      'folioInicialEgreso': int.tryParse(_folioEgresoCtrl.text) ?? 1,
      'logo': _logoBase64,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuracion guardada correctamente'),
        backgroundColor: AppColors.ingreso,
      ),
    );
  }

  void _subirLogo() {
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoad.listen((event) {
        final dataUrl = reader.result as String;
        final base64String = dataUrl.split(',').last;
        setState(() {
          _logoBase64 = base64String;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo cargado. Presiona Guardar para aplicar.'),
            backgroundColor: AppColors.brand,
          ),
        );
      });
    });
  }

  void _cambiarContrasena() {
    final passActualCtrl = TextEditingController();
    final passNuevaCtrl = TextEditingController();
    final passConfirmarCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contrasena'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passActualCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contrasena actual'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passNuevaCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contrasena'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passConfirmarCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar contrasena'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passNuevaCtrl.text != passConfirmarCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contrasenas no coinciden'),
                    backgroundColor: AppColors.egreso,
                  ),
                );
                return;
              }
              try {
                final user = _auth.currentUser!;
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passActualCtrl.text,
                );
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(passNuevaCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contrasena cambiada correctamente'),
                    backgroundColor: AppColors.ingreso,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contrasena actual incorrecta'),
                    backgroundColor: AppColors.egreso,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _administrarUsuarios() {
    final emailCtrl = TextEditingController();
    String rolSeleccionado = 'pastor';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Usuarios autorizados'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo del usuario'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: rolSeleccionado,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Administrador (todo)')),
                    DropdownMenuItem(value: 'tesorero', child: Text('Tesorero (registra, no edita)')),
                    DropdownMenuItem(value: 'pastor', child: Text('Pastor (solo ver y exportar)')),
                  ],
                  onChanged: (v) => setDialogState(() => rolSeleccionado = v ?? 'pastor'),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final correo = emailCtrl.text.trim().toLowerCase();
                      if (correo.isEmpty || !correo.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ingresa un correo valido'), backgroundColor: AppColors.egreso),
                        );
                        return;
                      }
                      // El documento se identifica por el correo (para las reglas por rol).
                      await _db.collection('usuarios_autorizados').doc(correo).set({
                        'email': correo,
                        'rol': rolSeleccionado,
                        'fecha': FieldValue.serverTimestamp(),
                      });
                      emailCtrl.clear();

                      setDialogState(() => rolSeleccionado = 'pastor');
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Agregar / Actualizar'),
                  ),
                ),
                const Divider(height: AppSpacing.xl),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('usuarios_autorizados').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Text('No hay usuarios autorizados'),
                      );
                    }
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rolTxt = (data['rol'] ?? 'pastor').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person, color: AppColors.brand),
                          title: Text(data['email'] ?? ''),
                          subtitle: Text('Rol: $rolTxt'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.egreso),
                            onPressed: () => doc.reference.delete(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permisos = RolProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: permisos.puedeEditarConfiguracion ? _subirLogo : null,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brand, width: 2),
                      ),
                      child: _logoBase64 != null
                          ? ClipOval(
                              child: Image.memory(base64Decode(_logoBase64!), fit: BoxFit.cover),
                            )
                          : const Icon(Icons.church, size: 48, color: AppColors.brand),
                    ),
                  ),
                  if (permisos.puedeEditarConfiguracion) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: _subirLogo,
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Cambiar logo'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Sesion / rol actual
            _tarjeta(
              cardColor,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                    child: const Icon(Icons.badge, color: AppColors.brand),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_auth.currentUser?.email ?? 'Sesion iniciada',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Rol: ${permisos.nombreRol}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (permisos.puedeEditarConfiguracion) ...[
              _seccion('Datos de la Iglesia', textColor),
              _campo(
                label: 'Nombre de la iglesia',
                child: TextField(controller: _nombreCtrl, style: TextStyle(color: textColor)),
              ),
              const SizedBox(height: AppSpacing.md),
              _campo(
                label: 'Moneda',
                child: DropdownButtonFormField<String>(
                  value: _moneda,
                  items: _monedas.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _moneda = v!),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _seccion('Configuracion de Folios', textColor),
              _campo(
                label: 'Folio inicial de Ingresos',
                child: TextField(
                  controller: _folioIngresoCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(prefixText: 'I-', hintText: 'Ejemplo: 1'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _campo(
                label: 'Folio inicial de Egresos',
                child: TextField(
                  controller: _folioEgresoCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(prefixText: 'E-', hintText: 'Ejemplo: 1'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            _seccion('Apariencia', textColor),
            _tarjeta(
              cardColor,
              child: Row(
                children: [
                  const Icon(Icons.dark_mode, color: AppColors.brand),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Modo oscuro', style: TextStyle(color: textColor))),
                  Switch(
                    value: isDark,
                    onChanged: (value) => TesoreriaApp.of(context)?.toggleTheme(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            _seccion('Seguridad', textColor),
            _botonOpcion(
              icono: Icons.lock,
              texto: 'Cambiar contrasena',
              cardColor: cardColor,
              textColor: textColor,
              onTap: _cambiarContrasena,
            ),
            if (permisos.puedeAdministrarUsuarios) ...[
              const SizedBox(height: AppSpacing.sm),
              _botonOpcion(
                icono: Icons.people,
                texto: 'Administrar usuarios autorizados',
                cardColor: cardColor,
                textColor: textColor,
                onTap: _administrarUsuarios,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            if (permisos.puedeEditarConfiguracion)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.egreso,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(Color cardColor, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _seccion(String titulo, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _campo({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }

  Widget _botonOpcion({
    required IconData icono,
    required String texto,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Icon(icono, color: AppColors.brand),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(texto, style: TextStyle(color: textColor))),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
