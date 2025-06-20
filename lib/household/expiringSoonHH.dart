import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpiringSoonHH extends StatefulWidget {
  const ExpiringSoonHH({super.key});

  @override
  State<ExpiringSoonHH> createState() => _ExpiringSoonHHState();
}

class _ExpiringSoonHHState extends State<ExpiringSoonHH> {
  String selectedCategory = 'All';
  String selectedSubcategory = 'All';
  List<Map<String, dynamic>> expiringItems = [];
  bool isLoading = true;

  final Map<String, List<String>> categorySubcategories = {
    'Dry Groceries': [
      'All',
      'Snacks & Sweets',
      'Canned & Jarred Goods',
      'Pasta & Rice',
      'Baking Supplies',
      'Breakfast Cereals',
      'Condiments & Sauces'
    ],
    'Wet Groceries': [
      'All',
      'Dairy & Eggs',
      'Meat & Poultry',
      'Seafood',
      'Fruits & Vegetables',
      'Ready Meals',
      'Beverages'
    ],
  };

  @override
  void initState() {
    super.initState();
    fetchExpiringItems();
  }

  Future<void> fetchExpiringItems() async {
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

      List<Map<String, dynamic>> items = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final expiryDateStr = data['expiryDate'] as String?;

        if (expiryDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          final daysLeft = expiryDate.difference(now).inDays;

          // Only include items expiring in 5 days or less
          if (daysLeft <= 5 && daysLeft >= 0) {
            items.add({
              ...data,
              'daysLeft': daysLeft,
              'expiryFormatted': _formatExpiryText(daysLeft),
            });
          }
        }
      }

      // Sort by days left (most urgent first)
      items.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));

      setState(() {
        expiringItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching items: $e');
    }
  }

  String _formatExpiryText(int daysLeft) {
    if (daysLeft == 0) return 'Expires today!';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }

  List<Map<String, dynamic>> get filteredItems {
    if (selectedCategory == 'All') return expiringItems;

    return expiringItems.where((item) {
      bool categoryMatch = item['category'] == selectedCategory;

      if (!categoryMatch) return false;

      if (selectedSubcategory == 'All') return true;

      return item['subcategory'] == selectedSubcategory;
    }).toList();
  }

  void showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.all_inclusive, color: Colors.blue[700]),
              ),
              title: const Text('All Items'),
              trailing: selectedCategory == 'All'
                  ? Icon(Icons.check, color: Colors.green[600])
                  : null,
              onTap: () {
                setState(() {
                  selectedCategory = 'All';
                  selectedSubcategory = 'All';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_grocery_store, color: Colors.orange[700]),
              ),
              title: const Text('Dry Groceries'),
              trailing: selectedCategory == 'Dry Groceries'
                  ? Icon(Icons.check, color: Colors.green[600])
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                if (selectedCategory != 'Dry Groceries') {
                  setState(() {
                    selectedCategory = 'Dry Groceries';
                    selectedSubcategory = 'All';
                  });
                }
                showSubcategoryOptions('Dry Groceries');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.set_meal, color: Colors.green[700]),
              ),
              title: const Text('Wet Groceries'),
              trailing: selectedCategory == 'Wet Groceries'
                  ? Icon(Icons.check, color: Colors.green[600])
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                if (selectedCategory != 'Wet Groceries') {
                  setState(() {
                    selectedCategory = 'Wet Groceries';
                    selectedSubcategory = 'All';
                  });
                }
                showSubcategoryOptions('Wet Groceries');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void showSubcategoryOptions(String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showFilterOptions();
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...categorySubcategories[category]!.map((subcategory) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: subcategory == 'All' ? Colors.blue[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  subcategory == 'All' ? Icons.all_inclusive : Icons.category,
                  color: subcategory == 'All' ? Colors.blue[700] : Colors.grey[700],
                ),
              ),
              title: Text(subcategory),
              trailing: selectedSubcategory == subcategory
                  ? Icon(Icons.check, color: Colors.green[600])
                  : null,
              onTap: () {
                setState(() {
                  selectedCategory = category;
                  selectedSubcategory = subcategory;
                });
                Navigator.pop(context);
              },
            )).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
          'Expiring Soon',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[400]!, Colors.orange[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Use Me!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: showFilterOptions,
                icon: const Icon(Icons.tune, color: Colors.white),
                label: Text(
                  selectedSubcategory != 'All'
                      ? '$selectedCategory - $selectedSubcategory'
                      : selectedCategory,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
                  : filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 60,
                        color: Colors.green[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No items expiring soon!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All your items are fresh',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: fetchExpiringItems,
                color: Colors.green[600],
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final daysLeft = item['daysLeft'] as int;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(20),
                              ),
                              border: Border.all(
                                color: daysLeft == 0
                                    ? Colors.red
                                    : daysLeft == 1
                                    ? Colors.orange
                                    : Colors.green,
                                width: 3,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(17),
                              ),
                              child: item['imageUrl'] != null
                                  ? Image.network(
                                item['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 40,
                                    ),
                                  );
                                },
                              )
                                  : Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.image,
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['name'] ?? 'Unknown Item',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Qty: ${item['quantity'] ?? 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: daysLeft == 0
                                          ? Colors.red[50]
                                          : daysLeft == 1
                                          ? Colors.orange[50]
                                          : Colors.yellow[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 16,
                                          color: daysLeft == 0
                                              ? Colors.red[600]
                                              : daysLeft == 1
                                              ? Colors.orange[600]
                                              : Colors.orange[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item['expiryFormatted'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: daysLeft == 0
                                                ? Colors.red[600]
                                                : daysLeft == 1
                                                ? Colors.orange[600]
                                                : Colors.orange[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        size: 16,
                                        color: Colors.green[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${item['category']} • ${item['subcategory']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}