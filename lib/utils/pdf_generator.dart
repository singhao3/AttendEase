import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<void> generatePdf(Map<String, dynamic> reportData, {required Uint8List chartImage}) async {
    final pdf = pw.Document();

    final sortedData = _sortDataBySubject(reportData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Image(pw.MemoryImage(chartImage), height: 200, width: double.infinity, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 20),
              _buildLegend(),
              pw.SizedBox(height: 20),
              ...sortedData.entries.map((entry) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Subject: ${entry.key}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.TableHelper.fromTextArray(
                      context: context,
                      data: <List<String>>[
                        <String>['Date', 'Status', 'Timestamp'],
                        ...entry.value.map<List<String>>((attendance) {
                          final formattedTimestamp = DateFormat('EEE, MMM d, yyyy - hh:mm a').format(DateTime.parse(attendance['timestamp']));
                          return [
                            attendance['date'].toString(),
                            attendance['status'].toString(),
                            formattedTimestamp,
                          ];
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Map<String, List<Map<String, dynamic>>> _sortDataBySubject(Map<String, dynamic> reportData) {
    final sortedData = <String, List<Map<String, dynamic>>>{};

    reportData.forEach((day, attendanceList) {
      if (attendanceList is List) {
        for (var attendance in attendanceList) {
          if (attendance is Map) {
            final subject = attendance['subject'].toString();
            if (!sortedData.containsKey(subject)) {
              sortedData[subject] = [];
            }
            sortedData[subject]!.add({
              'date': day,
              ...attendance.map<String, dynamic>((key, value) => MapEntry(key.toString(), value))
            });
          }
        }
      }
    });

    return sortedData;
  }

  static pw.Widget _buildLegend() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        _buildLegendItem(PdfColors.green, 'Present'),
        pw.SizedBox(width: 20),
        _buildLegendItem(PdfColors.red, 'Absent'),
      ],
    );
  }

  static pw.Widget _buildLegendItem(PdfColor color, String text) {
    return pw.Row(
      children: [
        pw.Container(
          width: 16,
          height: 16,
          color: color,
        ),
        pw.SizedBox(width: 8),
        pw.Text(text),
      ],
    );
  }
}
