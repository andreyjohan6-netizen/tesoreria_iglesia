import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles disponibles en la aplicacion.
enum Rol { admin, tesorero, pastor }

/// Encapsula los permisos derivados de un rol.
class Permisos {
  final Rol rol;
  const Permisos(this.rol);

  bool get esAdmin => rol == Rol.admin;
  bool get esTesorero => rol == Rol.tesorero;
  bool get esPastor => rol == Rol.pastor;

  bool get puedeVer => true;
  bool get puedeExportar => true;

  /// Agregar ingresos / egresos: admin y tesorero.
  bool get puedeIngresarEgresar => rol == Rol.admin || rol == Rol.tesorero;

  /// Finalizar un libro mensual: admin y tesorero.
  bool get puedeFinalizarLibro => rol == Rol.admin || rol == Rol.tesorero;

  /// Anular / editar / eliminar movimientos: solo admin.
  bool get puedeEditarMovimientos => rol == Rol.admin;

  /// Editar configuracion (nombre, logo, folios, moneda): solo admin.
  bool get puedeEditarConfiguracion => rol == Rol.admin;

  /// Administrar usuarios autorizados: solo admin.
  bool get puedeAdministrarUsuarios => rol == Rol.admin;

  String get nombreRol {
    switch (rol) {
      case Rol.admin:
        return 'Administrador';
      case Rol.tesorero:
        return 'Tesorero';
      case Rol.pastor:
        return 'Pastor';
    }
  }
}

/// Resultado de verificar el acceso de un usuario.
class Acceso {
  final bool autorizado;
  final Rol rol;
  const Acceso({required this.autorizado, required this.rol});
}

/// Servicio encargado de resolver el acceso y el rol de un usuario.
class RolService {
  RolService._();

  /// Correo del administrador principal. Siempre tendra rol admin.
  static const String adminEmail = 'andreyjohan6@gmail.com';

  static Rol rolDesdeTexto(String? texto) {
    switch ((texto ?? '').trim().toLowerCase()) {
      case 'admin':
        return Rol.admin;
      case 'tesorero':
        return Rol.tesorero;
      default:
        return Rol.pastor;
    }
  }

  /// Verifica si un correo esta autorizado y con que rol.
  ///
  /// - El admin principal SIEMPRE esta autorizado como admin.
  /// - Si el correo esta en `usuarios_autorizados`, se autoriza con su rol.
  /// - En cualquier otro caso, NO esta autorizado.
  static Future<Acceso> verificarAcceso(String? email) async {
    if (email == null) {
      return const Acceso(autorizado: false, rol: Rol.pastor);
    }
    final correo = email.trim().toLowerCase();

    if (correo == adminEmail) {
      return const Acceso(autorizado: true, rol: Rol.admin);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios_autorizados')
          .doc(correo)
          .get();

      if (doc.exists) {
        return Acceso(
          autorizado: true,
          rol: rolDesdeTexto(doc.data()?['rol']?.toString()),
        );
      }
    } catch (_) {
      // Sin acceso o error de red: no autorizado.
    }

    return const Acceso(autorizado: false, rol: Rol.pastor);
  }


  /// Carga solo el rol (sin bloquear). Se mantiene por compatibilidad.
  static Future<Rol> cargarRol(String? email) async {
    final acceso = await verificarAcceso(email);
    return acceso.rol;
  }
}

/// InheritedWidget que expone los Permisos del usuario actual.
class RolProvider extends InheritedWidget {
  final Permisos permisos;

  const RolProvider({
    super.key,
    required this.permisos,
    required super.child,
  });

  static Permisos of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<RolProvider>();
    return provider?.permisos ?? const Permisos(Rol.pastor);
  }

  @override
  bool updateShouldNotify(RolProvider oldWidget) =>
      oldWidget.permisos.rol != permisos.rol;
}
