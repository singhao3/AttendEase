import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback retry;

  const ErrorState({super.key, required this.message, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: GoogleFonts.ropaSans(
              textStyle: TextStyle(
                fontSize: 16.sp,
                color: Colors.red,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: retry,
            child: Text('Retry', style: GoogleFonts.ropaSans()),
          ),
        ],
      ),
    );
  }
}
