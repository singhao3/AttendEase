// ignore_for_file: public_member_api_docs, sort_constructors_first, constant_identifier_names, use_build_context_synchronously, implementation_imports
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:psm2_attendease/services/ml_service.dart';
import 'package:psm2_attendease/theming/colors.dart';
import 'package:rive/rive.dart';

import '../../../helpers/app_regex.dart';
import '../../../routing/routes.dart';
import '../../../theming/styles.dart';
import '../../helpers/extensions.dart';
import '../../helpers/firebase_helpers.dart';
import '../../../core/widgets/camera_widget.dart';
import 'app_text_button.dart';
import 'app_text_form_field.dart';
import 'password_validations.dart';

enum Animations {
  idle,
  Hands_up,
  hands_down,
  success,
  fail,
  Look_down_right,
  Look_down_left,
}

// ignore: must_be_immutable
class EmailAndPassword extends StatefulWidget {
  final bool? isSignUpPage;
  final bool? isPasswordPage;
  late GoogleSignInAccount? googleUser;
  late OAuthCredential? credential;
  final MLService? mlService;
  EmailAndPassword({
    super.key,
    this.isSignUpPage,
    this.isPasswordPage,
    this.googleUser,
    this.credential,
    this.mlService,
  });

  @override
  State<EmailAndPassword> createState() => _EmailAndPasswordState();
}

class _EmailAndPasswordState extends State<EmailAndPassword> {
  bool isObscureText = true;
  bool hasLowercase = false;
  bool hasUppercase = false;
  late final _auth = FirebaseAuth.instance;

  bool hasSpecialCharacters = false;
  bool hasNumber = false;
  bool hasMinLength = false;
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController passwordConfirmationController =
      TextEditingController();
  TextEditingController contactNumberController = TextEditingController();
  String? selectedLevel;
  List<String> selectedClasses = [];
  List<Map<String, dynamic>> availableClasses = [];
  XFile? profileImage;
  final formKey = GlobalKey<FormState>();
  Artboard? riveArtboard;
  late RiveAnimationController controllerIdle;
  late RiveAnimationController controllerHandsUp;
  late RiveAnimationController controllerHandsDown;
  late RiveAnimationController controllerSuccess;
  late RiveAnimationController controllerFail;
  late RiveAnimationController controllerLookDownRight;
  late RiveAnimationController controllerLookDownLeft;
  final passwordFocuseNode = FocusNode();
  final passwordConfirmationFocuseNode = FocusNode();

  bool isLookingRight = false;
  bool isLookingLeft = false;

  @override
  void initState() {
    controllerIdle = SimpleAnimation(Animations.idle.name);
    controllerHandsUp = SimpleAnimation(Animations.Hands_up.name);
    controllerHandsDown = SimpleAnimation(Animations.hands_down.name);
    controllerSuccess = SimpleAnimation(Animations.success.name);
    controllerFail = SimpleAnimation(Animations.fail.name);
    controllerLookDownRight = SimpleAnimation(Animations.Look_down_right.name);
    controllerLookDownLeft = SimpleAnimation(Animations.Look_down_left.name);
    rootBundle.load('assets/login_animation.riv').then((data) {
      final file = RiveFile.import(data);
      final artboard = file.mainArtboard;
      artboard.addController(controllerIdle);
      setState(() {
        riveArtboard = artboard;
      });
    });
    super.initState();
    setupPasswordControllerListener();
    checkForPasswordFocused();
    checkForPasswordConfirmationFocused();
  }

  void removeAllControllers() {
    final listOfControllers = [
      controllerIdle,
      controllerHandsUp,
      controllerHandsDown,
      controllerSuccess,
      controllerFail,
      controllerLookDownRight,
      controllerLookDownLeft,
    ];
    for (RiveAnimationController controller in listOfControllers) {
      riveArtboard!.removeController(controller);
    }
    isLookingLeft = false;
    isLookingRight = false;

    listOfControllers.clear();
  }

