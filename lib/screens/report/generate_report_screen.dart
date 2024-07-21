import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:psm2_attendease/bloc/attendance_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:psm2_attendease/utils/pdf_generator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String? _selectedSubject;
  String _viewType = 'Summary View';
  final userId = FirebaseAuth.instance.currentUser!.uid;

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
        context.read<AttendanceBloc>().add(ClearAttendance());
        context.read<AttendanceBloc>().add(LoadAttendance());
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
                    final subjects = sortedData.keys.toList();
                    final summary = _calculateOverallAttendance(sortedData);
                    return Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DropdownButton<String>(
                                value: _viewType,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _viewType = newValue!;
                                    _selectedSubject = null;
                                  });
                                },
                                items: <String>[
                                  'Summary View',
                                  'Report Cards',
                                  'Pie Chart'
                                ].map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(width: 20),
                              if (_viewType == 'Pie Chart')
                                DropdownButton<String>(
                                  hint: const Text('Select Subject'),
                                  value: _selectedSubject,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedSubject = newValue;
                                    });
                                  },
                                  items: subjects.map((String subject) {
                                    return DropdownMenuItem<String>(
                                      value: subject,
                                      child: Text(subject),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  if (_viewType == 'Summary View')
                                    _buildAttendanceSummary(summary)
                                  else if (_viewType == 'Pie Chart' &&
                                      _selectedSubject != null)
                                    Column(
                                      children: [
                                        RepaintBoundary(
                                          key: _chartKey,
                                          child: _buildPieChart(
                                              sortedData[_selectedSubject]!),
                                        ),
                                        const SizedBox(height: 20),
                                        _buildLegend(
                                            sortedData[_selectedSubject]),
                                      ],
                                    )
                                  else if (_viewType == 'Report Cards')
                                    Column(
                                      children: sortedData.entries.map((entry) {
                                        return _buildReportCard(
                                            entry.key, entry.value);
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                debugPrint("Download button pressed");
                                DocumentSnapshot userDoc =
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(userId)
                                        .get();

                                Map<String, dynamic> studentInfo = {
                                  'name': userDoc['name'],
                                  'email': userDoc['email'],
                                  'contactNumber': userDoc['contactNumber'],
                                  'level': userDoc['level'],
                                };

                                debugPrint("Generating PDF...");
                                await PdfGenerator.generatePdf(
                                    state.reportData, studentInfo);
                                debugPrint("PDF generation complete");
                              } catch (e) {
                                debugPrint("Error generating PDF: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error generating PDF: $e')),
                                );
                              }
                            },
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
                    _buildStatusBadge(attendance['status']),
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

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'present':
        badgeColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'late':
        badgeColor = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'absent':
        badgeColor = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            status.capitalize(),
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> attendanceList) {
    final List<PieChartSectionData> sections = [];
    int totalPresent = 0;
    int totalLate = 0;
    int totalAbsent = 0;

    for (var attendance in attendanceList) {
      if (attendance['status'] == 'present') {
        totalPresent++;
      } else if (attendance['status'] == 'late') {
        totalLate++;
      } else if (attendance['status'] == 'absent') {
        totalAbsent++;
      }
    }

    if (totalPresent > 0) {
      sections.add(PieChartSectionData(
        value: totalPresent.toDouble(),
        title: 'Present',
        color: Colors.green,
        radius: 50,
      ));
    }
    if (totalLate > 0) {
      sections.add(PieChartSectionData(
        value: totalLate.toDouble(),
        title: 'Late',
        color: Colors.orange,
        radius: 50,
      ));
    }
    if (totalAbsent > 0) {
      sections.add(PieChartSectionData(
        value: totalAbsent.toDouble(),
        title: 'Absent',
        color: Colors.red,
        radius: 50,
      ));
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          borderData: FlBorderData(show: false),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>>? attendanceList) {
    if (attendanceList == null) return const SizedBox.shrink();

    int totalPresent = 0;
    int totalLate = 0;
    int totalAbsent = 0;

    for (var attendance in attendanceList) {
      if (attendance['status'] == 'present') {
        totalPresent++;
      } else if (attendance['status'] == 'late') {
        totalLate++;
      } else if (attendance['status'] == 'absent') {
        totalAbsent++;
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.green, 'Present ($totalPresent)'),
            const SizedBox(width: 20),
            _buildLegendItem(Colors.orange, 'Late ($totalLate)'),
            const SizedBox(width: 20),
            _buildLegendItem(Colors.red, 'Absent ($totalAbsent)'),
          ],
        ),
        const SizedBox(height: 10),
        Text('Total Classes: ${totalPresent + totalLate + totalAbsent}'),
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

  Widget _buildAttendanceSummary(Map<String, int> summary) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Attendance Summary',
              style: GoogleFonts.ropaSans(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Present', summary['present']!, Colors.green),
                _buildSummaryItem('Late', summary['late']!, Colors.orange),
                _buildSummaryItem('Absent', summary['absent']!, Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total Classes: ${summary['total']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: summary['attended']! / summary['total']!,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 4),
            Text(
              'Attendance Rate: ${(summary['attended']! / summary['total']! * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 4),
            Text(
              'On-time Rate: ${(summary['present']! / summary['total']! * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

Map<String, int> _calculateOverallAttendance(
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
    'attended': totalPresent + totalLate,
  };
}
