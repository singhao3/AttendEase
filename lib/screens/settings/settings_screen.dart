import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:psm2_attendease/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _reminderTimeController = TextEditingController();
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderTimeController.text = _prefs?.getInt('reminder_time')?.toString() ?? '60';
    });
  }

  Future<void> _saveSettings() async {
    int reminderTime = int.tryParse(_reminderTimeController.text) ?? 60;
    bool success = await _prefs?.setInt('reminder_time', reminderTime) ?? false;

    if (success) {
      // Reschedule the notifications with the new settings
      await NotificationService.rescheduleAllNotifications();

      _showDialog('Success', 'Settings saved and notifications updated successfully!', DialogType.success);
    } else {
      _showDialog('Error', 'Failed to save settings. Please try again.', DialogType.error);
    }
  }

  void _showDialog(String title, String description, DialogType dialogType) {
    AwesomeDialog(
      context: context,
      dialogType: dialogType,
      animType: AnimType.rightSlide,
      title: title,
      desc: description,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reminder Time (minutes before class):'),
            const SizedBox(height: 8),
            TextField(
              controller: _reminderTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
