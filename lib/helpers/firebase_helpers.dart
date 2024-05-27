import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .set({
      'name': name,
      'email': email,
      'contactNumber': contactNumber,
      'profilePictureUrl': profileUrl ?? '',
    });
  }

  Future<String?> fetchUserProfileUrl() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    var userData = userDoc.data() as Map<String, dynamic>?;
    return userData?['profilePictureUrl'] as String?;
  }
}
