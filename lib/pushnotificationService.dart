// pushnotificationService.dart - Updated for completely free solution
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Initialize push notifications
  static Future<void> initialize() async {
    // Request permission for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Get FCM token and save to user document
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 🆓 FREE SOLUTION: Check expiring items when app initializes
    await _checkExpiringItemsOnAppStart();
  }

  // 🆓 Check expiring items when app starts (FREE alternative to Cloud Scheduler)
  static Future<void> _checkExpiringItemsOnAppStart() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if we already checked today to avoid spam
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      final lastCheck = prefs.getString('last_expiry_check');

      if (lastCheck == today) {
        print('Already checked expiring items today');
        return;
      }

      print('Checking for expiring items on app start...');

      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));

      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'In-stock')
          .get();

      List<Map<String, dynamic>> expiringItems = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final expiryDateStr = data['expiryDate'] as String?;

        if (expiryDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          final daysLeft = expiryDate.difference(now).inDays;

          // Check if item expires in 3 days or less
          if (daysLeft >= 0 && daysLeft <= 3) {
            expiringItems.add({
              'name': data['name'] ?? 'Unknown Item',
              'daysLeft': daysLeft,
              'category': data['category'],
              'subcategory': data['subcategory'],
            });
          }
        }
      }

      // Send notifications for expiring items
      if (expiringItems.isNotEmpty) {
        await _sendExpiryNotifications(expiringItems);

        // Save that we checked today
        await prefs.setString('last_expiry_check', today);
        print('Sent ${expiringItems.length} expiry notifications');
      }

    } catch (e) {
      print('Error checking expiring items on app start: $e');
    }
  }

  // Send local notifications for expiring items
  static Future<void> _sendExpiryNotifications(List<Map<String, dynamic>> items) async {
    // Group items by urgency
    final todayItems = items.where((item) => item['daysLeft'] == 0).toList();
    final tomorrowItems = items.where((item) => item['daysLeft'] == 1).toList();
    final soonItems = items.where((item) => item['daysLeft'] > 1).toList();

    // Send notification for items expiring today
    if (todayItems.isNotEmpty) {
      await _showLocalNotification(
        title: todayItems.length == 1
            ? 'Item Expires Today!'
            : '${todayItems.length} Items Expire Today!',
        body: todayItems.length == 1
            ? '${todayItems[0]['name']} expires today. Use it now!'
            : '${todayItems.map((item) => item['name']).join(', ')} expire today.',
        payload: 'expiry_today',
      );
    }

    // Send notification for items expiring tomorrow
    if (tomorrowItems.isNotEmpty) {
      await _showLocalNotification(
        title: tomorrowItems.length == 1
            ? 'Item Expires Tomorrow'
            : '${tomorrowItems.length} Items Expire Tomorrow',
        body: tomorrowItems.length == 1
            ? '${tomorrowItems[0]['name']} expires tomorrow. Plan to use it!'
            : '${tomorrowItems.map((item) => item['name']).join(', ')} expire tomorrow.',
        payload: 'expiry_tomorrow',
      );
    }

    // Send notification for items expiring soon
    if (soonItems.isNotEmpty) {
      await _showLocalNotification(
        title: soonItems.length == 1
            ? 'Item Expiring Soon'
            : '${soonItems.length} Items Expiring Soon',
        body: soonItems.length == 1
            ? '${soonItems[0]['name']} expires in ${soonItems[0]['daysLeft']} days.'
            : '${soonItems.length} items expire in the next few days.',
        payload: 'expiry_soon',
      );
    }
  }

  // Save FCM token to user's Firestore document
  static Future<void> _saveFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    }
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    await _showLocalNotification(
      title: message.notification?.title ?? 'Expiry Alert',
      body: message.notification?.body ?? 'An item is about to expire',
      payload: message.data.toString(),
    );
  }

  // Show local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Notifications',
      channelDescription: 'Notifications for items about to expire',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Manual check (can be called from other parts of your app)
  static Future<void> manualExpiryCheck() async {
    await _checkExpiringItemsOnAppStart();
  }

  // Request notification permissions
  static Future<bool> requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}