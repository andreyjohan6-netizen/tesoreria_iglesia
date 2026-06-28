import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:universal_html/html.dart' as html;
import '../theme/app_theme.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;
  bool _mesFinalizado = false;
  final _db = FirebaseFirestore.instance;

  final List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  final List<String> _iniciales = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  void initState() {
    super.initState();
    _verificarFinalizado();
  }

  Future<void> _verificarFinalizado() async {
    final snap = await _db
        .collection('libros_finalizados')
        .where('mes', isEqualTo: _mesSeleccionado)
        .where('anio', isEqualTo: _anioSeleccionado)
        .get();
    if (mounted) setState(() => _mesFinalizado = snap.docs.isNotEmpty);
  }

  void _avisoNoFinalizado() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solo puedes exportar meses ya finalizados (cerrados desde el Libro)'),
        backgroundColor: AppColors.aviso,
      ),
    );
  }

  String _formatear(double valor) {
    return '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
  }

  Future<List<QueryDocumentSnapshot>> _obtenerMovimientosMes(int mes, int anio) async {
    final snapshot = await _db
        .collection('movimientos')
        .where('mes', isEqualTo: mes)
        .where('anio', isEqualTo: anio)
        .where('estado', isEqualTo: 'Activo')
        .orderBy('fecha')
        .get();
    final docs = [...snapshot.docs]..sort((a, b) {
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
    });
    return docs;
  }

  Future<void> _exportarPDF(List<QueryDocumentSnapshot> docs) async {
    final configDoc = await _db.collection('configuracion').doc('iglesia').get();
    final cfg = configDoc.data() ?? {};
    final nombre = (cfg['nombre'] ?? 'Tesoreria Iglesia').toString();
    pw.MemoryImage? logoImg;
    final logoB64 = cfg['logo'];
    if (logoB64 != null) {
      try {
        logoImg = pw.MemoryImage(base64Decode(logoB64));
      } catch (_) {}
    }

    double saldoAnterior = 0;
    double totalIngresos = 0;
    double totalEgresos = 0;
    for (final doc in docs) {
      final m = doc.data() as Map<String, dynamic>;
      if (m['esSaldoAnterior'] == true) {
        saldoAnterior = (m['ingreso'] ?? 0).toDouble();
      } else {
        if (m['ingreso'] != null) totalIngresos += m['ingreso'].toDouble();
        if (m['egreso'] != null) totalEgresos += m['egreso'].toDouble();
      }
    }
    final saldoFinal = saldoAnterior + totalIngresos - totalEgresos;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImg != null) ...[
                pw.Container(width: 48, height: 48, child: pw.Image(logoImg)),
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(nombre,
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Libro de Tesoreria - ${_meses[_mesSeleccionado - 1]} $_anioSeleccionado',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.indigo),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Dia', 'Detalle', 'Ingreso', 'Egreso', 'Saldo', 'Folio'],
            data: docs.map((doc) {
              final m = doc.data() as Map<String, dynamic>;
              return [
                m['dia'].toString(),
                m['detalle'] ?? '',
                m['ingreso'] != null ? _formatear(m['ingreso'].toDouble()) : '-',
                m['egreso'] != null ? _formatear(m['egreso'].toDouble()) : '-',
                _formatear((m['saldo'] ?? 0).toDouble()),
                m['folio']?.toString() ?? '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Ingresos: ${_formatear(totalIngresos)}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Total Egresos: ${_formatear(totalEgresos)}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 4),
                pw.Text('Saldo Final: ${_formatear(saldoFinal)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 48),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(children: [
                pw.Container(width: 160, decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(width: 1)),
                )),
                pw.SizedBox(height: 4),
                pw.Text('Tesorero/a'),
              ]),
              pw.Column(children: [
                pw.Container(width: 160, decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(width: 1)),
                )),
                pw.SizedBox(height: 4),
                pw.Text('Pastor/a'),
              ]),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportarExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final sheet = excel['Tesoreria'];
    sheet.appendRow([
      TextCellValue('Dia'),
      TextCellValue('Detalle'),
      TextCellValue('Ingreso'),
      TextCellValue('Egreso'),
      TextCellValue('Saldo'),
      TextCellValue('Folio'),
      TextCellValue('Estado'),
    ]);
    for (var doc in docs) {
      final m = doc.data() as Map<String, dynamic>;
      sheet.appendRow([
        TextCellValue(m['dia'].toString()),
        TextCellValue(m['detalle'] ?? ''),
        TextCellValue(m['ingreso'] != null ? m['ingreso'].toString() : '-'),
        TextCellValue(m['egreso'] != null ? m['egreso'].toString() : '-'),
        TextCellValue((m['saldo'] ?? 0).toString()),
        TextCellValue(m['folio']?.toString() ?? '-'),
        TextCellValue(m['estado'] ?? 'Activo'),
      ]);
    }
    final bytes = excel.encode()!;
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'tesoreria_${_meses[_mesSeleccionado - 1]}_$_anioSeleccionado.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('movimientos')
            .where('anio', isEqualTo: _anioSeleccionado)
            .orderBy('fecha')
            .snapshots(),
        builder: (context, snapshot) {
          Map<int, double> ingresosPorMes = {};
          Map<int, double> egresosPorMes = {};

          for (int i = 1; i <= 12; i++) {
            ingresosPorMes[i] = 0;
            egresosPorMes[i] = 0;
          }

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final m = doc.data() as Map<String, dynamic>;
              if (m['estado'] == 'Activo' && m['esSaldoAnterior'] != true) {
                final mes = m['mes'] as int;
                if (m['ingreso'] != null) ingresosPorMes[mes] = (ingresosPorMes[mes] ?? 0) + m['ingreso'].toDouble();
                if (m['egreso'] != null) egresosPorMes[mes] = (egresosPorMes[mes] ?? 0) + m['egreso'].toDouble();
              }
            }
          }

          final ingresosMes = ingresosPorMes[_mesSeleccionado] ?? 0;
          final egresosMes = egresosPorMes[_mesSeleccionado] ?? 0;
          final saldoMes = ingresosMes - egresosMes;

          double ingresosAnio = 0;
          double egresosAnio = 0;
          ingresosPorMes.values.forEach((v) => ingresosAnio += v);
          egresosPorMes.values.forEach((v) => egresosAnio += v);
          final saldoAnio = ingresosAnio - egresosAnio;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.brand),
                      const SizedBox(width: AppSpacing.sm),
                      DropdownButton<int>(
                        value: _mesSeleccionado,
                        underline: const SizedBox(),
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_meses[i]))),
                        onChanged: (v) {
                          setState(() => _mesSeleccionado = v!);
                          _verificarFinalizado();
                        },
                      ),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _anioSeleccionado,
                        underline: const SizedBox(),
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        items: [2024, 2025, 2026, 2027].map((a) => DropdownMenuItem(value: a, child: Text(a.toString()))).toList(),
                        onChanged: (v) {
                          setState(() => _anioSeleccionado = v!);
                          _verificarFinalizado();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text('Ingresos vs Egresos $_anioSeleccionado',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: AppSpacing.sm),
                _grafico(ingresosPorMes, egresosPorMes, cardColor, textColor),
                const SizedBox(height: AppSpacing.xl),

                Text('Resumen del mes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: AppSpacing.sm),
                _tarjetaResumen(_meses[_mesSeleccionado - 1], ingresosMes, egresosMes, saldoMes, cardColor, textColor),
                const SizedBox(height: AppSpacing.lg),

                Text('Resumen del ano', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: AppSpacing.sm),
                _tarjetaResumen(_anioSeleccionado.toString(), ingresosAnio, egresosAnio, saldoAnio, cardColor, textColor),
                const SizedBox(height: AppSpacing.xl),

                Text('Exportar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: AppSpacing.sm),
                if (!_mesFinalizado)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.aviso.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.aviso.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.aviso, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Solo puedes exportar meses finalizados. Cierra el mes desde el Libro para habilitarlo.',
                            style: TextStyle(color: AppColors.aviso, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _mesFinalizado
                            ? () async {
                                final docs = await _obtenerMovimientosMes(_mesSeleccionado, _anioSeleccionado);
                                await _exportarPDF(docs);
                              }
                            : _avisoNoFinalizado,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _mesFinalizado ? AppColors.egreso : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _mesFinalizado
                            ? () async {
                                final docs = await _obtenerMovimientosMes(_mesSeleccionado, _anioSeleccionado);
                                await _exportarExcel(docs);
                              }
                            : _avisoNoFinalizado,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _mesFinalizado ? AppColors.ingreso : Colors.grey,
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

  Widget _grafico(Map<int, double> ing, Map<int, double> egr, Color cardColor, Color textColor) {
    double maxVal = 1;
    for (int i = 1; i <= 12; i++) {
      final a = ing[i] ?? 0;
      final b = egr[i] ?? 0;
      if (a > maxVal) maxVal = a;
      if (b > maxVal) maxVal = b;
    }
    const double maxH = 110;

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
              _leyenda(AppColors.ingreso, 'Ingresos'),
              const SizedBox(width: AppSpacing.lg),
              _leyenda(AppColors.egreso, 'Egresos'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: maxH + 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final mi = i + 1;
                final hi = ((ing[mi] ?? 0) / maxVal * maxH);
                final he = ((egr[mi] ?? 0) / maxVal * maxH);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _barra(hi, AppColors.ingreso),
                          const SizedBox(width: 2),
                          _barra(he, AppColors.egreso),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_iniciales[i], style: TextStyle(fontSize: 10, color: textColor)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barra(double h, Color c) {
    return Container(
      width: 7,
      height: h < 2 ? 2 : h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }

  Widget _leyenda(Color c, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _tarjetaResumen(String titulo, double ingresos, double egresos, double saldo, Color cardColor, Color textColor) {
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
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
          const Divider(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _itemResumen('Ingresos', ingresos, AppColors.ingreso),
              _itemResumen('Egresos', egresos, AppColors.egreso),
              _itemResumen('Saldo', saldo, AppColors.brand),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemResumen(String label, double valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(_formatear(valor), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