  void addIdleController() {
    removeAllControllers();
    riveArtboard!.addController(controllerIdle);
  }

  void addHandsUpController() {
    removeAllControllers();
    riveArtboard!.addController(controllerHandsUp);
  }

  void addHandsDownController() {
    removeAllControllers();
    riveArtboard!.addController(controllerHandsDown);
  }

  void addSuccessController() {
    removeAllControllers();
    riveArtboard!.addController(controllerSuccess);
  }

  void addFailController() {
    removeAllControllers();
    riveArtboard!.addController(controllerFail);
  }

  void addDownRightController() {
    removeAllControllers();
    riveArtboard!.addController(controllerLookDownRight);
    isLookingRight = true;
  }

  void addDownLeftController() {
    removeAllControllers();
    riveArtboard!.addController(controllerLookDownLeft);
    isLookingLeft = true;
  }

  void checkForPasswordFocused() {
    passwordFocuseNode.addListener(() {
      if (passwordFocuseNode.hasFocus && isObscureText) {
        addHandsUpController();
      } else if (!passwordFocuseNode.hasFocus && isObscureText) {
        addHandsDownController();
      }
    });
  }

  void checkForPasswordConfirmationFocused() {
    passwordConfirmationFocuseNode.addListener(() {
      if (passwordConfirmationFocuseNode.hasFocus && isObscureText) {
        addHandsUpController();
      } else if (!passwordConfirmationFocuseNode.hasFocus && isObscureText) {
        addHandsDownController();
      }
    });
  }

  void setupPasswordControllerListener() {
    passwordController.addListener(() {
      setState(() {
        hasLowercase = AppRegex.hasLowerCase(passwordController.text);
        hasUppercase = AppRegex.hasUpperCase(passwordController.text);
        hasSpecialCharacters =
            AppRegex.hasSpecialCharacter(passwordController.text);
        hasNumber = AppRegex.hasNumber(passwordController.text);
        hasMinLength = AppRegex.hasMinLength(passwordController.text);
      });
    });
  }

  Future<void> fetchAvailableClasses(String level, BuildContext context) async {
    DocumentSnapshot classesDoc = await FirebaseFirestore.instance
        .collection('admin')
        .doc('tuitionClasses')
        .get();

    if (classesDoc.exists && classesDoc.data() != null) {
      var data = classesDoc.get('classes')[level] ?? {};
      List<Map<String, dynamic>> fetchedClasses = [];

      data.forEach((day, classes) {
        for (var classInfo in classes) {
          fetchedClasses.add({
            ...classInfo,
            'day': day,
          });
        }
      });

      setState(() {
        availableClasses = fetchedClasses;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No classes found for the selected level'),
          duration: Duration(seconds: 2), // Adjust duration as needed
        ),
      );
    }
  }

