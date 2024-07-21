import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'location_picker_screen.dart';

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> tuitionClasses = {};
  String? selectedLevel;
  List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    DocumentSnapshot classesDoc =
        await _firestore.collection('admin').doc('tuitionClasses').get();
    if (classesDoc.exists && classesDoc.data() != null) {
      setState(() {
        tuitionClasses = classesDoc.get('classes') ?? {};
      });
    }
  }

  Future<void> updateClasses() async {
    try {
      await _firestore.collection('admin').doc('tuitionClasses').set({
        'classes': tuitionClasses,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classes updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update classes: $e')),
        );
      }
    }
  }

  void _addClass(String day, Map<String, dynamic> classInfo) {
    setState(() {
      
      if (tuitionClasses[selectedLevel][day] == null) {
        tuitionClasses[selectedLevel][day] = [];
      }
      tuitionClasses[selectedLevel][day].add(classInfo);
    });
  }

  void _editClass(
      String day, int index, Map<String, dynamic> updatedClassInfo) {
    setState(() {
      tuitionClasses[selectedLevel][day][index] = updatedClassInfo;
    });
  }

  void _removeClass(String day, int index) {
    setState(() {
      tuitionClasses[selectedLevel][day].removeAt(index);
      if (tuitionClasses[selectedLevel][day].isEmpty) {
        tuitionClasses[selectedLevel].remove(day);
      }
    });
  }

  void _changeClassDay(String oldDay, int index, String newDay) {
    setState(() {
      final classInfo = tuitionClasses[selectedLevel][oldDay][index];
      _removeClass(oldDay, index);
      _addClass(newDay, classInfo);
    });
  }

  Future<void> _pickTime(
      BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final localizations = MaterialLocalizations.of(context);
        controller.text =
            localizations.formatTimeOfDay(picked, alwaysUse24HourFormat: false);
      });
    }
  }

  Future<void> _pickLocation(
      BuildContext context,
      TextEditingController locationController,
      TextEditingController coordinatesController) async {
    final String? pickedLocation = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );
    if (pickedLocation != null) {
      final parts = pickedLocation.split('|');
      if (parts.length == 2) {
        setState(() {
          locationController.text = parts[0]; // Display address
          coordinatesController.text = parts[1]; // Store coordinates
        });
      }
    }
  }

  void _showClassDialog(String day,
      {int? index, Map<String, dynamic>? classInfo}) {
    final TextEditingController subjectController =
        TextEditingController(text: classInfo?['subject']);
    final TextEditingController startTimeController =
        TextEditingController(text: classInfo?['startTime']);
    final TextEditingController endTimeController =
        TextEditingController(text: classInfo?['endTime']);
    final TextEditingController locationController =
        TextEditingController(text: classInfo?['location']);
    final TextEditingController roomNumberController =
        TextEditingController(text: classInfo?['roomNumber']);
    final TextEditingController coordinatesController =
        TextEditingController(text: classInfo?['coordinates']);
    String selectedDay = day;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(index == null ? 'Add Class' : 'Edit Class'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: days.map((String day) {
                        return DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedDay = newValue!;
                        });
                      },
                    ),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    TextField(
                      controller: startTimeController,
                      decoration:
                          const InputDecoration(labelText: 'Start Time'),
                      readOnly: true,
                      onTap: () => _pickTime(context, startTimeController),
                    ),
                    TextField(
                      controller: endTimeController,
                      decoration: const InputDecoration(labelText: 'End Time'),
                      readOnly: true,
                      onTap: () => _pickTime(context, endTimeController),
                    ),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                      readOnly: true,
                      onTap: () => _pickLocation(
                          context, locationController, coordinatesController),
                    ),
                    TextField(
                      controller: roomNumberController,
                      decoration:
                          const InputDecoration(labelText: 'Room Number'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedLevel == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Select a valid level')),
                      );
                      return;
                    }
                    if (subjectController.text.isEmpty ||
                        startTimeController.text.isEmpty ||
                        endTimeController.text.isEmpty ||
                        locationController.text.isEmpty ||
                        roomNumberController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('All fields are required.')),
                      );
                      return;
                    }
                    final classInfo = {
                      'subject': subjectController.text,
                      'startTime': startTimeController.text,
                      'endTime': endTimeController.text,
                      'location': locationController.text,
                      'roomNumber': roomNumberController.text,
                      'coordinates': coordinatesController.text,
                    };
                    if (index == null) {
                      _addClass(selectedDay, classInfo);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Class added successfully')),
                      );
                    } else {
                      if (selectedDay != day) {
                        _changeClassDay(day, index, selectedDay);
                      }
                      _editClass(selectedDay, index, classInfo);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Class updated successfully')),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(index == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Classes', style: GoogleFonts.ropaSans()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: updateClasses,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: selectedLevel,
              decoration: const InputDecoration(
                labelText: 'Select Level',
                border: OutlineInputBorder(),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  selectedLevel = newValue!;
                });
              },
              items: <String>['Form 4', 'Form 5']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: days.map((day) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    title: Text(day, style: GoogleFonts.ropaSans(fontSize: 18)),
                    children: [
                      ...(tuitionClasses[selectedLevel]?[day] ?? [])
                          .map<Widget>((classInfo) {
                        final int index =
                            (tuitionClasses[selectedLevel]?[day] ?? [])
                                .indexOf(classInfo);
                        return ListTile(
                          title: Text(classInfo['subject'],
                              style: GoogleFonts.ropaSans(fontSize: 16)),
                          subtitle: Text(
                            'Time: ${classInfo['startTime']} - ${classInfo['endTime']}\nLocation: ${classInfo['location']}\nRoom Number: ${classInfo['roomNumber']}',
                            style: GoogleFonts.ropaSans(fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showClassDialog(day,
                                      index: index, classInfo: classInfo);
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _removeClass(day, index);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Class deleted successfully')),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      ListTile(
                        title: ElevatedButton.icon(
                          onPressed: () {
                            _showClassDialog(day);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Class'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
