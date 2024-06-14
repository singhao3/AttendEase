import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psm2_attendease/bloc/attendance_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('EEE, MMM d, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  int weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return weekNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance History', style: GoogleFonts.ropaSans()),
      ),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          if (state is AttendanceLoaded) {
            if (state.weeklyAttendance.isEmpty) {
              return Center(
                child: Text(
                  'No attendance history available.',
                  style: GoogleFonts.ropaSans(fontSize: 16),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: state.weeklyAttendance.length,
              itemBuilder: (context, index) {
                final day = state.weeklyAttendance.keys.elementAt(index);
                final classes = state.weeklyAttendance[day];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    title: Text(day, style: GoogleFonts.ropaSans(fontSize: 18)),
                    children: classes.map<Widget>((classInfo) {
                      final timestamp = classInfo['timestamp'];
                      final weekNumber = timestamp != null
                          ? weekOfYear(DateTime.parse(timestamp))
                          : 'N/A';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 15.0),
                        title: Text(
                          classInfo['subject'],
                          style: GoogleFonts.ropaSans(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text(
                              'Status: ${classInfo['status']}',
                              style: GoogleFonts.ropaSans(),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Time: ${_formatTimestamp(classInfo['timestamp'])}',
                              style: GoogleFonts.ropaSans(fontSize: 12),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Week: $weekNumber',
                              style: GoogleFonts.ropaSans(fontSize: 12),
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
            return Center(child: Text(state.message));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
