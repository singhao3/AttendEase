import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfGenerator {
  static Future<void> generatePdf(
      Map<String, dynamic> reportData, Map<String, dynamic> studentInfo) async {
    try {
      final pdf = pw.Document();
      final sortedData = _sortDataBySubject(reportData);
      final overallAttendance = _calculateOverallAttendance(sortedData);

      final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      final ttf = pw.Font.ttf(font);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader(studentInfo, ttf),
              _buildOverallSummary(overallAttendance, ttf),
              _buildAttendanceDetails(sortedData, ttf),
            ];
          },
        ),
      );

      debugPrint("Displaying PDF preview...");
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      debugPrint("PDF preview displayed successfully.");
    } catch (e) {
      debugPrint("Error generating PDF: $e");
    }
  }

  static pw.Widget _buildHeader(Map<String, dynamic> studentInfo, pw.Font ttf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Attendance Report',
            style: pw.TextStyle(
                font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Student Information:',
            style: pw.TextStyle(
                font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Name: ${studentInfo['name']}', style: pw.TextStyle(font: ttf)),
        pw.Text('Email: ${studentInfo['email']}',
            style: pw.TextStyle(font: ttf)),
        pw.Text('Contact: ${studentInfo['contactNumber']}',
            style: pw.TextStyle(font: ttf)),
        pw.Text('Level: ${studentInfo['level']}',
            style: pw.TextStyle(font: ttf)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildOverallSummary(
      Map<String, int> overallAttendance, pw.Font ttf) {
    final total = overallAttendance['total']!;
    final present = overallAttendance['present']!;
    final late = overallAttendance['late']!;
    final absent = overallAttendance['absent']!;
    final attendanceRate = (present + late) / total * 100;
    final onTimeRate = present / total * 100;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Overall Attendance Summary',
            style: pw.TextStyle(
                font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryItem('Present', present, PdfColors.green, ttf),
            _buildSummaryItem('Late', late, PdfColors.orange, ttf),
            _buildSummaryItem('Absent', absent, PdfColors.red, ttf),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text('Total Classes: $total', style: pw.TextStyle(font: ttf)),
        pw.Text('Attendance Rate: ${attendanceRate.toStringAsFixed(1)}%',
            style: pw.TextStyle(font: ttf)),
        pw.Text('On-time Rate: ${onTimeRate.toStringAsFixed(1)}%',
            style: pw.TextStyle(font: ttf)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildSummaryItem(
      String label, int count, PdfColor color, pw.Font ttf) {
    return pw.Column(
      children: [
        pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              count.toString(),
              style: pw.TextStyle(
                  font: ttf,
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(font: ttf)),
      ],
    );
  }

  static pw.Widget _buildAttendanceDetails(
      Map<String, List<Map<String, dynamic>>> sortedData, pw.Font ttf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Detailed Attendance',
            style: pw.TextStyle(
                font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        ...sortedData.entries.map((entry) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Subject: ${entry.key}',
                  style: pw.TextStyle(
                      font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                context: null,
                data: <List<String>>[
                  <String>['Date', 'Status', 'Time'],
                  ...entry.value.map<List<String>>((attendance) {
                    final formattedTimestamp = DateFormat('hh:mm a')
                        .format(DateTime.parse(attendance['timestamp']));
                    return [
                      attendance['date'].toString(),
                      attendance['status'].toString(),
                      formattedTimestamp,
                    ];
                  }),
                ],
                cellStyle: pw.TextStyle(font: ttf),
                headerStyle:
                    pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.center,
                headerAlignment: pw.Alignment.center,
              ),
              pw.SizedBox(height: 20),
            ],
          );
        }),
      ],
    );
  }

  static Map<String, List<Map<String, dynamic>>> _sortDataBySubject(
      Map<String, dynamic> reportData) {
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
              ...attendance.map<String, dynamic>(
                  (key, value) => MapEntry(key.toString(), value))
            });
          }
        }
      }
    });

    return sortedData;
  }

  static Map<String, int> _calculateOverallAttendance(
      Map<String, List<Map<String, dynamic>>> sortedData) {
    int totalPresent = 0;
    int totalLate = 0;
    int totalAbsent = 0;
    int totalClasses = 0;

    sortedData.forEach((subject, attendanceList) {
      for (var attendance in attendanceList) {
        switch (attendance['status'].toString().toLowerCase()) {
          case 'present':
            totalPresent++;
            break;
          case 'late':
            totalLate++;
            break;
          case 'absent':
            totalAbsent++;
            break;
        }
        totalClasses++;
      }
    });

    return {
      'present': totalPresent,
      'late': totalLate,
      'absent': totalAbsent,
      'total': totalClasses,
    };
  }
}
