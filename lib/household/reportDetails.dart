import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';

class ReportDetails extends StatefulWidget {
  final int month;
  final int year;
  final int totalBought;
  final int totalWaste;
  final String topWastedProduct;
  final int topWastedCount;

  const ReportDetails({
    super.key,
    required this.month,
    required this.year,
    required this.totalBought,
    required this.totalWaste,
    required this.topWastedProduct,
    required this.topWastedCount,
  });

  @override
  State<ReportDetails> createState() => _ReportDetailsState();
}

class _ReportDetailsState extends State<ReportDetails> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, int> categoryWaste = {};
  List<Map<String, dynamic>> weeklyData = [];
  List<Map<String, dynamic>> topWastedItems = [];
  bool isLoading = true;
  double wastePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDetailedData();
  }

  Future<void> _loadDetailedData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final startOfMonth = DateTime(widget.year, widget.month, 1);
      final endOfMonth = DateTime(widget.year, widget.month + 1, 0);

      final itemsQuery = await _firestore
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      Map<String, int> categoryWasteMap = {};
      Map<String, int> productWasteMap = {};
      List<Map<String, dynamic>> weeklyWasteData = [];

      // Initialize weekly data
      for (int week = 1; week <= 4; week++) {
        weeklyWasteData.add({
          'week': 'Week $week',
          'waste': 0,
          'bought': 0,
        });
      }

      for (var doc in itemsQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final expiryDate = DateTime.tryParse(data['expiryDate'] ?? '');
        final purchaseDate = DateTime.tryParse(data['purchaseDate'] ?? '');

        // Check if item was wasted/expired in the selected month
        // IMPORTANT: Exclude items that were consumed - they should not count as waste
        bool wasWastedInMonth = false;

        // Skip consumed items - they are not waste regardless of expiry date
        if (status == 'Consumed') {
          // Still count purchased items for weekly bought data, but skip waste calculation
          if (purchaseDate != null &&
              purchaseDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              purchaseDate.isBefore(endOfMonth.add(Duration(days: 1)))) {

            int weekNumber = ((purchaseDate.day - 1) / 7).floor();
            if (weekNumber < 4) {
              weeklyWasteData[weekNumber]['bought'] += (data['quantity'] as int? ?? 1);
            }
          }
          continue; // Skip this item for waste calculations
        }

        if (status == 'Expired' || status == 'Wasted') {
          // If explicitly marked as expired/wasted, check if it was purchased in the selected month
          if (purchaseDate != null &&
              purchaseDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              purchaseDate.isBefore(endOfMonth.add(Duration(days: 1)))) {
            wasWastedInMonth = true;
          }
        } else if (expiryDate != null && status != 'Consumed') {
          // Only consider items as expired waste if they're NOT consumed
          // If item expired during the selected month, count it as waste for that month
          if (expiryDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              expiryDate.isBefore(endOfMonth.add(Duration(days: 1))) &&
              expiryDate.isBefore(DateTime.now())) {
            wasWastedInMonth = true;
          }
          // Also count if item was purchased in selected month and has now expired
          else if (purchaseDate != null &&
              purchaseDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              purchaseDate.isBefore(endOfMonth.add(Duration(days: 1))) &&
              expiryDate.isBefore(DateTime.now())) {
            wasWastedInMonth = true;
          }
        }

        // Only process waste data if item was wasted in the selected month
        if (wasWastedInMonth) {
          final category = data['category'] as String? ?? 'Unknown';
          final productName = data['name'] as String? ?? 'Unknown';
          final quantity = data['quantity'] as int? ?? 1;

          // Category waste
          categoryWasteMap[category] = (categoryWasteMap[category] ?? 0) + quantity;

          // Product waste
          productWasteMap[productName] = (productWasteMap[productName] ?? 0) + quantity;

          // Weekly waste data (if purchase date is in selected month)
          if (purchaseDate != null &&
              purchaseDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              purchaseDate.isBefore(endOfMonth.add(Duration(days: 1)))) {

            int weekNumber = ((purchaseDate.day - 1) / 7).floor();
            if (weekNumber < 4) {
              weeklyWasteData[weekNumber]['waste'] += quantity;
            }
          }
          // For items that expired in the selected month but were purchased earlier,
          // assign them to the week they expired
          else if (expiryDate != null &&
              expiryDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              expiryDate.isBefore(endOfMonth.add(Duration(days: 1)))) {

            int weekNumber = ((expiryDate.day - 1) / 7).floor();
            if (weekNumber < 4) {
              weeklyWasteData[weekNumber]['waste'] += quantity;
            }
          }
        }

        // Count bought items for weekly data (only for selected month)
        // This applies to all items (including consumed ones) that were purchased in the month
        if (purchaseDate != null &&
            purchaseDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
            purchaseDate.isBefore(endOfMonth.add(Duration(days: 1))) &&
            status != 'Consumed') { // We already handled consumed items above

          int weekNumber = ((purchaseDate.day - 1) / 7).floor();
          if (weekNumber < 4) {
            weeklyWasteData[weekNumber]['bought'] += (data['quantity'] as int? ?? 1);
          }
        }
      }

      // Convert to sorted lists
      List<Map<String, dynamic>> sortedProducts = productWasteMap.entries
          .map((e) => {'name': e.key, 'waste': e.value})
          .toList();
      sortedProducts.sort((a, b) => b['waste'].compareTo(a['waste']));

      setState(() {
        categoryWaste = categoryWasteMap;
        weeklyData = weeklyWasteData;
        topWastedItems = sortedProducts.take(5).toList();
        wastePercentage = widget.totalBought > 0
            ? (widget.totalWaste / widget.totalBought) * 100
            : 0.0;
        isLoading = false;
      });

    } catch (e) {
      print('Error loading detailed data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (weeklyData.isEmpty) return Container();

    int maxValue = weeklyData.map((e) => e['waste'] as int).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Waste Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: lightColorScheme.primary,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: weeklyData.map((week) {
                double height = (week['waste'] / maxValue) * 120;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${week['waste']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDA320C),
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: height,
                      decoration: BoxDecoration(
                        color: Color(0xFFDA320C).withOpacity(0.8),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      week['week'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    if (categoryWaste.isEmpty) {
      return Container(
        height: 250,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waste by Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: lightColorScheme.primary,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                  'No waste data for ${_getMonthName(widget.month)} ${widget.year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    List<Color> colors = [
      Color(0xFFDA320C),
      Color(0xFFE12900),
      Color(0xFFDDC200),
      lightColorScheme.primary,
      Colors.purple,
      Colors.orange,
    ];

    int total = categoryWaste.values.reduce((a, b) => a + b);

    return Container(
      height: 250,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waste by Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: lightColorScheme.primary,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: categoryWaste.length,
              itemBuilder: (context, index) {
                String category = categoryWaste.keys.elementAt(index);
                int waste = categoryWaste[category]!;
                double percentage = (waste / total) * 100;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$waste (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopWastedList() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 Wasted Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: lightColorScheme.primary,
            ),
          ),
          SizedBox(height: 16),
          ...topWastedItems.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> item = entry.value;

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: index == 0 ? Color(0xFFDA320C) : lightColorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFDA320C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item['waste']} wasted',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDA320C),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (topWastedItems.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No wasted items found for ${_getMonthName(widget.month)} ${widget.year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    String insight = '';
    IconData insightIcon = Icons.lightbulb_outline;
    Color insightColor = lightColorScheme.primary;

    if (wastePercentage > 30) {
      insight = 'High waste rate detected. Consider better meal planning and storage techniques.';
      insightIcon = Icons.warning_amber;
      insightColor = Color(0xFFDA320C);
    } else if (wastePercentage > 15) {
      insight = 'Moderate waste rate. Look for patterns in your most wasted items.';
      insightIcon = Icons.info_outline;
      insightColor = Colors.orange;
    } else if (wastePercentage > 0) {
      insight = 'Good job! Your waste rate is low. Keep up the sustainable habits.';
      insightIcon = Icons.eco;
      insightColor = Colors.green;
    } else {
      insight = 'Excellent! No waste detected this month. You\'re doing great!';
      insightIcon = Icons.star;
      insightColor = Colors.green;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insightIcon, color: insightColor, size: 24),
              SizedBox(width: 8),
              Text(
                'Smart Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: lightColorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            insight,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: lightColorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Report',
              style: TextStyle(
                color: lightColorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_getMonthName(widget.month)} ${widget.year}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: lightColorScheme.primary),
            onPressed: _loadDetailedData,
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: lightColorScheme.primary,
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Bought',
                    '${widget.totalBought}',
                    lightColorScheme.primary,
                    Icons.shopping_cart,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Total Waste',
                    '${widget.totalWaste}',
                    Color(0xFFDA320C),
                    Icons.delete_outline,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Waste Rate',
                    '${wastePercentage.toStringAsFixed(1)}%',
                    Colors.orange,
                    Icons.trending_up,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Items Saved',
                    '${widget.totalBought - widget.totalWaste}',
                    Colors.green,
                    Icons.eco,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Charts Section
            _buildBarChart(),
            SizedBox(height: 16),
            _buildCategoryPieChart(),
            SizedBox(height: 16),

            // Top Wasted Items
            _buildTopWastedList(),
            SizedBox(height: 16),

            // Smart Insights
            _buildInsightsCard(),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}