import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/permisos.dart';
import 'theme/app_theme.dart';
import 'screens/resumen_screen.dart';
import 'screens/libro_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/configuracion_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TesoreriaApp());
}

class TesoreriaApp extends StatefulWidget {
  const TesoreriaApp({super.key});

  static _TesoreriaAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_TesoreriaAppState>();

  @override
  State<TesoreriaApp> createState() => _TesoreriaAppState();
}

class _TesoreriaAppState extends State<TesoreriaApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tesoreria Iglesia',
      themeMode: _themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Usuario autenticado: verificamos si esta autorizado y su rol.
            return FutureBuilder<Acceso>(
              future: RolService.verificarAcceso(snapshot.data!.email),
              builder: (context, accesoSnapshot) {
                if (accesoSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final acceso = accesoSnapshot.data;
                // Si no se pudo verificar o no esta autorizado, se bloquea.
                if (acceso == null || !acceso.autorizado) {
                  return NoAutorizadoScreen(correo: snapshot.data!.email);
                }
                return RolProvider(
                  permisos: Permisos(acceso.rol),
                  child: const MainScreen(),
                );
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ResumenScreen(),
    const LibroScreen(),
    const ReportesScreen(),
    const ConfiguracionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Resumen'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Libro'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reportes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Configuracion'),
        ],
      ),
    );
  }
}

/// Pantalla mostrada cuando un usuario autenticado NO esta autorizado.
class NoAutorizadoScreen extends StatelessWidget {
  final String? correo;
  const NoAutorizadoScreen({super.key, this.correo});

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
              const Icon(Icons.lock_person, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Acceso no autorizado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (correo != null)
                      Text(
                        correo!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu cuenta no esta autorizada para usar esta aplicacion. '
                      'Pide al administrador que agregue tu correo en la seccion '
                      'de usuarios autorizados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Volver al inicio de sesion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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
