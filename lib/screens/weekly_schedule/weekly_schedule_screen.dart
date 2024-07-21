import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../bloc/attendance_bloc.dart';
import '../../../theming/colors.dart';
import '../../../core/widgets/reusable_widgets.dart';

class WeeklyScheduleScreen extends StatelessWidget {
  final AttendanceBloc attendanceBloc;

  const WeeklyScheduleScreen({super.key, required this.attendanceBloc});

  List<String> getSortedDays() {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: attendanceBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Weekly Schedule', style: GoogleFonts.ropaSans()),
          backgroundColor: ColorsManager.lightShadeOfGray,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocBuilder<AttendanceBloc, AttendanceState>(
                    builder: (context, state) {
                      if (state is AttendanceLoaded) {
                        final registeredClasses = state.registeredClasses;
                        final sortedDays = getSortedDays();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sortedDays.map((day) {
                            final classes = registeredClasses
                                .where((classInfo) => classInfo['day'] == day)
                                .toList();

                            if (classes.isEmpty) {
                              return Container(); // Return an empty container if no classes for this day
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "$day's Classes",
                                  style: GoogleFonts.ropaSans(
                                    textStyle: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: classes.length,
                                  itemBuilder: (context, index) {
                                    final classInfo = classes[index];
                                    final avatarColor =
                                        ReusableWidgets.generateAvatarColor(
                                            classInfo['subject'],
                                            classInfo['day'],
                                            classInfo['startTime']);

                                    return Card(
                                      margin:
                                          EdgeInsets.symmetric(vertical: 8.h),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15.r),
                                      ),
                                      elevation: 2,
                                      child: Padding(
                                        padding: EdgeInsets.all(15.w),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: avatarColor,
                                                  child: Text(
                                                    classInfo['subject'][0],
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 10.w),
                                                Expanded(
                                                  child: Text(
                                                    classInfo['subject'],
                                                    style: TextStyle(
                                                      fontSize: 18.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 10.h),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time,
                                                    size: 16.sp,
                                                    color: Colors.grey),
                                                SizedBox(width: 5.w),
                                                Expanded(
                                                  child: Text(
                                                    '${classInfo['startTime']} - ${classInfo['endTime']}',
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 10.h),
                                            ReusableWidgets.buildLocationRow(
                                                classInfo['location']),
                                            SizedBox(height: 10.h),
                                            ReusableWidgets.buildPlaceRow(
                                                'Room ${classInfo['roomNumber']}'),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 20.h),
                              ],
                            );
                          }).toList(),
                        );
                      } else if (state is AttendanceError) {
                        return Center(
                          child: Text(
                            state.message,
                            style:
                                TextStyle(color: Colors.red, fontSize: 18.sp),
                          ),
                        );
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
