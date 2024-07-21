import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import '../../theming/colors.dart';

class WeekendMessage extends StatelessWidget {
  const WeekendMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://lottie.host/11cc3045-6673-4699-9e9e-b6bec6ec994d/dSGyGiTKgS.json',
            width: 200,
            height: 200,
          ),
          SizedBox(height: 20.h),
          Text(
            'No classes today! Enjoy your weekend!',
            style: GoogleFonts.ropaSans(
              textStyle: TextStyle(
                fontSize: 20.sp,
                color: ColorsManager.mainBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
