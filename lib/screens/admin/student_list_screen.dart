import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:psm2_attendease/theming/colors.dart';
import '../attendance_history/attendance_history_screen.dart';
import 'student_schedule_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<Map<String, dynamic>> students = [];
  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  bool hasMore = true;
  final int documentLimit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchStudents();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> fetchStudents() async {
    if (!hasMore) return;
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Students List', style: GoogleFonts.ropaSans()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        backgroundImage: student['profilePictureUrl'] != null
                            ? NetworkImage(student['profilePictureUrl'])
                            : const AssetImage('assets/images/placeholder.jpg')
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
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.schedule),
                                title: const Text('View Schedule'),
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
                              ListTile(
                                leading: const Icon(Icons.history),
                                title: const Text('View Attendance History'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AttendanceHistoryScreen(
                                        studentId: student['id'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
