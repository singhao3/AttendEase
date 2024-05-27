import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/widgets/app_text_button.dart';
import '../../../theming/colors.dart';

class ClassItem extends StatelessWidget {
  final String courseCode;
  final String courseName;
  final String time;
  final String status;

  const ClassItem({
    required Key key,
    required this.courseCode,
    required this.courseName,
    required this.time,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextStyle buttonTextStyle = TextStyle(
      color: Colors.white, 
      fontSize: 14.sp, // Using flutter_screenutil for responsive font size
    );

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: ThemeColors.getColorForCourse(courseCode),
        child: Text(courseCode),
      ),
      title: Text(courseName),
      subtitle: Text('$time - You are marked $status'),
      trailing: status == 'absent' ? Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextButton(
            buttonText: 'Mark Me Present',
            textStyle: buttonTextStyle,
            onPressed: () {
              // Implement action
            },
            backgroundColor: Colors.green, 
          ),
          AppTextButton(
            buttonText: 'Mark Me Absent',
            textStyle: buttonTextStyle,
            onPressed: () {
              // Implement action
            },
            backgroundColor: Colors.red, 
          ),
        ],
      ) : null,
    );
  }
}
