# AttendEase
AttendEase is a mobile facial recognition-based attendance system designed specifically for tuition centers. This application allows students to mark their attendance using facial recognition and geotagging technology, while administrators can manage attendance records, generate reports, and configure system settings efficiently.

# Features
- **Facial Recognition Attendance:** Students can mark their attendance by taking a selfie.
- **Geotagging:** Ensures students are within the designated attendance zone.
- **Manage Tuition Classes:** Administrators can add, edit, or delete classes.
- **Generate Reports:** Generate detailed attendance reports for specific periods.
- **Notifications:** Push notifications for upcoming classes and important updates.
- **User Management:** Easy registration and login for students and administrators.
- **System Configuration:** Administrators can customize notification settings and attendance thresholds.

# Installation
To run this project locally, follow these steps:

## Clone the repository:
```
git clone https://github.com/yourusername/attendease.git
cd attendease
```

## Install dependencies:
```
flutter pub get
```

## Set up Firebase:

### Option 1: Use Existing Firebase Configuration: 
The repository already contains the Firebase configuration files (google-services.json and GoogleService-Info.plist), so you can directly access the Firebase project. Use the following admin credentials to log in:
> Email: tiesinghao3300@gmail.com

> Password: Password123!

### Option 2: Create Your Own Firebase Configuration:
1. Go to the Firebase Console.
2. Create a new project.
3. Add an Android app to your project and follow the instructions to download the google-services.json file.
4. Replace the existing android/app/google-services.json file with your downloaded file.
5. Update the Firebase configuration in your Flutter project as needed.

## Run the app 
### (a physical Android device is recommended to test the facial recognition feature of the app):
```
flutter run
```

## Screenshots
### Admin Side
<img src="https://github.com/user-attachments/assets/6af2c769-32f5-4a01-aa03-150d3e15b32e" width="150">
<img src="https://github.com/user-attachments/assets/71f2f1a5-7d8f-48a0-a508-9f3780f65c0b" width="150">
<img src="https://github.com/user-attachments/assets/a2c174c3-630e-4cbe-9265-0172696ef418" width="150">
<img src="https://github.com/user-attachments/assets/d347e2f6-71fe-4d56-9448-7ed50965c4be" width="150">
<img src="https://github.com/user-attachments/assets/47148144-5564-4a7e-aecf-1d9105854fb0" width="150">
<img src="https://github.com/user-attachments/assets/6a5f2509-bc82-45ed-93b7-e54e804e9492" width="150">

### Student Side
<img src="https://github.com/user-attachments/assets/06e68744-b8d6-4c9e-8732-c1985db7d2cb" width="150">
<img src="https://github.com/user-attachments/assets/98a349c3-e67d-4360-98c4-32c30b011998" width="150">
<img src="https://github.com/user-attachments/assets/0df2cf87-dae5-461c-80c9-b46939a4d85f" width="150">
<img src="https://github.com/user-attachments/assets/8b76fc3b-5ffa-4bec-b080-396251715846" width="150">
<img src="https://github.com/user-attachments/assets/619f3f7f-46c9-4d68-aef9-0c2ef3fd0574" width="150">
<img src="https://github.com/user-attachments/assets/a8d6ba60-c636-4f8f-8084-0ededb9683dd" width="150">
<img src="https://github.com/user-attachments/assets/5eb7f7a2-a25f-432b-b6ca-ec3748ecb17b" width="150">
<img src="https://github.com/user-attachments/assets/bcfcd2e7-fe17-4512-b031-199a77c3ca3b" width="150">
<img src="https://github.com/user-attachments/assets/5f769351-1679-4fe9-88a2-4912aa16f368" width="150">
