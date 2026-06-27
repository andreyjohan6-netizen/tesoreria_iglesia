import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:html' as html;
import '../main.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuracion guardada correctamente'),
        backgroundColor: Colors.green,
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
            backgroundColor: Colors.indigo,
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
              decoration: const InputDecoration(
                labelText: 'Contrasena actual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passNuevaCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contrasena',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passConfirmarCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contrasena',
                border: OutlineInputBorder(),
              ),
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
                    backgroundColor: Colors.red,
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
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contrasena actual incorrecta'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _administrarUsuarios() {
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuarios autorizados'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Correo del usuario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (emailCtrl.text.isEmpty) return;
                      await _db.collection('usuarios_autorizados').add({
                        'email': emailCtrl.text.trim(),
                        'fecha': FieldValue.serverTimestamp(),
                      });
                      emailCtrl.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Agregar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _db.collection('usuarios_autorizados').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No hay usuarios autorizados');
                  }
                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.indigo),
                        title: Text(data['email'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : const Color(0xFFF5F5F5);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Configuracion', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _subirLogo,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.indigo, width: 2),
                      ),
                      child: _logoBase64 != null
                          ? ClipOval(
                              child: Image.memory(
                                base64Decode(_logoBase64!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.church, size: 50, color: Colors.indigo),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _subirLogo,
                    icon: const Icon(Icons.upload),
                    label: const Text('Cambiar logo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _seccion('Datos de la Iglesia', textColor),
            _campo(
              label: 'Nombre de la iglesia',
              child: TextField(
                controller: _nombreCtrl,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _campo(
              label: 'Moneda',
              child: DropdownButtonFormField<String>(
                value: _moneda,
                dropdownColor: cardColor,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _monedas.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _moneda = v!),
              ),
            ),
            const SizedBox(height: 24),

            _seccion('Configuracion de Folios', textColor),
            _campo(
              label: 'Folio inicial de Ingresos',
              child: TextField(
                controller: _folioIngresoCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Ejemplo: 1',
                  prefixText: 'I-',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _campo(
              label: 'Folio inicial de Egresos',
              child: TextField(
                controller: _folioEgresoCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Ejemplo: 1',
                  prefixText: 'E-',
                ),
              ),
            ),
            const SizedBox(height: 24),

            _seccion('Apariencia', textColor),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.dark_mode, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Modo oscuro', style: TextStyle(color: textColor))),
                  Switch(
                    value: isDark,
                    activeColor: Colors.indigo,
                    onChanged: (value) {
                      TesoreriaApp.of(context)?.toggleTheme(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _seccion('Seguridad', textColor),
            _botonOpcion(
              icono: Icons.lock,
              texto: 'Cambiar contrasena',
              color: Colors.indigo,
              cardColor: cardColor,
              textColor: textColor,
              onTap: _cambiarContrasena,
            ),
            const SizedBox(height: 8),
            _botonOpcion(
              icono: Icons.people,
              texto: 'Administrar usuarios autorizados',
              color: Colors.indigo,
              cardColor: cardColor,
              textColor: textColor,
              onTap: _administrarUsuarios,
            ),
            const SizedBox(height: 24),

            _seccion('Plan actual', textColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan Gratuito', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text('Funciones basicas activas', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Planes de pago - Proximamente')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mejorar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _campo({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _botonOpcion({
    required IconData icono,
    required String texto,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(icono, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: TextStyle(color: textColor))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}