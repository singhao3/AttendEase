import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:psm2_attendease/helpers/extensions.dart';
import '../../routing/routes.dart';

class SignOut {
  static Future<void> signOut(BuildContext context) async {
    try {
      await _disconnectGoogle();
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.pushNamedAndRemoveUntil(
          Routes.loginScreen,
          predicate: (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await _showSignOutErrorDialog(context, e.toString());
      }
    }
  }

  static Future<void> _disconnectGoogle() async {
    try {
      await GoogleSignIn().disconnect();
    } catch (e) {
      // Log the error but proceed with the sign-out
      debugPrint('Failed to disconnect Google: $e');
    }
  }

  static Future<void> _showSignOutErrorDialog(BuildContext context, String message) async {
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.rightSlide,
      title: 'Sign out error',
      desc: message,
    ).show();
  }
}
