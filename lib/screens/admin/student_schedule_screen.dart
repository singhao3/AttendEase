import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'location_picker_screen.dart';

class StudentScheduleScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentScheduleScreen({super.key, required this.studentId, required this.studentName});

  @override
  _StudentScheduleScreenState createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> weeklySchedule = {};

  @override
  void initState() {
    super.initState();
    fetchSchedule();
  }

  Future<void> fetchSchedule() async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(widget.studentId).get();
    if (userDoc.exists && userDoc.data() != null) {
      setState(() {
        weeklySchedule = userDoc.get('weeklySchedule') ?? {};
      });
    }
  }

  Future<void> updateSchedule() async {
    await _firestore.collection('users').doc(widget.studentId).update({
      'weeklySchedule': weeklySchedule,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule updated successfully.')),
    );
  }

  void _addClass(String day, Map<String, dynamic> classInfo) {
    setState(() {
      if (weeklySchedule[day] == null) {
        weeklySchedule[day] = [];
      }
      weeklySchedule[day].add(classInfo);
    });
  }

  void _editClass(String day, int index, Map<String, dynamic> updatedClassInfo) {
    setState(() {
      weeklySchedule[day][index] = updatedClassInfo;
    });
  }

  void _removeClass(String day, int index) {
    setState(() {
      weeklySchedule[day].removeAt(index);
      if (weeklySchedule[day].isEmpty) {
        weeklySchedule.remove(day);
      }
    });
  }

  Future<void> _pickTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  Future<void> _pickLocation(BuildContext context, TextEditingController controller) async {
    final String? pickedAddress = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );
    if (pickedAddress != null) {
      setState(() {
        controller.text = pickedAddress;
      });
    }
  }

  void _showClassDialog(String day, {int? index, Map<String, dynamic>? classInfo}) {
    final TextEditingController subjectController = TextEditingController(text: classInfo?['subject']);
    final TextEditingController timeController = TextEditingController(text: classInfo?['time']);
    final TextEditingController locationController = TextEditingController(text: classInfo?['location']);
    final TextEditingController placeController = TextEditingController(text: classInfo?['place']); 

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? 'Add Class' : 'Edit Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Time'),
                readOnly: true,
                onTap: () => _pickTime(context, timeController),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                readOnly: true,
                onTap: () => _pickLocation(context, locationController),
              ),
              TextField(
                controller: placeController,
                decoration: const InputDecoration(labelText: 'Place'), 
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final classInfo = {
                  'subject': subjectController.text,
                  'time': timeController.text,
                  'location': locationController.text,
                  'place': placeController.text, 
                };
                if (index == null) {
                  _addClass(day, classInfo);
                } else {
                  _editClass(day, index, classInfo);
                }
                Navigator.of(context).pop();
              },
              child: Text(index == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  List<String> _sortedDaysOfWeek() {
    const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    return daysOfWeek.where((day) => weeklySchedule.containsKey(day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName}\'s Schedule', style: GoogleFonts.ropaSans()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: updateSchedule,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: _sortedDaysOfWeek().map((day) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ExpansionTile(
              title: Text(day, style: GoogleFonts.ropaSans(fontSize: 18)),
              children: [
                ...List.generate(
                  weeklySchedule[day].length,
                  (index) {
                    final classInfo = weeklySchedule[day][index] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(classInfo['subject'], style: GoogleFonts.ropaSans(fontSize: 16)),
                      subtitle: Text(
                        'Time: ${classInfo['time']}\nLocation: ${classInfo['location']}\nPlace: ${classInfo['place']}', 
                        style: GoogleFonts.ropaSans(fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _showClassDialog(day, index: index, classInfo: classInfo);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _removeClass(day, index);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  title: TextButton(
                    onPressed: () {
                      _showClassDialog(day);
                    },
                    child: const Text('Add Class'),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showClassDialog('Monday'); 
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
