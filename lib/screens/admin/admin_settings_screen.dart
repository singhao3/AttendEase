import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final TextEditingController _presentThresholdController =
      TextEditingController();
  final TextEditingController _notificationTitleController =
      TextEditingController();
  final TextEditingController _notificationBodyController =
      TextEditingController();
  final TextEditingController _thresholdDistanceController =
      TextEditingController();

  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _presentThresholdController.text =
          _prefs?.getInt('present_threshold')?.toString() ?? '0';
      _notificationTitleController.text =
          _prefs?.getString('notification_title') ?? 'Class Reminder';
      _notificationBodyController.text =
          _prefs?.getString('notification_body') ??
              'Your class "{subject}" is scheduled soon.';
      _thresholdDistanceController.text =
          _prefs?.getInt('threshold_distance')?.toString() ?? '50';
    });
  }

  Future<void> _saveSettings() async {
    String? errorMessage;

    int? presentThreshold = int.tryParse(_presentThresholdController.text);
    if (presentThreshold == null || presentThreshold < 0) {
      errorMessage = 'Invalid Present Threshold value.';
    }

    int? thresholdDistance = int.tryParse(_thresholdDistanceController.text);
    if (thresholdDistance == null || thresholdDistance < 0) {
      errorMessage = 'Invalid Threshold Distance value.';
    }

    String notificationTitle = _notificationTitleController.text;
    if (notificationTitle.isEmpty) {
      errorMessage = 'Notification Title cannot be empty.';
    }

    String notificationBody = _notificationBodyController.text;
    if (notificationBody.isEmpty) {
      errorMessage = 'Notification Body cannot be empty.';
    }

    if (errorMessage != null) {
      _showDialog('Error', errorMessage, DialogType.error);
      return;
    }

    bool success =
        await _prefs?.setInt('present_threshold', presentThreshold!) ?? false;
    success = success &&
        (await _prefs?.setInt('threshold_distance', thresholdDistance!) ??
            false);
    success = success &&
        (await _prefs?.setString('notification_title', notificationTitle) ??
            false);
    success = success &&
        (await _prefs?.setString('notification_body', notificationBody) ??
            false);

    if (success) {
      _showDialog(
          'Success', 'Settings saved successfully!', DialogType.success);
    } else {
      _showDialog('Error', 'Failed to save settings. Please try again.',
          DialogType.error);
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
  void dispose() {
    _presentThresholdController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    _thresholdDistanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thresholds for Attendance:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Set the thresholds for marking attendance. These values determine how attendance is classified as Present or Late based on the time a student marks their attendance relative to the class start time.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildThresholdField(
              label: 'Present Threshold (minutes)',
              controller: _presentThresholdController,
              tooltip:
                  'The maximum number of minutes after the class start time during which a student can mark their attendance as "Present".',
            ),
            const SizedBox(height: 20),
            _buildThresholdField(
              label: 'Threshold Distance (meters)',
              controller: _thresholdDistanceController,
              tooltip:
                  'The distance in meters within which a student needs to be to mark their attendance.',
            ),
            const SizedBox(height: 40),
            const Text(
              'Notification Settings:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              label: 'Notification Title',
              controller: _notificationTitleController,
              tooltip: 'The title of the notification for class reminders.',
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Notification Body',
              controller: _notificationBodyController,
              tooltip:
                  'The body text of the notification for class reminders. Use {subject} as a placeholder for the class subject.',
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                ),
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdField({
    required String label,
    required TextEditingController controller,
    required String tooltip,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: tooltip,
          onPressed: () {
            final dynamic tooltipState = Tooltip(
              message: tooltip,
            ).createState();
            tooltipState.ensureTooltipVisible();
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String tooltip,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: tooltip,
          onPressed: () {
            final dynamic tooltipState = Tooltip(
              message: tooltip,
            ).createState();
            tooltipState.ensureTooltipVisible();
          },
        ),
      ),
    );
  }
}
