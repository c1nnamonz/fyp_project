import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
// 🚀 Import your push notification service
import '../pushnotificationService.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign up with email and password
  static Future<User?> signUpWithEmailAndPassword(
      String email, String password, String fullName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user data to Firestore
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'fullName': fullName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'signInMethod': 'email',
        'fcmTokens': [], // Initialize empty FCM tokens array
      });

      // 🔔 Notify push notification service about user change
      await PushNotificationService.onUserChanged();

      return userCredential.user;
    } catch (e) {
      print("Sign up error: $e");
      return null;
    }
  }

  // Sign in with email and password
  static Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔔 Notify push notification service about user change
      await PushNotificationService.onUserChanged();

      return userCredential.user;
    } catch (e) {
      print("Sign in error: $e");
      return null;
    }
  }

  // Sign in with Google
  static Future<User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credentials
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user and save their data
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'fullName': userCredential.user?.displayName ?? '',
          'email': userCredential.user?.email ?? '',
          'photoURL': userCredential.user?.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'signInMethod': 'google',
          'fcmTokens': [], // Initialize empty FCM tokens array
        });
      }

      // 🔔 Notify push notification service about user change
      await PushNotificationService.onUserChanged();

      return userCredential.user;
    } catch (e) {
      print("Google sign in error: $e");
      return null;
    }
  }

  // Sign out from both Firebase and Google
  static Future<void> signOut() async {
    try {
      // 🔔 Notify push notification service BEFORE signing out
      await PushNotificationService.onUserChanged();

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print("Sign out error: $e");
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Password reset error: $e");
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  // Check if user is currently signed in
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user stream for real-time updates
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Delete user-specific notification data
        await PushNotificationService.clearNotificationHistory();

        // Delete user data from Firestore
        await _firestore.collection('users').doc(user.uid).delete();

        // Sign out from Google if signed in with Google
        await _googleSignIn.signOut();

        // Delete the user account
        await user.delete();
      }
    } catch (e) {
      print("Delete account error: $e");
      rethrow;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);

        // Update Firestore document as well
        await _firestore.collection('users').doc(user.uid).update({
          if (displayName != null) 'fullName': displayName,
          if (photoURL != null) 'photoURL': photoURL,
        });
      }
    } catch (e) {
      print("Update profile error: $e");
      rethrow;
    }
  }

  // Verify email
  static Future<void> sendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print("Send email verification error: $e");
      rethrow;
    }
  }

  // 🆕 NEW: Additional helper methods for push notifications

  // Force expiry check for current user (useful for testing)
  static Future<void> forceExpiryCheck() async {
    await PushNotificationService.forceExpiryCheck();
  }

  // Manual expiry check for current user
  static Future<void> checkExpiringItems() async {
    await PushNotificationService.manualExpiryCheck();
  }

  // Clean up old notification data (call periodically)
  static Future<void> cleanupNotificationData() async {
    await PushNotificationService.cleanupOldUserData();
  }

  // Request notification permission
  static Future<bool> requestNotificationPermission() async {
    return await PushNotificationService.requestPermission();
  }
}