import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;
  final _db = FirebaseFirestore.instance;

  final List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

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
    // Ordenar por dia para que el reporte coincida con el libro.
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Libro de Tesoreria - ${_meses[_mesSeleccionado - 1]} $_anioSeleccionado',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Dia', 'Detalle', 'Ingreso', 'Egreso', 'Saldo', 'Folio'],
            data: docs.map((doc) {
              final m = doc.data() as Map<String, dynamic>;
              return [
                m['dia'].toString(),
                m['detalle'] ?? '',
                m['ingreso'] != null ? _formatear(m['ingreso'].toDouble()) : '-',
                m['egreso'] != null ? _formatear(m['egreso'].toDouble()) : '-',
                _formatear(m['saldo'].toDouble()),
                m['folio']?.toString() ?? '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            cellAlignment: pw.Alignment.centerLeft,
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
        TextCellValue(m['saldo'].toString()),
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
    final bgColor = isDark ? Colors.grey.shade900 : const Color(0xFFF5F5F5);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Reportes', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.indigo),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _mesSeleccionado,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_meses[i]))),
                        onChanged: (v) => setState(() => _mesSeleccionado = v!),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _anioSeleccionado,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                        items: [2024, 2025, 2026, 2027].map((a) => DropdownMenuItem(value: a, child: Text(a.toString()))).toList(),
                        onChanged: (v) => setState(() => _anioSeleccionado = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('Resumen Mensual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 8),
                _tarjetaResumen(titulo: _meses[_mesSeleccionado - 1], ingresos: ingresosMes, egresos: egresosMes, saldo: saldoMes, cardColor: cardColor, textColor: textColor),
                const SizedBox(height: 16),

                Text('Resumen Anual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 8),
                _tarjetaResumen(titulo: _anioSeleccionado.toString(), ingresos: ingresosAnio, egresos: egresosAnio, saldo: saldoAnio, cardColor: cardColor, textColor: textColor),
                const SizedBox(height: 16),

                Text('Detalle por Mes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.indigo),
                      dataRowColor: WidgetStateProperty.all(cardColor),
                      columns: const [
                        DataColumn(label: Text('Mes', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Ingresos', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Egresos', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Saldo', style: TextStyle(color: Colors.white))),
                      ],
                      rows: List.generate(12, (i) {
                        final ing = ingresosPorMes[i + 1] ?? 0;
                        final egr = egresosPorMes[i + 1] ?? 0;
                        final sal = ing - egr;
                        return DataRow(cells: [
                          DataCell(Text(_meses[i], style: TextStyle(color: textColor))),
                          DataCell(Text(_formatear(ing), style: const TextStyle(color: Colors.green))),
                          DataCell(Text(_formatear(egr), style: const TextStyle(color: Colors.red))),
                          DataCell(Text(_formatear(sal), style: TextStyle(color: sal >= 0 ? Colors.indigo : Colors.red, fontWeight: FontWeight.bold))),
                        ]);
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Exportar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final docs = await _obtenerMovimientosMes(_mesSeleccionado, _anioSeleccionado);
                          await _exportarPDF(docs);
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Exportar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final docs = await _obtenerMovimientosMes(_mesSeleccionado, _anioSeleccionado);
                          await _exportarExcel(docs);
                        },
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Exportar Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
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

  Widget _tarjetaResumen({
    required String titulo,
    required double ingresos,
    required double egresos,
    required double saldo,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _itemResumen('Ingresos', ingresos, Colors.green),
              _itemResumen('Egresos', egresos, Colors.red),
              _itemResumen('Saldo', saldo, Colors.indigo),
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