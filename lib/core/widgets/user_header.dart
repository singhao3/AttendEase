import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../helpers/firebase_helpers.dart';

class UserHeader extends StatefulWidget {
  final Color backgroundColor;

  const UserHeader({super.key, required this.backgroundColor});

  @override
  UserHeaderState createState() => UserHeaderState();
}

class UserHeaderState extends State<UserHeader> {
  String? profileImageUrl;
  final FirebaseHelpers firebaseHelpers = FirebaseHelpers();

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    profileImageUrl = await firebaseHelpers.fetchUserProfileUrl();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return UserAccountsDrawerHeader(
      accountName: Text(
        FirebaseAuth.instance.currentUser?.displayName ?? 'John Doe',
        style: GoogleFonts.ropaSans(),
      ),
      accountEmail: Text(
        FirebaseAuth.instance.currentUser?.email ?? 'john.doe@graduate.utm.my',
        style: GoogleFonts.ropaSans(),
      ),
      currentAccountPicture: CircleAvatar(
        child: ClipOval(
          child: profileImageUrl != null
              ? FadeInImage.assetNetwork(
                  placeholder: 'assets/images/placeholder.jpg',
                  image: profileImageUrl!,
                  imageErrorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/images/placeholder.jpg',
                      fit: BoxFit.cover,
                    );
                  },
                  fit: BoxFit.cover,
                  width: 90,
                  height: 90,
                )
              : Image.asset(
                  'assets/images/placeholder.jpg',
                  fit: BoxFit.cover,
                  width: 90,
                  height: 90,
                ),
        ),
      ),
      onDetailsPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileEditScreen(),
          ),
        );
      },
      decoration: BoxDecoration(
        color: widget.backgroundColor, // Use the color passed from the parent
      ),
    );
  }
}

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.ropaSans()),
      ),
      body: Center(
        child: Text(
          'Profile Editing Screen',
          style: GoogleFonts.ropaSans(
            textStyle: TextStyle(
              fontSize: 20.sp,
            ),
          ),
        ),
      ),
    );
  }
}
