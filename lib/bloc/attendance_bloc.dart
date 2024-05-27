import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  AttendanceBloc(this.userId) : super(AttendanceInitial()) {
    on<LoadAttendance>(_onLoadAttendance);
    on<UpdateAttendanceStatus>(_onUpdateAttendanceStatus);
    on<ScanFaceForAttendance>(_onScanFaceForAttendance);
  }

  Future<void> _onLoadAttendance(
      LoadAttendance event, Emitter<AttendanceState> emit) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      Map<String, dynamic> weeklySchedule = userDoc['weeklySchedule'];
      emit(AttendanceLoaded(weeklySchedule));
    } catch (e) {
      emit(AttendanceError("Failed to load attendance data"));
    }
  }

  void _onUpdateAttendanceStatus(
      UpdateAttendanceStatus event, Emitter<AttendanceState> emit) {
    if (state is AttendanceLoaded) {
      //print("Updating status for ${event.subject} on ${event.day} to ${event.status}");
      final currentState = state as AttendanceLoaded;
      final updatedSchedule =
          Map<String, dynamic>.from(currentState.weeklySchedule);

      // Update the specific class status
      List<dynamic> updatedClasses =
          List<dynamic>.from(updatedSchedule[event.day] ?? []);
      updatedClasses = updatedClasses.map((classInfo) {
        if (classInfo['subject'] == event.subject) {
          return {...classInfo, 'status': event.status};
        }
        return classInfo;
      }).toList();

      updatedSchedule[event.day] = updatedClasses;

      // Update Firestore and re-emit updated state
      _firestore
          .collection('users')
          .doc(userId)
          .update({'weeklySchedule': updatedSchedule});
      emit(AttendanceLoaded(updatedSchedule));
    }
  }

  // Future<void> _onScanFaceForAttendance(ScanFaceForAttendance event, Emitter<AttendanceState> emit) async {
  //   emit(FaceScanInProgress());
  //   try {
  //     final FaceDetector faceDetector = FaceDetector(options: FaceDetectorOptions(
  //       performanceMode: FaceDetectorMode.accurate,
  //     ));
  //     final InputImage inputImage = InputImage.fromFilePath(event.imagePath);
  //     final List<Face> faces = await faceDetector.processImage(inputImage);
  //     faceDetector.close();

  //     if (faces.isNotEmpty) {
  //       final bool isMatch = await matchFaceWithProfile(faces[0], userId);
  //       if (isMatch) {
  //         add(UpdateAttendanceStatus(event.subject, 'present', event.day));
  //       } else {
  //         emit(FaceScanFailed("Face does not match."));
  //       }
  //     } else {
  //       emit(FaceScanFailed("No face detected."));
  //     }
  //   } catch (e) {
  //     emit(FaceScanFailed(e.toString()));
  //   } finally {
  //     add(LoadAttendance());
  //   }
  // }

  Future<void> _onScanFaceForAttendance(
      ScanFaceForAttendance event, Emitter<AttendanceState> emit) async {
    // Directly mark attendance as present for testing.
    // print("Adding UpdateAttendanceStatus event");
    add(UpdateAttendanceStatus(event.subject, 'present', event.day));
  }

  Future<bool> matchFaceWithProfile(Face detectedFace, String userId) async {
    // Implement the face matching logic with the user's profile picture from Firestore
    // Placeholder return value
    return true;
  }
}
