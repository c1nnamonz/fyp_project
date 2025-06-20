import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/auth/welcome_screen.dart';
import 'package:fyp_project/household/ItemListHH.dart';
import 'package:fyp_project/household/homePageHH.dart';
import 'package:fyp_project/household/notificationHH.dart';
import 'package:fyp_project/household/profileHH.dart';
import 'package:fyp_project/household/recipeSuggestion.dart';
import 'package:fyp_project/household/reportPage.dart';
import 'package:fyp_project/household/scanPageHH.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:page_transition/page_transition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/auth/login_screen.dart';

import 'expiringSoonHH.dart';

class RootPageHousehold extends StatefulWidget {
  const RootPageHousehold({super.key});

  @override
  State<RootPageHousehold> createState() => RootPageHouseholdState();
}

class RootPageHouseholdState extends State<RootPageHousehold> {
  int bottomNavIndex = 0;

  //List of pages
  List<Widget> pages = const [
    HomePageHousehold(),
    ItemListHousehold(),
    ReportPage(),
    ProfileHousehold(),
  ];

  List<IconData> iconList = [
    Icons.home,
    Icons.list_alt,
    Icons.edit_note,
    Icons.person,
  ];

  List<String> titleList = [
    'Home',
    'Item List',
    'Analytics',
    'Profile',
  ];

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen and remove all previous routes
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

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationHousehold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titleList[bottomNavIndex],
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 24,
              ),
            ),
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.black45, size: 27.0),
              onPressed: _navigateToNotifications,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: IndexedStack(
        index: bottomNavIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            PageTransition(
              child: const ScanPageHousehold(),
              type: PageTransitionType.bottomToTop,
            ),
          );
        },
        child: Image.asset('images/camera2.png', height: 30.0),
        backgroundColor: lightColorScheme.primary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar(
        splashColor: lightColorScheme.primary,
        activeColor: lightColorScheme.primary,
        inactiveColor: Colors.black.withOpacity(.5),
        icons: iconList,
        activeIndex: bottomNavIndex,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.softEdge,
        onTap: (index) {
          setState(() {
            bottomNavIndex = index;
          });
        },
      ),
    );
  }
}