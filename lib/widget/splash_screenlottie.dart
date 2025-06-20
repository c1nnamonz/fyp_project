import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/auth/welcome_screen.dart';
import 'package:fyp_project/auth/login_screen.dart';
import 'package:fyp_project/household/rootPageHH.dart';
import 'package:lottie/lottie.dart';

class SplashScreen2 extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen2> {
  @override
  void initState() {
    super.initState();
    _navigateToAppropriateScreen();
  }

  Future<void> _navigateToAppropriateScreen() async {
    // Wait for both the splash delay and the auth check
    await Future.delayed(Duration(milliseconds: 3400));

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, check their role
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'] as String? ?? 'Household';

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => role == 'Household'
                    ? RootPageHousehold()
                    : RootPageHousehold(), // Replace with RootPageCommercial when available
              ),
            );
          }
          return;
        }
      } catch (e) {
        print('Error checking user role: $e');
        // Fall through to welcome screen if there's an error
      }
    }

    // If not logged in or any error occurs, go to welcome screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Transform.scale(
              scale: 1.2,
              child: Lottie.asset("images/splash2.json"),
            ),
          ),
        ],
      ),
    );
  }
}