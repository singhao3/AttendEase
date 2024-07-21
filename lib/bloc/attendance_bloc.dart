import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:psm2_attendease/services/ml_service.dart';
import 'package:psm2_attendease/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:psm2_attendease/utils/date_utils.dart' as custom_date_utils;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../helpers/firebase_helpers.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String userId;
  final MLService _mlService = MLService();
  bool _notificationsScheduled = false;

  AttendanceBloc(this.userId) : super(AttendanceInitial()) {
    on<LoadAttendance>(_onLoadAttendance);
    on<LoadAllAttendance>(_onLoadAllAttendance);
    on<UpdateAttendanceStatus>(_onUpdateAttendanceStatus);
    on<ScanFaceForAttendance>(_onScanFaceForAttendance);
    on<UpdateUserId>(_onUpdateUserId);
    on<ClearAttendance>(_onClearAttendance);
    on<GenerateReport>(_onGenerateReport);
    _mlService.initialize();
  }

  Future<void> _onLoadAttendance(
      LoadAttendance event, Emitter<AttendanceState> emit) async {
    try {
      final String id = event.studentId ?? userId;
      if (id.isEmpty) {
        emit(AttendanceError("User ID is empty."));
        return;
      }

      // Check and update the student's registered classes
      await FirebaseHelpers().checkAndUpdateRegisteredClasses(id);

      // Fetch the updated user data
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(id).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        List<dynamic> registeredClasses = data['registeredClasses'] ?? [];

        final weekId = _getWeekId();
        final attendanceRef = _firestore
            .collection('users')
            .doc(id)
            .collection('weeklyAttendance')
            .doc(weekId);

        DocumentSnapshot attendanceDoc = await attendanceRef.get();
        Map<String, dynamic> weeklyAttendance = {};

        if (attendanceDoc.exists) {
          weeklyAttendance = attendanceDoc.data() as Map<String, dynamic>;
        }

        emit(AttendanceLoaded(registeredClasses, weeklyAttendance));

        if (!_notificationsScheduled) {
          _scheduleClassNotifications(registeredClasses);
          _notificationsScheduled = true;
        }
      } else {
        emit(AttendanceError("No attendance data found."));
      }
    } catch (e) {
      emit(AttendanceError("Failed to load attendance data: ${e.toString()}"));
    }
  }

  Future<void> _onLoadAllAttendance(
    LoadAllAttendance event, Emitter<AttendanceState> emit) async {
  try {
    final String id = event.studentId;
    if (id.isEmpty) {
      emit(AttendanceError("User ID is empty."));
      return;
    }

    QuerySnapshot weeklyAttendanceSnapshot = await _firestore
        .collection('users')
        .doc(id)
        .collection('weeklyAttendance')
        .get();

    Map<String, List<Map<String, dynamic>>> subjectGroupedAttendance = {};

    for (var doc in weeklyAttendanceSnapshot.docs) {
      Map<String, dynamic> weeklyData = doc.data() as Map<String, dynamic>;
      final weekNumber = _getWeekNumberFromDocId(doc.id);
      weeklyData.forEach((day, attendanceList) {
        if (attendanceList is List) {
          for (var classInfo in attendanceList) {
            if (classInfo is Map) {
              final classInfoMap = Map<String, dynamic>.from(classInfo);
              classInfoMap['weekNumber'] = weekNumber;
              classInfoMap['day'] = day;  // Add the day information
              final subject = classInfoMap['subject'];
              if (subject is String) {
                subjectGroupedAttendance.putIfAbsent(subject, () => []);
                subjectGroupedAttendance[subject]!.add(classInfoMap);
              }
            }
          }
        }
      });
    }

    final sortedSubjects = subjectGroupedAttendance.keys.toList()..sort();

    Map<String, List<Map<String, dynamic>>> sortedAttendance = 
      Map.fromEntries(sortedSubjects.map((subject) => 
        MapEntry(subject, subjectGroupedAttendance[subject]!)));

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(id).get();
    List<dynamic> registeredClasses =
        (userDoc.data() as Map<String, dynamic>)['registeredClasses'] ?? [];

    emit(AttendanceLoaded(registeredClasses, sortedAttendance));
  } catch (e) {
    emit(AttendanceError(
        "Failed to load all attendance data: ${e.toString()}"));
  }
}

  int _getWeekNumberFromDocId(String docId) {
    final parts = docId.split('-');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 0;
    }
    return 0;
  }

  void _scheduleClassNotifications(List<dynamic> registeredClasses) {
    for (var classInfo in registeredClasses) {
      final className = classInfo['subject'] ?? 'Unknown Subject';
      final startTime = classInfo['startTime'] ?? 'Unknown Start Time';
      final endTime = classInfo['endTime'] ?? 'Unknown End Time';
      final day = classInfo['day'];
      final fromTime = classInfo['fromTime'];

      if (className == 'Unknown Subject' ||
          startTime == 'Unknown Start Time' ||
          endTime == 'Unknown End Time' ||
          day == null ||
          fromTime == null) {
        debugPrint('Skipping class due to missing information: $classInfo');
        continue;
      }

      final time = '$startTime - $endTime';
      final scheduleDate =
          custom_date_utils.DateUtils.getNextClassDate(day, fromTime);

      NotificationService.scheduleClassReminder(className, time, scheduleDate);
    }
  }

  void _onUpdateAttendanceStatus(
      UpdateAttendanceStatus event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceLoaded) {
      final currentState = state as AttendanceLoaded;
      final registeredClasses =
          List<dynamic>.from(currentState.registeredClasses);

      try {
        final weekId = _getWeekId();
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
        emit(AttendanceLoaded(registeredClasses, weeklyAttendance));
        debugPrint(
            "Firestore updated successfully with new attendance status.");

        await NotificationService.rescheduleAllNotifications();
        _notificationsScheduled = true;
      } catch (e) {
        debugPrint("Failed to update Firestore: ${e.toString()}");
        emit(AttendanceError(
            "Failed to update attendance status: ${e.toString()}"));
      }
    }
  }

  Future<bool> _isWithinGeofence(String coordinates) async {
    final locationParts = coordinates.split(',');
    if (locationParts.length != 2) return false;

    final double classLat = double.parse(locationParts[0].trim());
    final double classLong = double.parse(locationParts[1].trim());

    Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        classLat,
        classLong);

    final prefs = await SharedPreferences.getInstance();
    final double thresholdDistance =
        prefs.getInt('threshold_distance')?.toDouble() ?? 50.0;

    return distanceInMeters <= thresholdDistance;
  }

  Future<void> _onScanFaceForAttendance(
      ScanFaceForAttendance event, Emitter<AttendanceState> emit) async {
    if (state is! AttendanceLoaded) {
      emit(FaceScanFailed("Attendance data is not loaded."));
      return;
    }

    final attendanceLoadedState = state as AttendanceLoaded;
    emit(FaceScanInProgress());

    try {
      final prefs = await SharedPreferences.getInstance();
      final int presentThreshold = prefs.getInt('present_threshold') ?? 30;

      debugPrint("Scanning face for attendance: $event");

      final userDoc = await _firestore.collection('users').doc(userId).get();
      debugPrint("User document fetched: ${userDoc.data()}");

      var faceData = userDoc.data()?['faceData'];
      debugPrint("User face data: $faceData");

      if (faceData == null || faceData.isEmpty) {
        var profileUrl = userDoc.data()?['profilePictureUrl'];
        debugPrint("User profile picture URL: $profileUrl");

        if (profileUrl != null) {
          final imageBytes = await _downloadImage(profileUrl);
          debugPrint(
              "Profile image downloaded, bytes length: ${imageBytes.length}");

          final faceDetected = await _mlService.detectFaceFromBytes(imageBytes);
          debugPrint("Face detected in profile image: $faceDetected");

          if (faceDetected != null) {
            _mlService.setCurrentPrediction(imageBytes, faceDetected);
            faceData = _mlService.predictedData;
            await _firestore
                .collection('users')
                .doc(userId)
                .update({'faceData': faceData});
            debugPrint("Face data updated in Firestore");
          }
        }
      }

      if (faceData != null) {
        final capturedImageBytes = await _loadLocalImage(event.imagePath);
        debugPrint(
            "Captured image loaded, bytes length: ${capturedImageBytes.length}");

        final capturedFace =
            await _mlService.detectFaceFromBytes(capturedImageBytes);
        debugPrint("Face detected in captured image: $capturedFace");

        if (capturedFace != null) {
          _mlService.setCurrentPrediction(capturedImageBytes, capturedFace);
          if (await _mlService.matchFace(faceData)) {
            debugPrint("Faces matched, marking attendance");

            final registeredClasses = attendanceLoadedState.registeredClasses;
            final classInfo = registeredClasses.firstWhere(
                (classItem) =>
                    classItem['subject'] == event.subject &&
                    classItem['day'] == event.day,
                orElse: () => null);

            if (classInfo == null) {
              emit(FaceScanFailed("Class not found in registered classes."));
              return;
            }

            final classTime = _parseClassTime(classInfo['startTime']);
            final classEndTime = _parseClassTime(classInfo['endTime']);
            final now = DateTime.now();
            final difference = now.difference(classTime).inMinutes;

            // Log the thresholds and difference
            debugPrint("Difference: $difference minutes");
            debugPrint("Present Threshold: $presentThreshold minutes");

            // Geolocation check
            final isWithinGeofence =
                await _isWithinGeofence(classInfo['coordinates'] ?? '');
            if (!isWithinGeofence) {
              emit(FaceScanFailed("You are not within the class location."));
              return;
            }

            String status;
            if (now.isAfter(classEndTime)) {
              status = 'absent';
            } else if (difference <= presentThreshold) {
              status = 'present';
            } else {
              status = 'late';
            }

            await _updateAttendanceInFirestore(event, status);
            emit(FaceScanSuccess("Attendance marked successfully."));
          } else {
            debugPrint("Face does not match");
            emit(FaceScanFailed("Face does not match."));
          }
        } else {
          debugPrint("No face detected in the captured image");
          emit(FaceScanFailed("No face detected in the captured image."));
        }
      } else {
        debugPrint("No face data found in user profile");
        emit(FaceScanFailed("No face data found in user profile."));
      }
    } catch (e) {
      debugPrint("Error during face scan: $e");
      emit(FaceScanFailed(e.toString()));
    }
  }

  Future<void> _updateAttendanceInFirestore(
      ScanFaceForAttendance event, String status) async {
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
          classInfo['status'] = status;
          classInfo['timestamp'] = DateTime.now().toIso8601String();
          classFound = true;
          break;
        }
      }
      if (!classFound) {
        updatedClasses.add({
          'subject': event.subject,
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      weeklyAttendance[event.day] = updatedClasses;

      await attendanceRef.set(weeklyAttendance, SetOptions(merge: true));
      debugPrint("Firestore updated successfully with new attendance status.");
      debugPrint("Updated Attendance Data: $weeklyAttendance");
    } catch (e) {
      debugPrint("Failed to update attendance in Firestore: ${e.toString()}");
    }
  }

  void _onUpdateUserId(UpdateUserId event, Emitter<AttendanceState> emit) {
    userId = event.userId;
    _notificationsScheduled =
        false; // Reset flag to ensure notifications are rescheduled
    add(LoadAttendance());
  }

  void _onClearAttendance(
      ClearAttendance event, Emitter<AttendanceState> emit) {
    emit(AttendanceInitial());
// Reset flag to ensure data is re-fetched
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
      debugPrint("Generating report for user: $userId");
      debugPrint("Start Date: ${event.startDate}");
      debugPrint("End Date: ${event.endDate}");

      final adjustedEndDate = event.endDate.add(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weeklyAttendance')
          .get();

      debugPrint(
          "Query executed. Number of documents found: ${snapshot.docs.length}");

      if (snapshot.docs.isEmpty) {
        debugPrint("No documents found for the specified period.");
        emit(ReportError("No attendance data found for the specified period."));
        return;
      }

      Map<String, dynamic> reportData = {};

      for (var doc in snapshot.docs) {
        debugPrint("Processing document ID: ${doc.id}");

        Map<String, dynamic> weeklyData = doc.data() as Map<String, dynamic>;

        weeklyData.forEach((day, attendanceList) {
          if (attendanceList is List) {
            for (var attendance in attendanceList) {
              if (attendance is Map) {
                String timestamp = attendance['timestamp'] ?? '';
                DateTime attendanceDate = DateTime.parse(timestamp);

                // Change this condition to include the end date
                if (attendanceDate.isAtSameMomentAs(event.startDate) ||
                    attendanceDate.isAfter(event.startDate) &&
                        attendanceDate.isBefore(adjustedEndDate)) {
                  debugPrint("Attendance found: $attendance");

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
        debugPrint("No documents found for the specified period.");
        emit(ReportError("No attendance data found for the specified period."));
        return;
      }

      debugPrint(
          "Report generated successfully with ${reportData.length} entries.");
      emit(ReportLoaded(reportData));
    } catch (e) {
      debugPrint("Error during report generation: ${e.toString()}");
      emit(ReportError("Failed to generate report: ${e.toString()}"));
    }
  }

  DateTime _parseClassTime(String time) {
    final now = DateTime.now();
    final timeParts = time.split(' ');

    if (timeParts.length != 2) {
      throw FormatException("Invalid time format: $time");
    }

    final period = timeParts[1];
    final hourMinuteParts = timeParts[0].split(':');

    if (hourMinuteParts.length != 2) {
      throw FormatException("Invalid time format: $time");
    }

    int hour = int.parse(hourMinuteParts[0]);
    final int minute = int.parse(hourMinuteParts[1]);

    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
