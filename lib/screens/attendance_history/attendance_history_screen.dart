import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psm2_attendease/bloc/attendance_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theming/colors.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  final String studentId;

  const AttendanceHistoryScreen({super.key, required this.studentId});

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
    context.read<AttendanceBloc>().add(LoadAllAttendance(studentId: studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance History', style: GoogleFonts.ropaSans()),
        backgroundColor: ColorsManager.lightShadeOfGray,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.teal.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: BlocBuilder<AttendanceBloc, AttendanceState>(
          builder: (context, state) {
            if (state is AttendanceLoaded) {
              if (state.weeklyAttendance.isEmpty) {
                return Center(
                  child: Text(
                    'No attendance history available.',
                    style: GoogleFonts.ropaSans(fontSize: 16, color: Colors.teal.shade700),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: state.weeklyAttendance.keys.length,
                itemBuilder: (context, index) {
                  final subject = state.weeklyAttendance.keys.elementAt(index);
                  final attendances = state.weeklyAttendance[subject]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      title: Text(subject, style: GoogleFonts.ropaSans(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.teal.shade800)),
                      children: attendances.map<Widget>((attendance) {
                        final timestamp = attendance['timestamp'];
                        final weekNumber = attendance['weekNumber'];
                        final formattedTimestamp = timestamp != null ? _formatTimestamp(timestamp) : 'N/A';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                          leading: Icon(Icons.date_range, color: Colors.teal.shade700),
                          title: Text(
                            'Date: $formattedTimestamp',
                            style: GoogleFonts.ropaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text(
                                'Status: ${attendance['status']}',
                                style: GoogleFonts.ropaSans(color: Colors.teal.shade700),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Week: $weekNumber',
                                style: GoogleFonts.ropaSans(color: Colors.teal.shade700),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Day: ${attendance['day']}',
                                style: GoogleFonts.ropaSans(color: Colors.teal.shade700),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            } else if (state is AttendanceError) {
              return Center(child: Text(state.message, style: GoogleFonts.ropaSans(fontSize: 16, color: Colors.red)));
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}