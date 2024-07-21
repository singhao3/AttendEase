import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:psm2_attendease/theming/colors.dart';
import '../../../core/widgets/user_header.dart';
import '../../../core/widgets/user_profile_section.dart';
import '../../../core/widgets/sign_out.dart';
import '../../../helpers/firebase_helpers.dart';
import '../../admin/admin_settings_screen.dart';
import '../../admin/student_list_screen.dart';
import '../../admin/manage_classes_screen.dart';

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

  Map<String, dynamic> overallAttendance = {};
  List<Map<String, dynamic>> weeklyAttendance = [];

  bool isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    fetchStudents();
    loadData();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> loadData() async {
    await fetchOverallAttendance();
    await fetchWeeklyAttendance();
    setState(() {
      isDataLoaded = true;
    });
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

  Future<void> fetchOverallAttendance() async {
    try {
      DateTime now = DateTime.now();
      String today = DateFormat('yyyy-MM-dd').format(now);

      // Get total number of students
      QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      int totalStudents = studentsSnapshot.docs.length;

      // Calculate total present today across all users
      int presentToday = 0;
      for (var doc in studentsSnapshot.docs) {
        String studentId = doc.id;
        String weekId = _getWeekId();
        DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .collection('weeklyAttendance')
            .doc(weekId)
            .get();

        if (attendanceDoc.exists) {
          Map<String, dynamic> weeklyData =
              attendanceDoc.data() as Map<String, dynamic>;
          weeklyData.forEach((day, data) {
            if (data is List) {
              var dayAttendance = data
                  .where((entry) =>
                      entry['timestamp'].startsWith(today) &&
                      (entry['status'] == 'present' ||
                          entry['status'] == 'late'))
                  .length;
              presentToday += dayAttendance;
            }
          });
        }
      }

      // Calculate average attendance for the past 30 days
      int totalAttendanceLast30Days = 0;
      DateTime thirtyDaysAgo = now.subtract(const Duration(days: 30));
      for (var doc in studentsSnapshot.docs) {
        String studentId = doc.id;
        QuerySnapshot pastAttendance = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .collection('weeklyAttendance')
            .where('timestamp', isGreaterThanOrEqualTo: thirtyDaysAgo)
            .get();

        for (var weekDoc in pastAttendance.docs) {
          Map<String, dynamic> weeklyData =
              weekDoc.data() as Map<String, dynamic>;
          weeklyData.forEach((day, data) {
            if (data is List) {
              var dayAttendance = data
                  .where((entry) => (entry['status'] == 'present' ||
                      entry['status'] == 'late'))
                  .length;
              totalAttendanceLast30Days += dayAttendance;
            }
          });
        }
      }

      double averageAttendance =
          totalAttendanceLast30Days / (totalStudents * 30);

      setState(() {
        overallAttendance = {
          'totalStudents': totalStudents,
          'presentToday': presentToday,
          'averageAttendance': averageAttendance,
        };
      });
    } catch (e) {
      debugPrint('Error fetching overall attendance: $e');
    }
  }

  Future<void> fetchWeeklyAttendance() async {
    try {
      DateTime now = DateTime.now();
      List<Map<String, dynamic>> weekData = [];

      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        String formattedDate = DateFormat('yyyy-MM-dd').format(date);

        int totalAttendance = 0;
        int presentCount = 0;

        QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();

        for (var doc in studentsSnapshot.docs) {
          String studentId = doc.id;
          String weekId = _getWeekId();
          DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .collection('weeklyAttendance')
              .doc(weekId)
              .get();

          if (attendanceDoc.exists) {
            Map<String, dynamic> weeklyData =
                attendanceDoc.data() as Map<String, dynamic>;
            weeklyData.forEach((day, data) {
              if (data is List && day == DateFormat('EEEE').format(date)) {
                totalAttendance += data.length;
                presentCount += data
                    .where((entry) =>
                        (entry['status'] == 'present' ||
                            entry['status'] == 'late') &&
                        entry['timestamp'].startsWith(formattedDate))
                    .length;
              }
            });
          }
        }

        double attendanceRate =
            totalAttendance > 0 ? presentCount / totalAttendance : 0;

        weekData.add({
          'date': DateFormat('E').format(date),
          'attendance': attendanceRate,
        });
      }

      setState(() {
        weeklyAttendance = weekData;
      });
    } catch (e) {
      debugPrint('Error fetching weekly attendance: $e');
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildOverviewAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance Overview',
          style:
              GoogleFonts.ropaSans(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.people,
                color: ColorsManager.mainBlue,
                title: 'Total Students',
                value: overallAttendance['totalStudents']?.toString() ?? '0',
              ),
            ),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.check_circle,
                color: Colors.green,
                title: 'Present Today',
                value: overallAttendance['presentToday']?.toString() ?? '0',
              ),
            ),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.trending_up,
                color: Colors.orange,
                title: 'Avg. Attendance',
                value: overallAttendance['averageAttendance'] != null
                    ? '${(overallAttendance['averageAttendance'] * 100).toStringAsFixed(1)}%'
                    : '0%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Weekly Attendance Trend',
          style:
              GoogleFonts.ropaSans(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 250,
          child: weeklyAttendance.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 1,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${weeklyAttendance[group.x.toInt()]['date']}: ${(rod.toY * 100).toStringAsFixed(1)}%',
                            TextStyle(
                                color: Colors.white,
                                fontFamily: GoogleFonts.ropaSans().fontFamily,
                                backgroundColor:
                                    Colors.blueGrey.withOpacity(0.8)),
                          );
                        },
                        tooltipBorder:
                            BorderSide(color: Colors.blueGrey.withOpacity(0.8)),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            return index < weeklyAttendance.length
                                ? Text(
                                    weeklyAttendance[index]['date'] ?? '',
                                    style: GoogleFonts.ropaSans(fontSize: 12),
                                  )
                                : const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${(value * 100).toInt()}%',
                              style: GoogleFonts.ropaSans(fontSize: 12),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: 0.2,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyAttendance.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value['attendance'] ?? 0,
                            gradient: LinearGradient(
                              colors: [
                                ColorsManager.mainBlue.withOpacity(0.6),
                                ColorsManager.mainBlue
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.ropaSans(fontSize: 14)),
            Text(value,
                style: GoogleFonts.ropaSans(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
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
              leading: const Icon(Icons.home, color: ColorsManager.mainBlue),
              title: Text('Admin Home', style: GoogleFonts.ropaSans()),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: ColorsManager.mainBlue),
              title: Text('Manage Classes', style: GoogleFonts.ropaSans()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageClassesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: ColorsManager.mainBlue),
              title: Text('Students List', style: GoogleFonts.ropaSans()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.settings, color: ColorsManager.mainBlue),
              title: Text('Settings', style: GoogleFonts.ropaSans()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: ColorsManager.mainBlue),
              title: Text('Sign Out', style: GoogleFonts.ropaSans()),
              onTap: () => SignOut.signOut(context),
            ),
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
            isDataLoaded
                ? _buildOverviewAnalytics()
                : const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
