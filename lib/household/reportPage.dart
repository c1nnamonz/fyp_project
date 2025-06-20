import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/household/listItemWasted.dart';
import 'package:fyp_project/household/reportDetails.dart';
import '../theme/theme.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Report data variables
  int totalProductsBought = 0;
  int totalWaste = 0;
  String topWastedProduct = '';
  int topWastedCount = 0;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> wastedItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = _auth.currentUser;
      if (user == null) return;

      // Create date range for selected month/year
      final startOfMonth = DateTime(selectedYear, selectedMonth, 1);
      final endOfMonth = DateTime(selectedYear, selectedMonth + 1, 0);

      // Query items for current user
      final itemsQuery = await _firestore
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Process items data
      Map<String, int> wastedProductCounts = {};
      int totalProducts = 0;
      int wastedProducts = 0;
      List<Map<String, dynamic>> monthlyWastedItems = [];

      for (var doc in itemsQuery.docs) {
        final data = doc.data();
        final purchaseDate = DateTime.tryParse(data['purchaseDate'] ?? '');
        final expiryDate = DateTime.tryParse(data['expiryDate'] ?? '');
        final status = data['status'] as String? ?? '';

        // Count products bought in selected month
        if (purchaseDate != null &&
            purchaseDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
            purchaseDate.isBefore(endOfMonth.add(Duration(days: 1)))) {
          totalProducts += (data['quantity'] as int? ?? 1);
        }

        // Check if item was wasted/expired in the selected month
        // IMPORTANT: Exclude items that were consumed - they should not count as waste
        bool wasWastedInMonth = false;

        // Skip consumed items - they are not waste regardless of expiry date
        if (status == 'Consumed') {
          continue; // Skip this item entirely
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

        if (wasWastedInMonth) {
          final productName = data['name'] as String? ?? 'Unknown';
          final quantity = data['quantity'] as int? ?? 1;

          wastedProducts += quantity;
          wastedProductCounts[productName] =
              (wastedProductCounts[productName] ?? 0) + quantity;

          // Add to monthly wasted items list
          monthlyWastedItems.add({
            'name': data['name'] ?? 'Unknown',
            'imageUrl': data['imageUrl'] ?? '',
            'quantity': data['quantity'] ?? 1,
            'category': data['category'] ?? 'Unknown',
          });
        }
      }

      // Find top wasted product for the month
      String topProduct = '';
      int maxWasted = 0;
      wastedProductCounts.forEach((product, count) {
        if (count > maxWasted) {
          maxWasted = count;
          topProduct = product;
        }
      });

      // Sort monthly wasted items by quantity (most wasted first)
      monthlyWastedItems.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

      setState(() {
        totalProductsBought = totalProducts;
        totalWaste = wastedProducts;
        topWastedProduct = topProduct.isEmpty ? 'None' : topProduct;
        topWastedCount = maxWasted;
        wastedItems = monthlyWastedItems.take(10).toList(); // Show top 10
        isLoading = false;
      });

    } catch (e) {
      print('Error loading report data: $e');
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

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempMonth = selectedMonth;
        int tempYear = selectedYear;

        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  'Select Report Period',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: lightColorScheme.primary,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month Selector
                    Row(
                      children: [
                        Text('Month: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<int>(
                            value: tempMonth,
                            isExpanded: true,
                            items: List.generate(12, (index) {
                              return DropdownMenuItem(
                                value: index + 1,
                                child: Text(_getMonthName(index + 1)),
                              );
                            }),
                            onChanged: (value) {
                              setDialogState(() {
                                tempMonth = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Year Selector
                    Row(
                      children: [
                        Text('Year: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<int>(
                            value: tempYear,
                            isExpanded: true,
                            items: List.generate(5, (index) {
                              int year = DateTime.now().year - 2 + index;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }),
                            onChanged: (value) {
                              setDialogState(() {
                                tempYear = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedMonth = tempMonth;
                        selectedYear = tempYear;
                      });
                      Navigator.pop(context);
                      _loadReportData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightColorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Apply'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(45.0, 50.0, 45.0, 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Report Analysis ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  ClipRRect(
                    child: Image.asset(
                      'images/lightbulb.png',
                      width: 35,
                      height: 35,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Header with month/year selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: lightColorScheme.primary,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showMonthYearPicker,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: lightColorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: lightColorScheme.primary),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 16,
                                color: lightColorScheme.primary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '${_getMonthName(selectedMonth)} $selectedYear',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        onPressed: _loadReportData,
                        icon: Icon(
                          Icons.refresh,
                          color: lightColorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Main report card - Now clickable
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportDetails(
                        month: selectedMonth,
                        year: selectedYear,
                        totalBought: totalProductsBought,
                        totalWaste: totalWaste,
                        topWastedProduct: topWastedProduct,
                        topWastedCount: topWastedCount,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 330,
                  width: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(30, 30, 25, 20),
                  child: isLoading
                      ? Center(
                    child: CircularProgressIndicator(
                      color: lightColorScheme.primary,
                    ),
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Report Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Icon(
                            Icons.touch_app,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                      Text(
                        '${_getMonthName(selectedMonth)} $selectedYear',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Report Content
                      Row(
                        children: [
                          Text(
                            'Total Products Bought: ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Text(
                            '$totalProductsBought',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Text(
                            'Total Waste: ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Text(
                            '$totalWaste',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDA320C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Text(
                            'Top Product Waste: ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$topWastedProduct ($topWastedCount)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDA320C),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Text(
                            'Waste Percentage: ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Text(
                            '${totalProductsBought > 0 ? ((totalWaste / totalProductsBought) * 100).toStringAsFixed(1) : '0.0'}%',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDA320C),
                            ),
                          ),
                        ],
                      ),

                      Spacer(),

                      // Tap hint
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: lightColorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.analytics,
                                size: 16,
                                color: lightColorScheme.primary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Tap for detailed analysis',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section title
            Padding(
              padding: const EdgeInsets.fromLTRB(25.0, 5.0, 25.0, 5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Items ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Text(
                            'Usually ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE12900),
                            ),
                          ),
                          Text(
                            'Wasted',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDDC200),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ListItemWasted()),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Wasted items list
            Container(
              height: 270,
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  color: lightColorScheme.primary,
                ),
              )
                  : wastedItems.isEmpty
                  ? Center(
                child: Text(
                  'No wasted items found for ${_getMonthName(selectedMonth)} $selectedYear',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              )
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                itemCount: wastedItems.length,
                itemBuilder: (context, index) {
                  final item = wastedItems[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: Container(
                      width: 210,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item['imageUrl'].isNotEmpty
                                    ? Image.network(
                                  item['imageUrl'],
                                  width: 170,
                                  height: 130,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 170,
                                      height: 130,
                                      color: Colors.grey[300],
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                )
                                    : Container(
                                  width: 170,
                                  height: 130,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.fastfood,
                                    size: 50,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                'Name: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Total Wasted: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                              Text(
                                '${item['quantity']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDA320C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Category: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item['category'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}