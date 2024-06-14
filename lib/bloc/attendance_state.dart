part of 'attendance_bloc.dart';

@immutable
abstract class AttendanceState {}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoaded extends AttendanceState {
  final Map<String, dynamic> weeklySchedule;
  final Map<String, dynamic> weeklyAttendance;

  AttendanceLoaded(this.weeklySchedule, this.weeklyAttendance);
}

class AttendanceError extends AttendanceState {
  final String message;

  AttendanceError(this.message);
}

class FaceScanInProgress extends AttendanceState {}

class FaceScanFailed extends AttendanceState {
  final String message;

  FaceScanFailed(this.message);
}

class FaceScanSuccess extends AttendanceState {
  final String message;

  FaceScanSuccess(this.message);
}

class ReportLoading extends AttendanceState {}

class ReportLoaded extends AttendanceState {
  final Map<String, dynamic> reportData;

  ReportLoaded(this.reportData);
}

class ReportError extends AttendanceState {
  final String message;

  ReportError(this.message);
}