import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FirebaseHelpers {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadProfilePicture(XFile? imageFile) async {
    if (imageFile == null) throw Exception('No image selected');
    File file = File(imageFile.path);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${_auth.currentUser!.uid}.jpg');
      final result = await ref.putFile(file);
      return await result.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  Future<void> saveUserDataToFirestore({
    required String name,
    required String email,
    required String contactNumber,
    String? profileUrl,
    List? faceData,
    required String? level,
    required List<String> selectedClasses,
  }) async {
    DocumentSnapshot classesDoc = await FirebaseFirestore.instance
        .collection('admin')
        .doc('tuitionClasses')
        .get();
    var data = classesDoc.get('classes')[level] ?? {};
    List<Map<String, dynamic>> availableClasses = [];
    data.forEach((day, classes) {
      for (var classInfo in classes) {
        if (selectedClasses.contains(classInfo['subject'])) {
          availableClasses.add({
            ...classInfo,
            'day': day,
          });
        }
      }
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .set({
      'name': name,
      'email': email,
      'contactNumber': contactNumber,
      'profilePictureUrl': profileUrl ?? '',
      'role': 'student',
      'faceData': faceData ?? [],
      'level': level,
      'registeredClasses': availableClasses,
    });
  }

  Future<String?> fetchUserProfileUrl() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    var userData = userDoc.data() as Map<String, dynamic>?;
    return userData?['profilePictureUrl'] as String?;
  }

  Future<void> checkAndUpdateRegisteredClasses(String userId) async {
    try {
      // Fetch the current user's data
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      var userData = userDoc.data() as Map<String, dynamic>;
      String level = userData['level'];
      List<dynamic> currentRegisteredClasses = userData['registeredClasses'] ?? [];

      // Fetch the latest admin tuition classes
      DocumentSnapshot classesDoc = await _firestore.collection('admin').doc('tuitionClasses').get();
      var adminClasses = classesDoc.get('classes')[level] ?? {};

      // Create a new list for updated registered classes
      List<Map<String, dynamic>> updatedRegisteredClasses = [];

      // Check each registered class against the admin classes
      for (var registeredClass in currentRegisteredClasses) {
        String subject = registeredClass['subject'];
        bool classFound = false;

        adminClasses.forEach((day, classes) {
          for (var adminClass in classes) {
            if (adminClass['subject'] == subject) {
              updatedRegisteredClasses.add({
                ...adminClass,
                'day': day,
              });
              classFound = true;
              break;
            }
          }
          if (classFound) return;
        });

        // If the class is not found in admin classes, it has been deleted
        // We don't add it to updatedRegisteredClasses
      }

      // Check if there are any changes
      if (!_areClassListsEqual(currentRegisteredClasses, updatedRegisteredClasses)) {
        // Update the user's document with the new registered classes
        await _firestore.collection('users').doc(userId).update({
          'registeredClasses': updatedRegisteredClasses,
        });
        debugPrint('Registered classes updated for user $userId');
      } else {
        debugPrint('No updates needed for user $userId');
      }
    } catch (e) {
      debugPrint('Error updating registered classes: $e');
    }
  }

  bool _areClassListsEqual(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (!_areClassesEqual(list1[i], list2[i])) return false;
    }
    return true;
  }

  bool _areClassesEqual(dynamic class1, dynamic class2) {
    return class1['subject'] == class2['subject'] &&
           class1['day'] == class2['day'] &&
           class1['startTime'] == class2['startTime'] &&
           class1['endTime'] == class2['endTime'] &&
           class1['location'] == class2['location'] &&
           class1['roomNumber'] == class2['roomNumber'];
  }
}
