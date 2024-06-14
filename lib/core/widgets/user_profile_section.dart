import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileSection extends StatelessWidget {
  final String? profileImageUrl;

  const UserProfileSection({super.key, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30.w,
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl!)
                : const AssetImage('assets/images/placeholder.jpg') as ImageProvider,
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                FirebaseAuth.instance.currentUser!.displayName ?? 'John Doe',
                style: GoogleFonts.ropaSans(
                  textStyle: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                FirebaseAuth.instance.currentUser!.email ?? 'john.doe@graduate.utm.my',
                style: GoogleFonts.ropaSans(
                  textStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
