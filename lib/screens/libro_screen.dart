import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LibroScreen extends StatefulWidget {
  const LibroScreen({super.key});

  @override
  State<LibroScreen> createState() => _LibroScreenState();
}

class _LibroScreenState extends State<LibroScreen> {
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;
  bool _libroFinalizado = false;
  int _folioInicialIngreso = 1;
  int _folioInicialEgreso = 1;

  final List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  final _db = FirebaseFirestore.instance;

  String _formatear(double valor) {
    return '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
  }

  int _diasEnMes(int mes, int anio) {
    return DateTime(anio, mes + 1, 0).day;
  }

  @override
  void initState() {
    super.initState();
    _cargarUltimoMesActivo();
    _cargarConfiguracion();
  }

  Future<void> _cargarUltimoMesActivo() async {
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
        _mesSeleccionado = mes;
        _anioSeleccionado = anio;
      });
    } else {
      int mesSiguiente = mes == 12 ? 1 : mes + 1;
      int anioSiguiente = mes == 12 ? anio + 1 : anio;
      setState(() {
        _mesSeleccionado = mesSiguiente;
        _anioSeleccionado = anioSiguiente;
      });
    }

    await _verificarLibroFinalizado();
    await _agregarSaldoAnterior();
  }

  Future<void> _cargarConfiguracion() async {
    final doc = await _db.collection('configuracion').doc('iglesia').get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _folioInicialIngreso = data['folioInicialIngreso'] ?? 1;
        _folioInicialEgreso = data['folioInicialEgreso'] ?? 1;
      });
    }
  }

  Future<void> _verificarLibroFinalizado() async {
    final snapshot = await _db
        .collection('libros_finalizados')
        .where('mes', isEqualTo: _mesSeleccionado)
        .where('anio', isEqualTo: _anioSeleccionado)
        .get();
    setState(() {
      _libroFinalizado = snapshot.docs.isNotEmpty;
    });
  }

  Future<double> _obtenerSaldoActual() async {
    final movMes = await _db
        .collection('movimientos')
        .where('mes', isEqualTo: _mesSeleccionado)
        .where('anio', isEqualTo: _anioSeleccionado)
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    if (movMes.docs.isNotEmpty) {
      return (movMes.docs.first['saldo'] ?? 0).toDouble();
    }

    int mesAnterior = _mesSeleccionado == 1 ? 12 : _mesSeleccionado - 1;
    int anioAnterior = _mesSeleccionado == 1 ? _anioSeleccionado - 1 : _anioSeleccionado;

    final libroAnterior = await _db
        .collection('libros_finalizados')
        .where('mes', isEqualTo: mesAnterior)
        .where('anio', isEqualTo: anioAnterior)
        .get();

    if (libroAnterior.docs.isNotEmpty) {
      return (libroAnterior.docs.first['saldoFinal'] ?? 0).toDouble();
    }

    return 0;
  }

  Future<String> _obtenerUltimoFolioIngreso() async {
    final snapshot = await _db
        .collection('movimientos')
        .where('tipoFolio', isEqualTo: 'ingreso')
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final folio = snapshot.docs.first['folioNumero'] ?? (_folioInicialIngreso - 1);
      return 'I-${(folio + 1).toString().padLeft(3, '0')}';
    }
    return 'I-${_folioInicialIngreso.toString().padLeft(3, '0')}';
  }

  Future<String> _obtenerUltimoFolioEgreso() async {
    final snapshot = await _db
        .collection('movimientos')
        .where('tipoFolio', isEqualTo: 'egreso')
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final folio = snapshot.docs.first['folioNumero'] ?? (_folioInicialEgreso - 1);
      return 'E-${(folio + 1).toString().padLeft(3, '0')}';
    }
    return 'E-${_folioInicialEgreso.toString().padLeft(3, '0')}';
  }

  Future<void> _agregarSaldoAnterior() async {
    final existe = await _db
        .collection('movimientos')
        .where('mes', isEqualTo: _mesSeleccionado)
        .where('anio', isEqualTo: _anioSeleccionado)
        .get();

    if (existe.docs.isNotEmpty) return;

    int mesAnterior = _mesSeleccionado == 1 ? 12 : _mesSeleccionado - 1;
    int anioAnterior = _mesSeleccionado == 1 ? _anioSeleccionado - 1 : _anioSeleccionado;

    final libroAnterior = await _db
        .collection('libros_finalizados')
        .where('mes', isEqualTo: mesAnterior)
        .where('anio', isEqualTo: anioAnterior)
        .get();

    if (libroAnterior.docs.isEmpty) return;

    final saldoAnterior = (libroAnterior.docs.first['saldoFinal'] ?? 0).toDouble();
    if (saldoAnterior == 0) return;

    await _db.collection('movimientos').add({
      'folio': 'S-ANT',
      'folioNumero': 0,
      'tipoFolio': 'saldo',
      'dia': 1,
      'detalle': 'Saldo anterior - ${_meses[mesAnterior - 1]} $anioAnterior',
      'ingreso': saldoAnterior,
      'egreso': null,
      'saldo': saldoAnterior,
      'estado': 'Activo',
      'mes': _mesSeleccionado,
      'anio': _anioSeleccionado,
      'esSaldoAnterior': true,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  void _mostrarLibroFinalizado() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('El libro de ${_meses[_mesSeleccionado - 1]} ya ha sido finalizado'),
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
    final maxDias = _diasEnMes(_mesSeleccionado, _anioSeleccionado);

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
              decoration: const InputDecoration(
                labelText: 'Detalle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto',
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
              if (detalleCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El detalle no puede estar vacio'), backgroundColor: Colors.red),
                );
                return;
              }

              final saldoActual = await _obtenerSaldoActual();
              final nuevoSaldo = esIngreso ? saldoActual + monto : saldoActual - monto;

              String folio;
              int folioNumero;

              if (esIngreso) {
                folio = await _obtenerUltimoFolioIngreso();
                final snap = await _db
                    .collection('movimientos')
                    .where('tipoFolio', isEqualTo: 'ingreso')
                    .orderBy('fecha', descending: true)
                    .limit(1)
                    .get();
                folioNumero = snap.docs.isNotEmpty
                    ? (snap.docs.first['folioNumero'] ?? (_folioInicialIngreso - 1)) + 1
                    : _folioInicialIngreso;
              } else {
                folio = await _obtenerUltimoFolioEgreso();
                final snap = await _db
                    .collection('movimientos')
                    .where('tipoFolio', isEqualTo: 'egreso')
                    .orderBy('fecha', descending: true)
                    .limit(1)
                    .get();
                folioNumero = snap.docs.isNotEmpty
                    ? (snap.docs.first['folioNumero'] ?? (_folioInicialEgreso - 1)) + 1
                    : _folioInicialEgreso;
              }

              await _db.collection('movimientos').add({
                'folio': folio,
                'folioNumero': folioNumero,
                'tipoFolio': esIngreso ? 'ingreso' : 'egreso',
                'dia': dia,
                'detalle': detalleCtrl.text,
                'ingreso': esIngreso ? monto : null,
                'egreso': esIngreso ? null : monto,
                'saldo': nuevoSaldo,
                'estado': 'Activo',
                'mes': _mesSeleccionado,
                'anio': _anioSeleccionado,
                'fecha': FieldValue.serverTimestamp(),
              });

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

  void _mostrarFinalizarLibro(List<QueryDocumentSnapshot> movimientos) {
    if (_libroFinalizado) {
      _mostrarLibroFinalizado();
      return;
    }

    double totalIngresos = 0;
    double totalEgresos = 0;
    double saldoFinal = 0;

    for (var doc in movimientos) {
      final m = doc.data() as Map<String, dynamic>;
      if (m['estado'] == 'Activo' && m['esSaldoAnterior'] != true) {
        if (m['ingreso'] != null) totalIngresos += m['ingreso'].toDouble();
        if (m['egreso'] != null) totalEgresos += m['egreso'].toDouble();
      }
    }

    if (movimientos.isNotEmpty) {
      saldoFinal = (movimientos.last['saldo'] ?? 0).toDouble();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Finalizar Libro'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_meses[_mesSeleccionado - 1]} $_anioSeleccionado',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _filaResumen('Total Ingresos', _formatear(totalIngresos), Colors.green),
            const SizedBox(height: 8),
            _filaResumen('Total Egresos', _formatear(totalEgresos), Colors.red),
            const Divider(),
            _filaResumen('Saldo Final', _formatear(saldoFinal), Colors.indigo),
            const SizedBox(height: 16),
            const Text(
              'Al finalizar el libro no se podran agregar mas movimientos en este mes.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _db.collection('libros_finalizados').add({
                'mes': _mesSeleccionado,
                'anio': _anioSeleccionado,
                'totalIngresos': totalIngresos,
                'totalEgresos': totalEgresos,
                'saldoFinal': saldoFinal,
                'fecha': FieldValue.serverTimestamp(),
              });
              setState(() => _libroFinalizado = true);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Libro de ${_meses[_mesSeleccionado - 1]} finalizado correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.lock),
            label: const Text('Finalizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaResumen(String label, String valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : const Color(0xFFF5F5F5);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Libro de Tesoreria', style: TextStyle(color: Colors.white)),
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
            .where('mes', isEqualTo: _mesSeleccionado)
            .where('anio', isEqualTo: _anioSeleccionado)
            .orderBy('fecha')
            .snapshots(),
        builder: (context, snapshot) {
          final movimientos = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

          return Column(
            children: [
              Container(
                color: _libroFinalizado
                    ? Colors.red.shade900.withOpacity(0.2)
                    : Colors.indigo.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _mesSeleccionado,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontSize: 13),
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_meses[i]),
                      )),
                      onChanged: (v) {
                        setState(() => _mesSeleccionado = v!);
                        _verificarLibroFinalizado();
                        _agregarSaldoAnterior();
                      },
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _anioSeleccionado,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontSize: 13),
                      items: [2024, 2025, 2026, 2027].map((a) => DropdownMenuItem(
                        value: a,
                        child: Text(a.toString()),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _anioSeleccionado = v!);
                        _verificarLibroFinalizado();
                        _agregarSaldoAnterior();
                      },
                    ),
                    const Spacer(),
                    if (movimientos.isNotEmpty && !_libroFinalizado)
                      TextButton.icon(
                        onPressed: () => _mostrarFinalizarLibro(movimientos),
                        icon: const Icon(Icons.lock, color: Colors.indigo, size: 16),
                        label: const Text('Finalizar', style: TextStyle(color: Colors.indigo, fontSize: 12)),
                      ),
                    if (_libroFinalizado)
                      const Row(
                        children: [
                          Icon(Icons.lock, color: Colors.red, size: 14),
                          SizedBox(width: 4),
                          Text('Finalizado', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : movimientos.isEmpty
                        ? Center(child: Text('No hay movimientos este mes',
                            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.indigo),
                                dataRowColor: WidgetStateProperty.all(cardColor),
                                columns: const [
                                  DataColumn(label: Text('Dia', style: TextStyle(color: Colors.white))),
                                  DataColumn(label: Text('Detalle', style: TextStyle(color: Colors.white))),
                                  DataColumn(label: Text('Ingreso', style: TextStyle(color: Colors.white))),
                                  DataColumn(label: Text('Egreso', style: TextStyle(color: Colors.white))),
                                  DataColumn(label: Text('Saldo', style: TextStyle(color: Colors.white))),
                                  DataColumn(label: Text('Folio', style: TextStyle(color: Colors.white))),
                                  DataColumn(label: Text('Estado', style: TextStyle(color: Colors.white))),
                                ],
                                rows: movimientos.map((doc) {
                                  final m = doc.data() as Map<String, dynamic>;
                                  final estado = m['estado'] ?? 'Activo';
                                  final esSaldoAnterior = m['esSaldoAnterior'] == true;
                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      esSaldoAnterior
                                          ? Colors.indigo.withOpacity(0.15)
                                          : estado == 'Anulado'
                                              ? Colors.red.withOpacity(0.15)
                                              : cardColor,
                                    ),
                                    cells: [
                                      DataCell(Text(m['dia'].toString(), style: TextStyle(color: textColor))),
                                      DataCell(Row(
                                        children: [
                                          if (esSaldoAnterior)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 4),
                                              child: Icon(Icons.arrow_forward, size: 14, color: Colors.indigo),
                                            ),
                                          Flexible(child: Text(m['detalle'] ?? '', style: TextStyle(color: textColor))),
                                        ],
                                      )),
                                      DataCell(Text(
                                        m['ingreso'] != null ? _formatear(m['ingreso'].toDouble()) : '-',
                                        style: const TextStyle(color: Colors.green),
                                      )),
                                      DataCell(Text(
                                        m['egreso'] != null ? _formatear(m['egreso'].toDouble()) : '-',
                                        style: const TextStyle(color: Colors.red),
                                      )),
                                      DataCell(Text(_formatear(m['saldo'].toDouble()), style: TextStyle(color: textColor))),
                                      DataCell(Text(m['folio']?.toString() ?? '-', style: TextStyle(color: textColor))),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: esSaldoAnterior
                                              ? Colors.indigo.withOpacity(0.2)
                                              : estado == 'Activo'
                                                  ? Colors.green.withOpacity(0.2)
                                                  : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          esSaldoAnterior ? 'S. Anterior' : estado,
                                          style: TextStyle(
                                            color: esSaldoAnterior
                                                ? Colors.indigo
                                                : estado == 'Activo'
                                                    ? Colors.green
                                                    : Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
      bottomSheet: Container(
        color: cardColor,
        padding: const EdgeInsets.all(12),
        child: Row(
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
      ),
    );
  }
}