  Widget forgetPasswordTextButton(BuildContext context) {
    if (widget.isSignUpPage == null && widget.isPasswordPage == null) {
      return TextButton(
        onPressed: () {
          context.pushNamed(Routes.forgetScreen);
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Forget Password?',
            style: TextStyles.font14Blue400Weight,
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  loginOrSignUpOrPasswordButton(BuildContext context) {
    if (widget.isSignUpPage == true) {
      return signUpButton(context);
    }
    if (widget.isSignUpPage == null && widget.isPasswordPage == null) {
      return loginButton(context);
    }
    if (widget.isPasswordPage == true) {
      return passwordButton(context);
    }
  }

  AppTextButton signUpButton(BuildContext context) {
    final FirebaseHelpers firebaseHelpers = FirebaseHelpers();

    return AppTextButton(
      buttonText: "Create Account",
      textStyle: TextStyles.font16White600Weight,
      onPressed: () async {
        passwordFocuseNode.unfocus();
        passwordConfirmationFocuseNode.unfocus();
        if (formKey.currentState!.validate()) {
          if (profileImage == null) {
            await AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.rightSlide,
              title: 'Profile Picture Required',
              desc: 'Please upload a profile picture to continue.',
            ).show();
            return;
          }
          try {
            List? faceData;
            if (widget.mlService != null) {
              final imageBytes = await profileImage!.readAsBytes();
              debugPrint("Image bytes length: ${imageBytes.length}");
              faceData = await widget.mlService!
                  .validateAndExtractFaceData(imageBytes);
              debugPrint("Face data extracted successfully");
            }

            await _auth.createUserWithEmailAndPassword(
              email: emailController.text,
              password: passwordController.text,
            );
            await _auth.currentUser!.updateDisplayName(nameController.text);

            String profileUrl =
                await firebaseHelpers.uploadProfilePicture(profileImage);

            await firebaseHelpers.saveUserDataToFirestore(
              name: nameController.text,
              email: emailController.text,
              contactNumber: contactNumberController.text,
              profileUrl: profileUrl,
              faceData: faceData,
              level: selectedLevel,
              selectedClasses: selectedClasses,
            );

            await _auth.currentUser!.sendEmailVerification();
            await _auth.signOut();

            await AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.rightSlide,
              title: 'Sign up Success',
              desc: 'Don\'t forget to verify your email check inbox.',
            ).show();

            addSuccessController();
            await Future.delayed(const Duration(seconds: 2));
            removeAllControllers();

            if (!mounted) return;

            context.pushNamedAndRemoveUntil(
              Routes.loginScreen,
              predicate: (route) => false,
            );
          } catch (e) {
            addFailController();

            if (!mounted) return;

            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.rightSlide,
              title: 'Error',
              desc: e.toString(),
            ).show();
          }
        }
      },
    );
  }

  Widget studentLevelDropdown() {
    if (widget.isSignUpPage == true) {
      return DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Select Level'),
        value: selectedLevel,
        onChanged: (String? value) {
          setState(() {
            selectedLevel = value;
            fetchAvailableClasses(value!, context);
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            addFailController();
            return 'Please select a level';
          }
          return null;
        },
        items: <String>[
          'Form 4',
          'Form 5',
        ].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget classSelectionWidget() {
    if (selectedLevel != null && availableClasses.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Classes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...availableClasses.map((classInfo) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CheckboxListTile(
                  title: Text(
                    classInfo['subject'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day: ${classInfo['day'] ?? ''}'),
                      Text(
                          'Time: ${classInfo['startTime'] ?? ''} - ${classInfo['endTime'] ?? ''}'),
                      Text('Location: ${classInfo['location'] ?? ''}'),
                      Text('Room Number: ${classInfo['roomNumber'] ?? ''}'),
                    ],
                  ),
                  value: selectedClasses.contains(classInfo['subject']),
                  activeColor: ColorsManager.mainBlue,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedClasses.add(classInfo['subject']);
                      } else {
                        selectedClasses.remove(classInfo['subject']);
                      }
                    });
                  },
                ),
              ),
            );
          }),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  AppTextButton loginButton(BuildContext context) {
    return AppTextButton(
      buttonText: 'Login',
      textStyle: TextStyles.font16White600Weight,
      onPressed: () async {
        passwordFocuseNode.unfocus();

        if (formKey.currentState!.validate()) {
          try {
            final c = await _auth.signInWithEmailAndPassword(
              email: emailController.text,
              password: passwordController.text,
            );
            final userRole = await FirebaseFirestore.instance
                .collection('users')
                .doc(c.user!.uid)
                .get()
                .then((doc) => doc.data()?['role']);

            if (c.user!.emailVerified || userRole == 'admin') {
              addSuccessController();
              await Future.delayed(const Duration(seconds: 2));
              removeAllControllers();
              if (!context.mounted) return;

              if (userRole == 'admin') {
                context.pushNamedAndRemoveUntil(
                  Routes.adminHomeScreen,
                  predicate: (route) => false,
                );
              } else {
                context.pushNamedAndRemoveUntil(
                  Routes.homeScreen,
                  predicate: (route) => false,
                );
              }
            } else {
              await _auth.signOut();
              addFailController();
              if (!context.mounted) return;

              AwesomeDialog(
                context: context,
                dialogType: DialogType.info,
                animType: AnimType.rightSlide,
                title: 'Email Not Verified',
                desc: 'Please check your email and verify your email.',
              ).show();
            }
          } on FirebaseAuthException catch (e) {
            addFailController();

            if (e.code == 'user-not-found') {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.rightSlide,
                title: 'FireBase Error',
                desc: 'No user found for that email.',
              ).show();
            } else if (e.code == 'wrong-password') {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.rightSlide,
                title: 'Error',
                desc: 'Wrong password provided for that user.',
              ).show();
            } else {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.rightSlide,
                title: 'Error',
                desc: e.message,
              ).show();
            }
          }
        }
      },
    );
  }

  AppTextButton passwordButton(BuildContext context) {
    return AppTextButton(
      buttonText: 'Create Password',
      textStyle: TextStyles.font16White600Weight,
      onPressed: () async {
        passwordFocuseNode.unfocus();
        passwordConfirmationFocuseNode.unfocus();
        if (formKey.currentState!.validate()) {
          try {
            await _auth.createUserWithEmailAndPassword(
              email: widget.googleUser!.email,
              password: passwordController.text,
            );

            await _auth.currentUser!.linkWithCredential(widget.credential!);
            await _auth.currentUser!
                .updateDisplayName(widget.googleUser!.displayName);
            await _auth.currentUser!
                .updatePhotoURL(widget.googleUser!.photoUrl);
            if (!context.mounted) return;
            await AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.rightSlide,
              title: 'Sign up Success',
              desc: 'You have successfully signed up.',
            ).show();

            addSuccessController();
            await Future.delayed(const Duration(seconds: 2));
            removeAllControllers();
            if (!context.mounted) return;

            context.pushNamedAndRemoveUntil(
              Routes.homeScreen,
              predicate: (route) => false,
            );
          } on FirebaseAuthException catch (e) {
            addFailController();

            if (e.code == 'email-already-in-use') {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.rightSlide,
                title: 'Error',
                desc:
                    'This account already exists for that email go and login.',
              ).show();
            } else {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.rightSlide,
                title: 'Error',
                desc: e.message,
              ).show();
            }
          } catch (e) {
            addFailController();

            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.rightSlide,
              title: 'Error',
              desc: e.toString(),
            ).show();
          }
        }
      },
    );
  }

  Widget emailField() {
    if (widget.isPasswordPage == null) {
      return Column(
        children: [
          AppTextFormField(
            hint: 'Email',
            onChanged: (value) {
              if (value.isNotEmpty && value.length <= 13 && !isLookingLeft) {
                addDownLeftController();
              } else if (value.isNotEmpty &&
                  value.length > 13 &&
                  !isLookingRight) {
                addDownRightController();
              }
            },
            validator: (value) {
              if (value == null ||
                  value.isEmpty ||
                  !AppRegex.isEmailValid(value)) {
                addFailController();
                return 'Please enter a valid email';
              }
            },
            controller: emailController,
          ),
          Gap(18.h),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget nameField() {
    if (widget.isSignUpPage == true) {
      return Column(
        children: [
          AppTextFormField(
            hint: 'Name',
            onChanged: (value) {
              if (value.isNotEmpty && value.length <= 13 && !isLookingLeft) {
                addDownLeftController();
              } else if (value.isNotEmpty &&
                  value.length > 13 &&
                  !isLookingRight) {
                addDownRightController();
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty || value.startsWith(' ')) {
                addFailController();
                return 'Please enter a valid name';
              }
            },
            controller: nameController,
          ),
          Gap(18.h),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  AppTextFormField passwordField() {
    return AppTextFormField(
      focusNode: passwordFocuseNode,
      controller: passwordController,
      hint: 'Password',
      isObscureText: isObscureText,
      suffixIcon: GestureDetector(
        onTap: () {
          setState(() {
            if (isObscureText) {
              isObscureText = false;
              addHandsDownController();
            } else {
              addHandsUpController();
              isObscureText = true;
            }
          });
        },
        child: Icon(
          isObscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.isEmpty ||
            !AppRegex.isPasswordValid(value)) {
          addFailController();
          return 'Please enter a valid password';
        }
      },
    );
  }

  Widget passwordConfirmationField() {
    if (widget.isSignUpPage == true || widget.isPasswordPage == true) {
      return AppTextFormField(
        focusNode: passwordConfirmationFocuseNode,
        controller: passwordConfirmationController,
        hint: 'Password Confirmation',
        isObscureText: isObscureText,
        suffixIcon: GestureDetector(
          onTap: () {
            setState(() {
              if (isObscureText) {
                isObscureText = false;
                addHandsDownController();
              } else {
                addHandsUpController();
                isObscureText = true;
              }
            });
          },
          child: Icon(
            isObscureText ? Icons.visibility_off : Icons.visibility,
          ),
        ),
        validator: (value) {
          if (value != passwordController.text) {
            addFailController();

            return 'Enter a matched passwords';
          }
          if (value == null ||
              value.isEmpty ||
              !AppRegex.isPasswordValid(value)) {
            addFailController();
            return 'Please enter a valid password';
          }
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget contactNumberField() {
    if (widget.isSignUpPage == true) {
      return AppTextFormField(
        controller: contactNumberController,
        hint: 'Contact Number',
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            addFailController();
            return 'Please enter your contact number';
          } else if (!RegExp(r'^\+?1?\d{9,15}$').hasMatch(value)) {
            addFailController();
            return 'Please enter a valid contact number';
          }
          return null;
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget profilePictureField(BuildContext context) {
    if (widget.isSignUpPage == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Capture Profile Picture',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final XFile? capturedImage = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraWidget()),
              );
              if (capturedImage != null) {
                setState(() {
                  profileImage = capturedImage;
                });
              }
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: profileImage == null
                    ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                    : Image.file(
                        File(profileImage!.path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height / 5,
            child: riveArtboard != null
                ? Rive(
                    fit: BoxFit.cover,
                    artboard: riveArtboard!,
                  )
                : const SizedBox.shrink(),
          ),
          nameField(),
          emailField(),
          passwordField(),
          Gap(18.h),
          passwordConfirmationField(),
          forgetPasswordTextButton(context),
          Gap(10.h),
          PasswordValidations(
            hasLowerCase: hasLowercase,
            hasUpperCase: hasUppercase,
            hasSpecialCharacters: hasSpecialCharacters,
            hasNumber: hasNumber,
            hasMinLength: hasMinLength,
          ),
          Gap(18.h),
          contactNumberField(),
          Gap(18.h),
          profilePictureField(context),
          Gap(18.h),
          studentLevelDropdown(),
          Gap(18.h),
          classSelectionWidget(),
          Gap(20.h),
          loginOrSignUpOrPasswordButton(context),
        ],
      ),
    );
  }

  @override
  void dispose() {
    contactNumberController.dispose();
    passwordController.dispose();
    passwordConfirmationController.dispose();
    emailController.dispose();
    nameController.dispose();
    removeAllControllers();
    controllerIdle.dispose();
    controllerHandsUp.dispose();
    controllerHandsDown.dispose();
    controllerSuccess.dispose();
    controllerFail.dispose();
    controllerLookDownRight.dispose();
    passwordFocuseNode.dispose();
    passwordConfirmationFocuseNode.dispose();
    controllerLookDownLeft.dispose();
    super.dispose();
  }
}
