import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:psm2_attendease/theming/colors.dart';
import '../../../core/widgets/user_header.dart';
import '../../../core/widgets/user_profile_section.dart';
import '../../../core/widgets/sign_out.dart';
import '../../../helpers/firebase_helpers.dart';
import '../../admin/student_schedule_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String? profileImageUrl;
  final FirebaseHelpers firebaseHelpers = FirebaseHelpers();
  List<Map<String, dynamic>> students = [];
  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  bool hasMore = true;
  final int documentLimit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    fetchStudents();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> fetchUserProfile() async {
    profileImageUrl = await firebaseHelpers.fetchUserProfileUrl();
    if (mounted) setState(() {});
  }

  Future<void> fetchStudents() async {
    if (!hasMore) return;
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isNotEqualTo: 'admin')
        .limit(documentLimit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }

    QuerySnapshot userDocs = await query.get();
    if (userDocs.docs.isEmpty) {
      setState(() {
        hasMore = false;
        isLoading = false;
      });
      return;
    }

    lastDocument = userDocs.docs.last;
    List<Map<String, dynamic>> userData = userDocs.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'] ?? 'No Name',
        'email': data['email'] ?? 'No Email',
        'profilePictureUrl': data['profilePictureUrl'],
      };
    }).toList();

    setState(() {
      students.addAll(userData);
      isLoading = false;
    });
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200) {
      fetchStudents();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint(user.toString());

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text('User is not signed in',
              style: GoogleFonts.ropaSans(fontSize: 20)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Home', style: GoogleFonts.ropaSans()),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const UserHeader(backgroundColor: ColorsManager.indigo),
            ListTile(
              title: Text('Admin Home', style: GoogleFonts.ropaSans()),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              title: Text('Sign Out', style: GoogleFonts.ropaSans()),
              onTap: () => SignOut.signOut(context),
            ),
            // Add more drawer items for admin-specific actions
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserProfileSection(profileImageUrl: profileImageUrl),
            const SizedBox(height: 20),
            Text(
              'Students List',
              style: GoogleFonts.ropaSans(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Text(
                        'No students found.',
                        style: GoogleFonts.ropaSans(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: students.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == students.length) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final student = students[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10.0),
                            leading: CircleAvatar(
                              backgroundImage: student['profilePictureUrl'] !=
                                      null
                                  ? NetworkImage(student['profilePictureUrl'])
                                  : const AssetImage(
                                          'assets/images/placeholder.jpg')
                                      as ImageProvider,
                              radius: 30,
                            ),
                            title: Text(
                              student['name'],
                              style: GoogleFonts.ropaSans(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              student['email'],
                              style: GoogleFonts.ropaSans(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: ColorsManager.mainBlue),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentScheduleScreen(
                                    studentId: student['id'],
                                    studentName: student['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
