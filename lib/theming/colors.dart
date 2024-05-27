import 'package:flutter/material.dart';

class ColorsManager {
  static const Color mainBlue = Color(0xFF000080);
  static const Color gray = Color(0xFF757575);
  static const Color gray93Color = Color(0xFFEDEDED);
  static const Color gray76 = Color(0xFFC2C2C2);
  static const Color darkBlue = Color(0xFF242424);
  static const Color lightShadeOfGray = Color(0xFFFDFDFF);
  static const Color mediumLightShadeOfGray = Color(0xFF9E9E9E);
  static const Color coralRed = Color(0xFFFF4C5E);
}

class ThemeColors {
  static Color getColorForCourse(String courseCode) {
    switch (courseCode) {
      case 'M':
        return Colors.blueAccent; // Color for Mathematics
      case 'P':
        return Colors.greenAccent; // Color for Physics
      case 'B':
        return Colors.redAccent; // Color for Biology
      case 'G':
        return Colors.orangeAccent; // Color for Geography
      case 'C':
        return Colors.purpleAccent; // Color for Chemistry
      case 'H':
        return Colors.grey; // Color for History (Cancelled class)
      default:
        return Colors.black; // Default color if no match found
    }
  }
}