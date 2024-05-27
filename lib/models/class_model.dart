class ClassModel {
  final String courseInitials;
  final String courseName;
  final String time;
  final String status;  // 'present', 'absent', 'cancelled'
  final bool canMarkAttendance;

  ClassModel({required this.courseInitials, required this.courseName, required this.time, required this.status, required this.canMarkAttendance});
}
