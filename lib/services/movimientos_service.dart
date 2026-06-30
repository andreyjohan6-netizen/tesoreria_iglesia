import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio central para registrar movimientos y mantener el saldo
/// siempre consistente. Lo usan el Libro y el Resumen por igual.
class MovimientosService {
  MovimientosService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static int compararMovimientos(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final ma = a.data() as Map<String, dynamic>;
    final mb = b.data() as Map<String, dynamic>;
    final sa = ma['esSaldoAnterior'] == true ? 0 : 1;
    final sb = mb['esSaldoAnterior'] == true ? 0 : 1;
    if (sa != sb) return sa - sb;
    final diaA = (ma['dia'] ?? 0) as int;
    final diaB = (mb['dia'] ?? 0) as int;
    if (diaA != diaB) return diaA.compareTo(diaB);
    final fa = ma['fecha'];
    final fb = mb['fecha'];
    if (fa is Timestamp && fb is Timestamp) return fa.compareTo(fb);
    return 0;
  }

  /// Recalcula el saldo acumulado de todos los movimientos de un mes.
  static Future<void> recalcularSaldos(int mes, int anio) async {
    final snapshot = await _db
        .collection('movimientos')
        .where('mes', isEqualTo: mes)
        .where('anio', isEqualTo: anio)
        .orderBy('fecha')
        .get();

    final docs = [...snapshot.docs]..sort(compararMovimientos);

    double saldo = 0;
    final batch = _db.batch();

    for (final doc in docs) {
      final m = doc.data();
      final esSaldoAnterior = m['esSaldoAnterior'] == true;
      final estado = m['estado'] ?? 'Activo';
      if (esSaldoAnterior) {
        saldo = (m['ingreso'] ?? 0).toDouble();
      } else if (estado == 'Activo') {
        saldo += (m['ingreso'] ?? 0).toDouble() - (m['egreso'] ?? 0).toDouble();
      }
      batch.update(doc.reference, {'saldo': saldo});
    }

    await batch.commit();
  }
  /// Calcula el saldo disponible actual de un mes (saldo anterior + ingresos
  /// activos - egresos activos). Sirve para validar antes de registrar.
  static Future<double> saldoActual(int mes, int anio) async {
    final snap = await _db
        .collection('movimientos')
        .where('mes', isEqualTo: mes)
        .where('anio', isEqualTo: anio)
        .get();

    double saldo = 0;
    for (final doc in snap.docs) {
      final m = doc.data();
      if (m['esSaldoAnterior'] == true) {
        saldo += (m['ingreso'] ?? 0).toDouble();
      } else if ((m['estado'] ?? 'Activo') == 'Activo') {
        saldo += (m['ingreso'] ?? 0).toDouble() - (m['egreso'] ?? 0).toDouble();
      }
    }
    return saldo;
  }

  /// Calcula el siguiente folio continuo (global) para un tipo dado.
  static Future<Map<String, dynamic>> _siguienteFolio(bool esIngreso) async {
    final tipo = esIngreso ? 'ingreso' : 'egreso';

    final config = await _db.collection('configuracion').doc('iglesia').get();
    final folioInicial = esIngreso
        ? ((config.data()?['folioInicialIngreso'] ?? 1) as num).toInt()
        : ((config.data()?['folioInicialEgreso'] ?? 1) as num).toInt();

    final snap = await _db
        .collection('movimientos')
        .where('tipoFolio', isEqualTo: tipo)
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    int folioNumero;
    if (snap.docs.isNotEmpty) {
      final ultimo = (snap.docs.first['folioNumero'] ?? (folioInicial - 1)) as int;
      folioNumero = ultimo + 1;
    } else {
      folioNumero = folioInicial;
    }

    final prefijo = esIngreso ? 'I' : 'E';
    return {
      'folio': '$prefijo-${folioNumero.toString().padLeft(3, '0')}',
      'folioNumero': folioNumero,
    };
  }

  /// Agrega un movimiento con folio continuo y recalcula los saldos del mes.
  static Future<void> agregarMovimiento({
    required bool esIngreso,
    required int dia,
    required String detalle,
    required double monto,
    required int mes,
    required int anio,
  }) async {
    final folioData = await _siguienteFolio(esIngreso);

    await _db.collection('movimientos').add({
      'folio': folioData['folio'],
      'folioNumero': folioData['folioNumero'],
      'tipoFolio': esIngreso ? 'ingreso' : 'egreso',
      'dia': dia,
      'detalle': detalle,
      'ingreso': esIngreso ? monto : null,
      'egreso': esIngreso ? null : monto,
      'saldo': 0,
      'estado': 'Activo',
      'mes': mes,
      'anio': anio,
      'fecha': FieldValue.serverTimestamp(),
    });

    await recalcularSaldos(mes, anio);
  }
}
