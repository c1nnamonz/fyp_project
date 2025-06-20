import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/pushnotificationService.dart';
import 'package:fyp_project/widget/splash_screen.dart';
import 'package:fyp_project/widget/splash_screenlottie.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb) {
    await Firebase.initializeApp(options: FirebaseOptions(
        apiKey: "AIzaSyAgiIe1xG9frt2XAuNm-QBttsRfEAYi3H4",
        authDomain: "fyp-project-a1d73.firebaseapp.com",
        projectId: "fyp-project-a1d73",
        storageBucket: "fyp-project-a1d73.firebasestorage.app",
        messagingSenderId: "1088962417125",
        appId: "1:1088962417125:web:d2ae593059baf490bedf0c"));
    await PushNotificationService.initialize();
  }else{
    await Firebase.initializeApp();
    await PushNotificationService.initialize();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'fypProject',
        debugShowCheckedModeBanner: false,
        home: SplashScreen2(),
    );
  }
}


