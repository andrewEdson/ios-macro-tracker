# Macro Tracker

iOS app for tracking daily macros (carbs, protein, fat) with meal logging and barcode scanning.

## Firebase setup

1. Create a project at [Firebase Console](https://console.firebase.google.com).
2. Add an iOS app with bundle ID `Andrew.Macro-Tracker`.
3. Download `GoogleService-Info.plist` and add it to the **Macro Tracker** target (drag into the project in Xcode and ensure "Copy items if needed" and the app target are checked).
4. Enable **Authentication** > Email/Password in the Firebase Console.
5. Create a Firestore database (Start in test mode for development).

Without `GoogleService-Info.plist`, the app will crash at launch when calling `FirebaseApp.configure()`.

## Building

Open `Macro Tracker.xcodeproj` in Xcode. Resolve Swift packages (File > Packages > Resolve Package Versions) then build and run.
