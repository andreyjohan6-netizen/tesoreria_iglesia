import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/permisos.dart';
import '../services/movimientos_service.dart';
import '../theme/app_theme.dart';

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
        backgroundColor: AppColors.egreso,
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
              decoration: InputDecoration(labelText: 'Dia (1 - $maxDias)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: detalleCtrl,
              decoration: const InputDecoration(labelText: 'Detalle'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto'),
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
                  SnackBar(content: Text('El dia debe estar entre 1 y $maxDias'), backgroundColor: AppColors.egreso),
                );
                return;
              }
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              if (monto <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El monto debe ser mayor a 0'), backgroundColor: AppColors.egreso),
                );
                return;
              }
              if (detalleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El detalle no puede estar vacio'), backgroundColor: AppColors.egreso),
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
              backgroundColor: esIngreso ? AppColors.ingreso : AppColors.egreso,
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
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
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
                      radius: 16,
                      backgroundImage: MemoryImage(base64Decode(logo)),
                    )
                  else
                    const Icon(Icons.church, color: Colors.white, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(nombre, overflow: TextOverflow.ellipsis),
                  ),
                ],
              );
            }
            return const Text('Tesoreria Iglesia');
          },
        ),
        actions: [
          if (_libroFinalizado)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.lg),
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_libroFinalizado)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.egreso.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.egreso.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: AppColors.egreso, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'El libro de ${_meses[_mes - 1]} ya fue finalizado',
                            style: const TextStyle(color: AppColors.egreso, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brand, AppColors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Saldo actual',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${_meses[_mes - 1]} $_anio',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _formatear(saldo),
                        style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(child: _tarjetaTotal('Ingresos', ingresos, AppColors.ingreso, Icons.arrow_downward, cardColor, isDark)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _tarjetaTotal('Egresos', egresos, AppColors.egreso, Icons.arrow_upward, cardColor, isDark)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                Text('Ultimos movimientos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: AppSpacing.md),

                if (ultimos.isEmpty)
                  _estadoVacio(subtle)
                else
                  ...ultimos.map((doc) {
                    final m = doc.data() as Map<String, dynamic>;
                    if (m['esSaldoAnterior'] == true) return const SizedBox.shrink();
                    final esIngreso = m['ingreso'] != null;
                    final monto = esIngreso ? m['ingreso'].toDouble() : m['egreso'].toDouble();
                    final anulado = m['estado'] == 'Anulado';
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: (esIngreso ? AppColors.ingreso : AppColors.egreso).withValues(alpha: 0.12),
                            child: Icon(
                              esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                              color: esIngreso ? AppColors.ingreso : AppColors.egreso,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['detalle'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    decoration: anulado ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                Text('Dia ${m['dia']}', style: TextStyle(color: subtle, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            '${esIngreso ? '+' : '-'}${_formatear(monto)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: esIngreso ? AppColors.ingreso : AppColors.egreso,
                              decoration: anulado ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: AppSpacing.xl),

                if (permisos.puedeIngresarEgresar)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarFormulario(esIngreso: true),
                          icon: const Icon(Icons.add),
                          label: const Text('Ingreso'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _libroFinalizado ? Colors.grey : AppColors.ingreso,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarFormulario(esIngreso: false),
                          icon: const Icon(Icons.remove),
                          label: const Text('Egreso'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _libroFinalizado ? Colors.grey : AppColors.egreso,
                            foregroundColor: Colors.white,
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

  Widget _tarjetaTotal(String titulo, double valor, Color color, IconData icono, Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(titulo, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatear(valor),
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(Color subtle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: subtle.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.md),
          Text('Aun no hay movimientos este mes', style: TextStyle(color: subtle)),
        ],
      ),
    );
  }
}
