import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:psm2_attendease/services/ml_service.dart';
import 'package:psm2_attendease/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:psm2_attendease/utils/date_utils.dart' as custom_date_utils;

part 'attendance_event.dart';
part 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String userId;
  final MLService _mlService = MLService();
  bool _attendanceLoaded = false;

  AttendanceBloc(this.userId) : super(AttendanceInitial()) {
    on<LoadAttendance>(_onLoadAttendance);
    on<UpdateAttendanceStatus>(_onUpdateAttendanceStatus);
    on<ScanFaceForAttendance>(_onScanFaceForAttendance);
    on<UpdateUserId>(_onUpdateUserId);
    on<ClearAttendance>(_onClearAttendance);
    on<GenerateReport>(_onGenerateReport);
    _mlService.initialize();
  }

  Future<void> _onLoadAttendance(
      LoadAttendance event, Emitter<AttendanceState> emit) async {
    // Reset the attendance loaded flag to allow re-fetching of data
    _attendanceLoaded = false;

    if (_attendanceLoaded) return;
    _attendanceLoaded = true;

    try {
      print("Loading attendance for user: $userId");
      if (userId.isEmpty) {
        emit(AttendanceError("User ID is empty."));
        return;
      }

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> weeklySchedule = data['weeklySchedule'];

        final weekId = _getWeekId();
        final attendanceRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('weeklyAttendance')
            .doc(weekId);

        DocumentSnapshot attendanceDoc = await attendanceRef.get();
        Map<String, dynamic> weeklyAttendance = {};

        if (attendanceDoc.exists) {
          weeklyAttendance = attendanceDoc.data() as Map<String, dynamic>;
        }

        emit(AttendanceLoaded(weeklySchedule, weeklyAttendance));
        // Schedule notifications for each class
        _scheduleClassNotifications(weeklySchedule);
      } else {
        emit(AttendanceError("No attendance data found."));
      }
    } catch (e) {
      emit(AttendanceError("Failed to load attendance data: ${e.toString()}"));
    }
  }

  Future<void> _scheduleClassNotifications(
      Map<String, dynamic> schedule) async {
    final classTimes = _extractClassTimes(schedule);
    for (var entry in classTimes.entries) {
      final weekday = entry.key;
      for (var classInfo in entry.value) {
        String classTime = classInfo['time'] ?? 'Unknown Time';
        String subject = classInfo['subject'] ?? 'Unknown Subject';

        try {
          final classDate =
              custom_date_utils.DateUtils.getNextClassDate(weekday, classTime);
          await NotificationService.scheduleClassReminder(
            subject,
            classTime,
            classDate,
          );
          // Log the scheduled time
          print(
              'Notification scheduled for class $subject at $classTime on $weekday at ${classDate.toLocal()}');
        } catch (e) {
          print('Failed to parse time: $classTime on $weekday. Error: $e');
        }
      }
    }
  }

  Map<String, List<Map<String, String>>> _extractClassTimes(
      Map<String, dynamic> schedule) {
    final classTimes = <String, List<Map<String, String>>>{};
    schedule.forEach((day, classes) {
      if (classes is List) {
        for (var item in classes) {
          if (item is Map &&
              item.containsKey('time') &&
              item.containsKey('subject')) {
            classTimes
                .putIfAbsent(day, () => [])
                .add({'time': item['time'], 'subject': item['subject']});
          }
        }
      }
    });
    return classTimes;
  }

  Future<void> _onUpdateAttendanceStatus(
      UpdateAttendanceStatus event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceLoaded) {
      final currentState = state as AttendanceLoaded;
      final weeklySchedule =
          Map<String, dynamic>.from(currentState.weeklySchedule);

      try {
        final weekId = _getWeekId(); // Get the current week ID
        final attendanceRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('weeklyAttendance')
            .doc(weekId);

        DocumentSnapshot attendanceDoc = await attendanceRef.get();
        Map<String, dynamic> weeklyAttendance;

        if (attendanceDoc.exists) {
          weeklyAttendance = attendanceDoc.data() as Map<String, dynamic>;
        } else {
          weeklyAttendance = {};
        }

        List<dynamic> updatedClasses =
            List<dynamic>.from(weeklyAttendance[event.day] ?? []);

        bool classFound = false;
        for (var classInfo in updatedClasses) {
          if (classInfo['subject'] == event.subject) {
            classInfo['status'] = event.status;
            classInfo['timestamp'] = DateTime.now().toIso8601String();
            classFound = true;
            break;
          }
        }
        if (!classFound) {
          updatedClasses.add({
            'subject': event.subject,
            'status': event.status,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }

        weeklyAttendance[event.day] = updatedClasses;

        await attendanceRef.set(weeklyAttendance, SetOptions(merge: true));
        emit(AttendanceLoaded(weeklySchedule, weeklyAttendance));
        print("Firestore updated successfully with new attendance status.");
      } catch (e) {
        print("Failed to update Firestore: ${e.toString()}");
        emit(AttendanceError(
            "Failed to update attendance status: ${e.toString()}"));
      }
    }
  }

  Future<void> _onScanFaceForAttendance(
      ScanFaceForAttendance event, Emitter<AttendanceState> emit) async {
    emit(FaceScanInProgress());
    try {
      print("Scanning face for attendance: $event");

      final userDoc = await _firestore.collection('users').doc(userId).get();
      print("User document fetched: ${userDoc.data()}");

      var faceData = userDoc.data()?['faceData'];
      print("User face data: $faceData");

      if (faceData == null || faceData.isEmpty) {
        var profileUrl = userDoc.data()?['profilePictureUrl'];
        print("User profile picture URL: $profileUrl");

        if (profileUrl != null) {
          final imageBytes = await _downloadImage(profileUrl);
          print("Profile image downloaded, bytes length: ${imageBytes.length}");

          final faceDetected = await _mlService.detectFaceFromBytes(imageBytes);
          print("Face detected in profile image: $faceDetected");

          if (faceDetected != null) {
            _mlService.setCurrentPrediction(imageBytes, faceDetected);
            faceData = _mlService.predictedData;
            await _firestore
                .collection('users')
                .doc(userId)
                .update({'faceData': faceData});
            print("Face data updated in Firestore");
          }
        }
      }

      if (faceData != null) {
        final capturedImageBytes = await _loadLocalImage(event.imagePath);
        print(
            "Captured image loaded, bytes length: ${capturedImageBytes.length}");

        final capturedFace =
            await _mlService.detectFaceFromBytes(capturedImageBytes);
        print("Face detected in captured image: $capturedFace");

        if (capturedFace != null) {
          _mlService.setCurrentPrediction(capturedImageBytes, capturedFace);
          if (await _mlService.matchFace(faceData)) {
            print("Faces matched, marking attendance as present");
            await _updateAttendanceInFirestore(event);
            emit(FaceScanSuccess("Attendance marked successfully."));
          } else {
            print("Face does not match");
            emit(FaceScanFailed("Face does not match."));
          }
        } else {
          print("No face detected in the captured image");
          emit(FaceScanFailed("No face detected in the captured image."));
        }
      } else {
        print("No face data found in user profile");
        emit(FaceScanFailed("No face data found in user profile."));
      }
    } catch (e) {
      print("Error during face scan: $e");
      emit(FaceScanFailed(e.toString()));
    }
  }

  Future<void> _updateAttendanceInFirestore(ScanFaceForAttendance event) async {
    try {
      final weekId = _getWeekId(); // Get the current week ID
      final attendanceRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('weeklyAttendance')
          .doc(weekId);

      DocumentSnapshot attendanceDoc = await attendanceRef.get();
      Map<String, dynamic> weeklyAttendance;

      if (attendanceDoc.exists) {
        weeklyAttendance = attendanceDoc.data() as Map<String, dynamic>;
      } else {
        weeklyAttendance = {};
      }

      List<dynamic> updatedClasses =
          List<dynamic>.from(weeklyAttendance[event.day] ?? []);

      bool classFound = false;
      for (var classInfo in updatedClasses) {
        if (classInfo['subject'] == event.subject) {
          classInfo['status'] = 'present';
          classInfo['timestamp'] = DateTime.now().toIso8601String();
          classFound = true;
          break;
        }
      }
      if (!classFound) {
        updatedClasses.add({
          'subject': event.subject,
          'status': 'present',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      weeklyAttendance[event.day] = updatedClasses;

      await attendanceRef.set(weeklyAttendance, SetOptions(merge: true));
      print("Firestore updated successfully with new attendance status.");
      print("Updated Attendance Data: $weeklyAttendance");
    } catch (e) {
      print("Failed to update attendance in Firestore: ${e.toString()}");
    }
  }

  void _onUpdateUserId(UpdateUserId event, Emitter<AttendanceState> emit) {
    userId = event.userId;
    _attendanceLoaded = false;
    add(LoadAttendance());
  }

  void _onClearAttendance(
      ClearAttendance event, Emitter<AttendanceState> emit) {
    emit(AttendanceInitial());
    _attendanceLoaded = false; // Reset flag to ensure data is re-fetched
  }

  Future<Uint8List> _downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download profile picture');
    }
  }

  Future<Uint8List> _loadLocalImage(String imagePath) async {
    final file = File(imagePath);
    return await file.readAsBytes();
  }

  Future<Face?> detectFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: true,
      ),
    );
    final List<Face> faces = await faceDetector.processImage(inputImage);
    faceDetector.close();
    return faces.isNotEmpty ? faces.first : null;
  }

  Future<List> fetchProfileData(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data() != null) {
      return List.from(userDoc['faceData']);
    } else {
      throw Exception("User profile data not found.");
    }
  }

  String _getWeekId() {
    final now = DateTime.now();
    final weekYear = "${now.year}-${weekOfYear(now)}";
    return weekYear;
  }

  int weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;

    // Get the ISO week number
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return weekNumber;
  }

  Future<void> _onGenerateReport(
      GenerateReport event, Emitter<AttendanceState> emit) async {
    emit(ReportLoading());
    try {
      print("Generating report for user: $userId");
      print("Start Date: ${event.startDate}");
      print("End Date: ${event.endDate}");

      // Get all documents from the weeklyAttendance collection
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weeklyAttendance')
          .get();

      print(
          "Query executed. Number of documents found: ${snapshot.docs.length}");

      if (snapshot.docs.isEmpty) {
        print("No documents found for the specified period.");
        emit(ReportError("No attendance data found for the specified period."));
        return;
      }

      Map<String, dynamic> reportData = {};

      for (var doc in snapshot.docs) {
        print("Processing document ID: ${doc.id}");

        Map<String, dynamic> weeklyData = doc.data() as Map<String, dynamic>;

        weeklyData.forEach((day, attendanceList) {
          if (attendanceList is List) {
            for (var attendance in attendanceList) {
              if (attendance is Map) {
                String timestamp = attendance['timestamp'] ?? '';
                DateTime attendanceDate = DateTime.parse(timestamp);

                if (attendanceDate.isAfter(event.startDate) &&
                    attendanceDate.isBefore(event.endDate)) {
                  print("Attendance found: $attendance");

                  if (!reportData.containsKey(day)) {
                    reportData[day] = [];
                  }
                  reportData[day].add(attendance);
                }
              }
            }
          }
        });
      }

      if (reportData.isEmpty) {
        print("No documents found for the specified period.");
        emit(ReportError("No attendance data found for the specified period."));
        return;
      }

      print("Report generated successfully with ${reportData.length} entries.");
      emit(ReportLoaded(reportData));
    } catch (e) {
      print("Error during report generation: ${e.toString()}");
      emit(ReportError("Failed to generate report: ${e.toString()}"));
    }
  }
}
