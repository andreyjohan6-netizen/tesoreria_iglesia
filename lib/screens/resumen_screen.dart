import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/permisos.dart';
import '../services/movimientos_service.dart';


class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  final _db = FirebaseFirestore.instance;
  int _mes = DateTime.now().month;
  int _anio = DateTime.now().year;
  bool _libroFinalizado = false;

  final List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _cargarMesActivo();
  }

  Future<void> _cargarMesActivo() async {
    final ahora = DateTime.now();
    int mes = ahora.month;
    int anio = ahora.year;

    final finalizado = await _db
        .collection('libros_finalizados')
        .where('mes', isEqualTo: mes)
        .where('anio', isEqualTo: anio)
        .get();

    if (finalizado.docs.isEmpty) {
      setState(() {
        _mes = mes;
        _anio = anio;
        _libroFinalizado = false;
      });
    } else {
      int mesSiguiente = mes == 12 ? 1 : mes + 1;
      int anioSiguiente = mes == 12 ? anio + 1 : anio;
      setState(() {
        _mes = mesSiguiente;
        _anio = anioSiguiente;
        _libroFinalizado = false;
      });
    }

    await _verificarLibroFinalizado();
  }

  Future<void> _verificarLibroFinalizado() async {
    final snapshot = await _db
        .collection('libros_finalizados')
        .where('mes', isEqualTo: _mes)
        .where('anio', isEqualTo: _anio)
        .get();
    setState(() {
      _libroFinalizado = snapshot.docs.isNotEmpty;
    });
  }

  String _formatear(double valor) {
    return '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
  }

  void _mostrarLibroFinalizado() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('El libro de ${_meses[_mes - 1]} ya ha sido finalizado'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarFormulario({bool esIngreso = true}) {
    if (_libroFinalizado) {
      _mostrarLibroFinalizado();
      return;
    }

    final detalleCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final diaCtrl = TextEditingController();
    final maxDias = DateTime(_anio, _mes + 1, 0).day;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esIngreso ? 'Nuevo Ingreso' : 'Nuevo Egreso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: diaCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Dia (1 - $maxDias)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detalleCtrl,
              decoration: const InputDecoration(labelText: 'Detalle', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
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
              final dia = int.tryParse(diaCtrl.text) ?? 0;
              if (dia < 1 || dia > maxDias) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('El dia debe estar entre 1 y $maxDias'), backgroundColor: Colors.red),
                );
                return;
              }
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              if (monto <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El monto debe ser mayor a 0'), backgroundColor: Colors.red),
                );
                return;
              }
              if (detalleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El detalle no puede estar vacio'), backgroundColor: Colors.red),
                );
                return;
              }

              await MovimientosService.agregarMovimiento(
                esIngreso: esIngreso,
                dia: dia,
                detalle: detalleCtrl.text.trim(),
                monto: monto,
                mes: _mes,
                anio: _anio,
              );

              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: esIngreso ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final permisos = RolProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : const Color(0xFFF5F5F5);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('configuracion').doc('iglesia').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final logo = data['logo'];
              final nombre = data['nombre'] ?? 'Tesoreria Iglesia';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logo != null)
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: MemoryImage(base64Decode(logo)),
                    )
                  else
                    const Icon(Icons.church, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }
            return const Text('Tesoreria Iglesia', style: TextStyle(color: Colors.white));
          },
        ),
        centerTitle: true,
        actions: [
          if (_libroFinalizado)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text('Finalizado', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('movimientos')
            .where('mes', isEqualTo: _mes)
            .where('anio', isEqualTo: _anio)
            .orderBy('fecha')
            .snapshots(),
        builder: (context, snapshot) {
          double ingresos = 0;
          double egresos = 0;
          double saldo = 0;
          List<QueryDocumentSnapshot> ultimos = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final docs = snapshot.data!.docs;
            double saldoAnterior = 0;
            for (var doc in docs) {
              final m = doc.data() as Map<String, dynamic>;
              if (m['esSaldoAnterior'] == true) {
                saldoAnterior = (m['ingreso'] ?? 0).toDouble();
              } else if (m['estado'] == 'Activo') {
                if (m['ingreso'] != null) ingresos += m['ingreso'].toDouble();
                if (m['egreso'] != null) egresos += m['egreso'].toDouble();
              }
            }
            saldo = saldoAnterior + ingresos - egresos;

            ultimos = docs.reversed.take(5).toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_libroFinalizado)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'El libro de ${_meses[_mes - 1]} ya ha sido finalizado',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Mes activo: ${_meses[_mes - 1]} $_anio',
                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('Saldo Actual', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        _formatear(saldo),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ingresos', style: TextStyle(color: Colors.green, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(_formatear(ingresos),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Egresos', style: TextStyle(color: Colors.red, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(_formatear(egresos),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Ultimos movimientos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),

                if (ultimos.isEmpty)
                  Text('No hay movimientos este mes',
                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)),

                ...ultimos.map((doc) {
                  final m = doc.data() as Map<String, dynamic>;
                  if (m['esSaldoAnterior'] == true) return const SizedBox.shrink();
                  final esIngreso = m['ingreso'] != null;
                  final monto = esIngreso ? m['ingreso'].toDouble() : m['egreso'].toDouble();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: esIngreso ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            esIngreso ? Icons.arrow_upward : Icons.arrow_downward,
                            color: esIngreso ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['detalle'] ?? '',
                                style: TextStyle(fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87)),
                              Text('Dia ${m['dia']}',
                                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                          '${esIngreso ? '+' : '-'}${_formatear(monto)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: esIngreso ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                if (permisos.puedeIngresarEgresar)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarFormulario(esIngreso: true),
                          icon: const Icon(Icons.add),
                          label: const Text('Ingreso'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _libroFinalizado ? Colors.grey : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarFormulario(esIngreso: false),
                          icon: const Icon(Icons.remove),
                          label: const Text('Egreso'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _libroFinalizado ? Colors.grey : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
