import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class ReusableWidgets {
  static Color generateAvatarColor(String subject, String day, String time) {
    final random = Random((subject + day + time).hashCode);
    final hue = random.nextDouble() * 360;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.8).toColor();
  }

  static Future<void> launchLocation(String coordinates) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$coordinates');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  static Row buildClassTimeRow(String classTime) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.access_time, size: 18.sp, color: Colors.grey[600]),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            classTime,
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  static GestureDetector buildLocationRow(String location) {
    return GestureDetector(
      onTap: () => launchLocation(location),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.location_on, size: 18.sp, color: Colors.grey[600]),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              location,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.blue[700],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Row buildPlaceRow(String place) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.meeting_room, size: 18.sp, color: Colors.grey[600]),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            place,
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}
