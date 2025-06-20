import 'package:flutter/material.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/auth/welcome_screen.dart';
import '../widget/profile_widget.dart';

class ProfileHousehold extends StatefulWidget {
  const ProfileHousehold({super.key});

  @override
  State<ProfileHousehold> createState() => _ProfileHouseholdState();
}

class _ProfileHouseholdState extends State<ProfileHousehold> {
  String _userName = 'Loading...';
  String _userEmail = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['fullName'] ?? 'User';
            _userEmail = user.email ?? 'No email';
            _isLoading = false;
          });
        } else {
          // If user document doesn't exist, use auth email
          setState(() {
            _userName = 'User';
            _userEmail = user.email ?? 'No email';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _userName = 'Error loading name';
        _userEmail = 'Error loading email';
        _isLoading = false;
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to welcome screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  void _handleProfileWidgetTap(String title) {
    switch (title) {
      case 'My Profile':
      // TODO: Navigate to profile editing screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('My Profile clicked')),
        );
        break;
      case 'FAQs':
      // TODO: Navigate to FAQs screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FAQs clicked')),
        );
        break;
      case 'Logout':
        _showLogoutDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          height: size.height,
          width: size.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 170,
                child: const CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.transparent,
                  backgroundImage: ExactAssetImage('images/profile.jpg'),
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: lightColorScheme.primary.withOpacity(.5),
                    width: 5.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 5.0),
                      child: Text(
                        _userName,
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(
                        height: 24,
                        child: Image.asset("images/verified.png")),
                  ],
                ),
              ),
              _isLoading
                  ? const SizedBox()
                  : Text(
                _userEmail,
                style: TextStyle(
                  color: Colors.black45.withOpacity(.3),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: size.height * .7,
                width: size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _handleProfileWidgetTap('My Profile'),
                      child: const ProfileWidget(
                        icon: Icons.person,
                        title: 'My Profile',
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _handleProfileWidgetTap('FAQs'),
                      child: const ProfileWidget(
                        icon: Icons.chat,
                        title: 'FAQs',
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _handleProfileWidgetTap('Logout'),
                      child: const ProfileWidget(
                        icon: Icons.logout_outlined,
                        title: 'Logout',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}