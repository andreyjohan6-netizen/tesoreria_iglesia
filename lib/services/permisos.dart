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

/// Servicio encargado de resolver el rol de un usuario.
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

  /// Carga el rol del usuario a partir de su correo.
  static Future<Rol> cargarRol(String? email) async {
    if (email == null) return Rol.pastor;
    final correo = email.trim().toLowerCase();

    if (correo == adminEmail) return Rol.admin;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios_autorizados')
          .where('email', isEqualTo: correo)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return rolDesdeTexto(snap.docs.first.data()['rol']?.toString());
      }
    } catch (_) {
      // Ante un error de red, devolvemos el rol mas restrictivo.
    }
    return Rol.pastor;
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
