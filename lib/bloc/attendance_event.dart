part of 'attendance_bloc.dart';

@immutable
abstract class AttendanceEvent {}

class LoadAttendance extends AttendanceEvent {}

class UpdateAttendanceStatus extends AttendanceEvent {
  final String subject;
  final String status;
  final String day;

  UpdateAttendanceStatus(this.subject, this.status, this.day);
}

class ScanFaceForAttendance extends AttendanceEvent {
  final String imagePath;
  final String subject;
  final String day;

  ScanFaceForAttendance(this.imagePath, this.subject, this.day);
}
