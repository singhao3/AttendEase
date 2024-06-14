import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:psm2_attendease/bloc/attendance_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:psm2_attendease/utils/pdf_generator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final GlobalKey _chartKey = GlobalKey();

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both start and end dates.')),
      );
      return;
    }

    context.read<AttendanceBloc>().add(GenerateReport(_startDate!, _endDate!));
  }

  Future<void> _downloadPdf(Map<String, dynamic> reportData) async {
    final chartImage = await _capturePng();
    PdfGenerator.generatePdf(reportData, chartImage: chartImage);
  }

  Future<Uint8List> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      rethrow;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('EEE, MMM d, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (isBackButton) {
        // Clear the attendance state to avoid reloading issues
        context.read<AttendanceBloc>().add(ClearAttendance());
        context
            .read<AttendanceBloc>()
            .add(LoadAttendance()); // Trigger reloading of attendance data
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Generate Report', style: GoogleFonts.ropaSans()),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildDatePicker('Start Date', _startController, true),
              const SizedBox(height: 10),
              _buildDatePicker('End Date', _endController, false),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _generateReport,
                icon: const Icon(FontAwesomeIcons.filePdf),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<AttendanceBloc, AttendanceState>(
                builder: (context, state) {
                  if (state is ReportLoading) {
                    return const CircularProgressIndicator();
                  } else if (state is ReportLoaded) {
                    final sortedData = _sortDataBySubject(state.reportData);
                    return Expanded(
                      child: Column(
                        children: [
                          RepaintBoundary(
                            key: _chartKey,
                            child: _buildChart(sortedData),
                          ),
                          const SizedBox(height: 20),
                          _buildLegend(),
                          Expanded(
                            child: ListView.builder(
                              itemCount: sortedData.length,
                              itemBuilder: (context, index) {
                                final entry =
                                    sortedData.entries.elementAt(index);
                                return _buildReportCard(entry.key, entry.value);
                              },
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _downloadPdf(state.reportData),
                            icon: const Icon(FontAwesomeIcons.download),
                            label: const Text('Download PDF'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (state is ReportError) {
                    return Text(state.message,
                        style: const TextStyle(color: Colors.red));
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(
      String label, TextEditingController controller, bool isStart) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(FontAwesomeIcons.calendarDay),
      ),
      readOnly: true,
      onTap: () => _selectDate(context, controller, isStart),
    );
  }

  Map<String, List<Map<String, dynamic>>> _sortDataBySubject(
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

  Widget _buildReportCard(
      String subject, List<Map<String, dynamic>> attendanceList) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...attendanceList.map((attendance) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(attendance['status']),
                    Text(_formatTimestamp(attendance['timestamp'])),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(Map<String, List<Map<String, dynamic>>> sortedData) {
    final List<BarChartGroupData> barGroups = [];
    sortedData.forEach((subject, attendanceList) {
      final int presentCount = attendanceList
          .where((attendance) => attendance['status'] == 'present')
          .length;
      final int absentCount = attendanceList.length - presentCount;

      barGroups.add(
        BarChartGroupData(
          x: sortedData.keys.toList().indexOf(subject),
          barRods: [
            BarChartRodData(
              toY: presentCount.toDouble(),
              color: Colors.green,
              width: 15,
            ),
            BarChartRodData(
              toY: absentCount.toDouble(),
              color: Colors.red,
              width: 15,
            ),
          ],
        ),
      );
    });

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final subject = sortedData.keys.toList()[value.toInt()];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(
                      subject,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.green, 'Present'),
        const SizedBox(width: 20),
        _buildLegendItem(Colors.red, 'Absent'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
