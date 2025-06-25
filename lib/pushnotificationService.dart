// Account-aware pushNotificationService.dart - Tracks per user
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static String? _lastCheckedUserId; // Track which user was last checked
  static bool _hasCheckedToday = false; // In-memory flag for current session

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

    // 🆓 ACCOUNT-AWARE: Check expiring items for current user
    await _checkExpiringItemsOnAppStart();
  }

  // 🆓 ACCOUNT-AWARE: Check per user, not just per device
  static Future<void> _checkExpiringItemsOnAppStart() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in, skipping expiry check');
        return;
      }

      final userId = user.uid;
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

      // Check if this is a different user than last time
      if (_lastCheckedUserId != userId) {
        print('Different user detected, resetting check flags');
        _hasCheckedToday = false;
        _lastCheckedUserId = userId;
      }

      // Skip if already checked in this app session for this user
      if (_hasCheckedToday) {
        print('Already checked expiring items for user $userId in this session');
        return;
      }

      // Get user-specific check history from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userCheckKey = 'last_expiry_check_$userId'; // User-specific key
      final lastCheck = prefs.getString(userCheckKey);

      if (lastCheck == today) {
        print('Already checked expiring items today for user $userId');
        _hasCheckedToday = true;
        return;
      }

      print('Checking for expiring items for user $userId...');

      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'In-stock')
          .get();

      List<Map<String, dynamic>> expiringItems = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final expiryDateStr = data['expiryDate'] as String?;

        if (expiryDateStr != null) {
          try {
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
          } catch (e) {
            print('Error parsing expiry date for item: ${data['name']} - $e');
          }
        }
      }

      // Send notifications for expiring items
      if (expiringItems.isNotEmpty) {
        await _sendExpiryNotifications(expiringItems);
        print('Sent ${expiringItems.length} expiry notifications for user $userId');
      } else {
        print('No items expiring in the next 3 days for user $userId');
      }

      // Save that we checked today for this specific user
      await prefs.setString(userCheckKey, today);
      _hasCheckedToday = true;

    } catch (e) {
      print('Error checking expiring items on app start: $e');
    }
  }

  // 🆓 NEW: Method to handle user logout/login changes
  static Future<void> onUserChanged() async {
    print('User changed, resetting notification check flags');
    _hasCheckedToday = false;
    _lastCheckedUserId = null;

    // Optionally check immediately for new user
    await _checkExpiringItemsOnAppStart();
  }

  // 🆓 NEW: Clean up old user data from SharedPreferences
  static Future<void> cleanupOldUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Remove old user-specific check data (older than 30 days)
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final cutoffString = cutoffDate.toIso8601String().split('T')[0];

      for (String key in keys) {
        if (key.startsWith('last_expiry_check_')) {
          final value = prefs.getString(key);
          if (value != null && value.compareTo(cutoffString) < 0) {
            await prefs.remove(key);
            print('Cleaned up old user data: $key');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old user data: $e');
    }
  }

  // Send local notifications for expiring items
  static Future<void> _sendExpiryNotifications(List<Map<String, dynamic>> items) async {
    // Group items by urgency
    final todayItems = items.where((item) => item['daysLeft'] == 0).toList();
    final tomorrowItems = items.where((item) => item['daysLeft'] == 1).toList();
    final soonItems = items.where((item) => item['daysLeft'] > 1).toList();

    // Send notification for items expiring today (highest priority)
    if (todayItems.isNotEmpty) {
      await _showLocalNotification(
        title: todayItems.length == 1
            ? '⚠️ Item Expires Today!'
            : '⚠️ ${todayItems.length} Items Expire Today!',
        body: todayItems.length == 1
            ? '${todayItems[0]['name']} expires today. Use it now!'
            : '${todayItems.map((item) => item['name']).take(3).join(', ')}${todayItems.length > 3 ? ' and ${todayItems.length - 3} more' : ''} expire today.',
        payload: 'expiry_today',
        notificationId: 1,
      );
    }

    // Send notification for items expiring tomorrow
    if (tomorrowItems.isNotEmpty) {
      await _showLocalNotification(
        title: tomorrowItems.length == 1
            ? '📅 Item Expires Tomorrow'
            : '📅 ${tomorrowItems.length} Items Expire Tomorrow',
        body: tomorrowItems.length == 1
            ? '${tomorrowItems[0]['name']} expires tomorrow. Plan to use it!'
            : '${tomorrowItems.map((item) => item['name']).take(3).join(', ')}${tomorrowItems.length > 3 ? ' and ${tomorrowItems.length - 3} more' : ''} expire tomorrow.',
        payload: 'expiry_tomorrow',
        notificationId: 2,
      );
    }

    // Send notification for items expiring soon (lower priority)
    if (soonItems.isNotEmpty) {
      await _showLocalNotification(
        title: soonItems.length == 1
            ? '🔔 Item Expiring Soon'
            : '🔔 ${soonItems.length} Items Expiring Soon',
        body: soonItems.length == 1
            ? '${soonItems[0]['name']} expires in ${soonItems[0]['daysLeft']} days.'
            : '${soonItems.length} items expire in the next few days.',
        payload: 'expiry_soon',
        notificationId: 3,
      );
    }
  }

  // Save FCM token to user's Firestore document
  static Future<void> _saveFCMToken(String token) async {
    try {
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
    } catch (e) {
      print('Error saving FCM token: $e');
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
    int? notificationId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Notifications',
      channelDescription: 'Notifications for items about to expire',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
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

    final id = notificationId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Manual check (can be called from other parts of your app)
  static Future<void> manualExpiryCheck() async {
    _hasCheckedToday = false; // Reset flag to force check
    await _checkExpiringItemsOnAppStart();
  }

  // Force check regardless of previous checks (for testing)
  static Future<void> forceExpiryCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final userCheckKey = 'last_expiry_check_${user.uid}';
      await prefs.remove(userCheckKey); // Remove previous check record for this user
    }
    _hasCheckedToday = false;
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

  // Clear notification history for current user
  static Future<void> clearNotificationHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final userCheckKey = 'last_expiry_check_${user.uid}';
      await prefs.remove(userCheckKey);
      _hasCheckedToday = false;
      print('Notification history cleared for user ${user.uid}');
    }
  }
}