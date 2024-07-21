import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentScheduleScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentScheduleScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> registeredClasses = [];
  List<Map<String, dynamic>> predefinedClasses = [];
  Map<String, dynamic>? selectedClass;

  @override
  void initState() {
    super.initState();
    fetchPredefinedClasses();
    fetchStudentSchedule();
  }

  Future<void> fetchPredefinedClasses() async {
    try {
      DocumentSnapshot adminDoc =
          await _firestore.collection('admin').doc('tuitionClasses').get();

      if (adminDoc.exists && adminDoc.data() != null) {
        Map<String, dynamic>? classesMap = adminDoc.get('classes');
        if (classesMap != null) {
          List<Map<String, dynamic>> allClasses = [];

          classesMap.forEach((level, levelData) {
            levelData.forEach((day, dayData) {
              List<Map<String, dynamic>> dayClasses =
                  List<Map<String, dynamic>>.from(dayData);
              for (var classInfo in dayClasses) {
                classInfo['day'] = day;
                allClasses.add(classInfo);
              }
            });
          });

          allClasses.sort((a, b) => _dayToInt(a['day']).compareTo(_dayToInt(b['day'])));

          setState(() {
            predefinedClasses = allClasses;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching predefined classes: $e');
    }
  }

  int _dayToInt(String day) {
    const days = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    return days[day] ?? 0;
  }

  Future<void> fetchStudentSchedule() async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(widget.studentId).get();

      if (userDoc.exists && userDoc.data() != null) {
        List<Map<String, dynamic>> classes = List<Map<String, dynamic>>.from(
          userDoc.get('registeredClasses') ?? [],
        );

        setState(() {
          registeredClasses = classes;
          predefinedClasses.removeWhere((predefinedClass) =>
              registeredClasses.any((registeredClass) =>
                  registeredClass['subject'] == predefinedClass['subject'] &&
                  registeredClass['startTime'] == predefinedClass['startTime'] &&
                  registeredClass['endTime'] == predefinedClass['endTime'] &&
                  registeredClass['location'] == predefinedClass['location'] &&
                  registeredClass['roomNumber'] == predefinedClass['roomNumber']));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching student schedule: $e');
    }
  }

  Future<void> updateSchedule() async {
    try {
      await _firestore.collection('users').doc(widget.studentId).update({
        'registeredClasses': registeredClasses,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update schedule: $e')),
        );
      }
    }
  }

  void _addClass(Map<String, dynamic> classInfo) {
    setState(() {
      registeredClasses.add(classInfo);
      // Remove added class from predefined classes
      predefinedClasses.removeWhere((predefinedClass) =>
          predefinedClass['subject'] == classInfo['subject'] &&
          predefinedClass['startTime'] == classInfo['startTime'] &&
          predefinedClass['endTime'] == classInfo['endTime'] &&
          predefinedClass['location'] == classInfo['location'] &&
          predefinedClass['roomNumber'] == classInfo['roomNumber']);
      selectedClass = null;
    });
  }

  void _removeClass(int index) {
    setState(() {
      registeredClasses.removeAt(index);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName}\'s Schedule',
            style: GoogleFonts.ropaSans()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: updateSchedule,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              isExpanded: true,
              hint: const Text('Please select to add class'),
              value: selectedClass,
              items: predefinedClasses.map((classInfo) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: classInfo,
                  child: Text(
                    '${classInfo['day']} - ${classInfo['subject']} - ${classInfo['startTime']} to ${classInfo['endTime']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedClass = value;
                });
                if (value != null) {
                  _addClass(value);
                }
              },
              decoration: const InputDecoration(labelText: 'Add Class'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: registeredClasses.length,
              itemBuilder: (context, index) {
                final classInfo = registeredClasses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text(classInfo['subject'],
                        style: GoogleFonts.ropaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${classInfo['day']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'From: ${classInfo['startTime']} - ${classInfo['endTime']}',
                          style: GoogleFonts.ropaSans(fontSize: 14),
                        ),
                        Text(
                          'Location: ${classInfo['location']}',
                          style: GoogleFonts.ropaSans(fontSize: 14),
                        ),
                        Text(
                          'Room Number: ${classInfo['roomNumber']}',
                          style: GoogleFonts.ropaSans(fontSize: 14),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _removeClass(index);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
