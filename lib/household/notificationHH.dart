import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationHousehold extends StatefulWidget {
  const NotificationHousehold({super.key});

  @override
  State<NotificationHousehold> createState() => _NotificationHouseholdState();
}

class _NotificationHouseholdState extends State<NotificationHousehold> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final fiveDaysFromNow = now.add(const Duration(days: 5));

      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'In-stock')
          .get();

      List<Map<String, dynamic>> notificationList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final expiryDateStr = data['expiryDate'] as String?;

        if (expiryDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          final daysLeft = expiryDate.difference(now).inDays;

          // Create notifications for items expiring in 5 days or less
          if (daysLeft <= 5 && daysLeft >= 0) {
            notificationList.add({
              'id': doc.id,
              'type': 'expiry',
              'title': _getNotificationTitle(daysLeft),
              'message': _getNotificationMessage(data['name'], daysLeft),
              'itemName': data['name'],
              'daysLeft': daysLeft,
              'timestamp': now,
              'priority': _getPriority(daysLeft),
              'icon': _getNotificationIcon(daysLeft),
              'color': _getNotificationColor(daysLeft),
              'itemData': data,
            });
          }
        }
      }

      // Sort by priority (most urgent first) then by days left
      notificationList.sort((a, b) {
        int priorityCompare = a['priority'].compareTo(b['priority']);
        if (priorityCompare != 0) return priorityCompare;
        return a['daysLeft'].compareTo(b['daysLeft']);
      });

      setState(() {
        notifications = notificationList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching notifications: $e');
    }
  }

  String _getNotificationTitle(int daysLeft) {
    if (daysLeft == 0) return 'Urgent: Item Expires Today!';
    if (daysLeft == 1) return 'Warning: Item Expires Tomorrow';
    return 'Reminder: Item Expiring Soon';
  }

  String _getNotificationMessage(String? itemName, int daysLeft) {
    final name = itemName ?? 'Unknown Item';
    if (daysLeft == 0) return '$name expires today. Use it now!';
    if (daysLeft == 1) return '$name expires tomorrow. Plan to use it soon.';
    return '$name expires in $daysLeft days. Consider using it soon.';
  }

  int _getPriority(int daysLeft) {
    if (daysLeft == 0) return 1; // Highest priority
    if (daysLeft == 1) return 2; // High priority
    return 3; // Medium priority
  }

  IconData _getNotificationIcon(int daysLeft) {
    if (daysLeft == 0) return Icons.warning;
    if (daysLeft == 1) return Icons.schedule;
    return Icons.notifications;
  }

  Color _getNotificationColor(int daysLeft) {
    if (daysLeft == 0) return Colors.red;
    if (daysLeft == 1) return Colors.orange;
    return Colors.amber;
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Future<void> markAsRead(String notificationId) async {
    setState(() {
      notifications.removeWhere((notification) => notification['id'] == notificationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  notifications.clear();
                });
              },
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        )
            : notifications.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 60,
                  color: Colors.blue[400],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re all caught up!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: fetchNotifications,
          color: Colors.green[600],
          child: Column(
            children: [
              // Summary banner
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expiry Alerts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${notifications.length} item${notifications.length != 1 ? 's' : ''} need${notifications.length == 1 ? 's' : ''} attention',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Notifications list
              Expanded(
                child: ListView.builder(
                  itemCount: notifications.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Dismissible(
                      key: Key(notification['id']),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        markAsRead(notification['id']);
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: notification['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              notification['icon'],
                              color: notification['color'],
                              size: 24,
                            ),
                          ),
                          title: Text(
                            notification['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                notification['message'],
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimeAgo(notification['timestamp']),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: notification['daysLeft'] == 0
                              ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                              : null,
                          onTap: () {
                            // You can navigate to item details or expiring soon page
                            markAsRead(notification['id']);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}