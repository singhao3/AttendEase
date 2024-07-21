part of 'attendance_bloc.dart';

@immutable
abstract class AttendanceEvent {}

class LoadAttendance extends AttendanceEvent {
  final String? studentId;

  LoadAttendance({this.studentId});
}

class LoadAllAttendance extends AttendanceEvent {
  final String studentId;
  LoadAllAttendance({required this.studentId});
}

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

class UpdateUserId extends AttendanceEvent {
  final String userId;

  UpdateUserId(this.userId);
}

class ClearAttendance extends AttendanceEvent {}

class GenerateReport extends AttendanceEvent {
  final DateTime startDate;
  final DateTime endDate;

  GenerateReport(this.startDate, this.endDate);
}
