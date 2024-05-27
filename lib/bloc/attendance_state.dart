part of 'attendance_bloc.dart';

@immutable
abstract class AttendanceState {}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoaded extends AttendanceState {
  final Map<String, dynamic> weeklySchedule;

  AttendanceLoaded(this.weeklySchedule);
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
