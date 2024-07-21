import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:psm2_attendease/utils/date_utils.dart' as custom_date_utils;

class NotificationService {
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'class_reminders',
          channelName: 'Class Reminders',
          channelDescription: 'Notification channel for class reminders',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
      ],
      debug: true,
    );

    await requestNotificationPermissions();
  }

  static Future<void> requestNotificationPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> scheduleClassReminder(
      String subject, String classTime, DateTime scheduledTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int reminderTimeInMinutes = prefs.getInt('reminder_time') ?? 60;
    String notificationTitle =
        prefs.getString('notification_title') ?? 'Class Reminder';
    String notificationBodyTemplate = prefs.getString('notification_body') ??
        'Your class "{subject}" is scheduled soon.';

    final reminderTime =
        scheduledTime.subtract(Duration(minutes: reminderTimeInMinutes));
    String notificationBody =
        notificationBodyTemplate.replaceAll('{subject}', subject);

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: reminderTime.hashCode,
        channelKey: 'class_reminders',
        title: '$notificationTitle: $subject',
        body:
            '$notificationBody at $classTime on ${DateFormat('EEEE').format(scheduledTime)}',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: reminderTime),
    );
  }

  static Future<void> triggerTestNotification() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String notificationTitle =
        prefs.getString('notification_title') ?? 'Test Notification';
    String notificationBodyTemplate =
        prefs.getString('notification_body') ?? 'This is a test notification.';
    String notificationBody =
        notificationBodyTemplate.replaceAll('{subject}', 'Test Subject');

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().hashCode,
          channelKey: 'class_reminders',
          title: notificationTitle,
          body: notificationBody,
          notificationLayout: NotificationLayout.Default,
        ),
      );
      debugPrint("Test notification triggered successfully.");
    } catch (e) {
      debugPrint("Error triggering test notification: $e");
    }
  }

  static Future<void> rescheduleAllNotifications() async {
    // Clear all existing notifications
    await AwesomeNotifications().cancelAll();

    // Fetch the user's weekly schedule
    final userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> weeklySchedule = data['weeklySchedule'];

      // Reschedule the notifications for each class
      for (var entry in weeklySchedule.entries) {
        final day = entry.key;
        final classes = entry.value as List<dynamic>;

        for (var classInfo in classes) {
          final className = classInfo['subject'];
          final time = classInfo['time'];
          final scheduleDate =
              custom_date_utils.DateUtils.getNextClassDate(day, time);
          await scheduleClassReminder(className, time, scheduleDate);
        }
      }
    }
  }
}
