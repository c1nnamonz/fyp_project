import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ItemListHousehold extends StatefulWidget {
  const ItemListHousehold({super.key});

  @override
  State<ItemListHousehold> createState() => _ItemListHouseholdState();
}

class _ItemListHouseholdState extends State<ItemListHousehold> {
  String? selectedCategory; // Tracks the selected category (Wet/Dry)
  String? selectedSubcategory; // Tracks the selected subcategory
  String? selectedStatus; // Tracks the selected status
  String selectedSortOption = 'Default'; // Default sorting option
  bool isLoading = true;
  List<Map<String, dynamic>> groceryItems = [];

  // Sort options
  final List<String> _sortOptions = [
    'Default',
    'Expiring Soon',
    'Recently Added',
    'Alphabetical (A-Z)',
  ];

  // Category options mapping (same as in AddItemPage)
  final Map<String, List<String>> _categoryOptions = {
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

  // Status options
  final List<String> _statusOptions = [
    'All',
    'In-stock',
    'Wasted',
    'Consumed'
  ];

  // Status options for editing (without 'All')
  final List<String> _editStatusOptions = [
    'In-stock',
    'Wasted',
    'Consumed'
  ];

  @override
  void initState() {
    super.initState();
    // Set initial category
    selectedCategory = 'Wet Groceries';
    selectedSubcategory = 'All';
    selectedStatus = 'All';
    // Fetch items from Firebase
    _fetchItems();
  }

  // Check if an item is expired
  bool _isItemExpired(String expiryDateStr) {
    try {
      final DateTime expiryDate = DateFormat('yyyy-MM-dd').parse(expiryDateStr);
      final DateTime today = DateTime.now();
      final DateTime todayOnly = DateTime(today.year, today.month, today.day);
      final DateTime expiryOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

      return todayOnly.isAfter(expiryOnly);
    } catch (e) {
      print('Error parsing expiry date: $e');
      return false; // Don't mark as expired if we can't parse the date
    }
  }

  // Calculate days until expiry for sorting and display
  int _getDaysUntilExpiry(String expiryDateStr) {
    try {
      final DateTime expiryDate = DateFormat('yyyy-MM-dd').parse(expiryDateStr);
      final DateTime today = DateTime.now();
      final DateTime todayOnly = DateTime(today.year, today.month, today.day);
      final DateTime expiryOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

      // Return the difference in days, negative if already expired
      return expiryOnly.difference(todayOnly).inDays;
    } catch (e) {
      print('Error calculating days until expiry: $e');
      return 999; // Return a large number for invalid dates to sort them last
    }
  }

  // Sort items based on selected sort option
  void _sortItems() {
    switch (selectedSortOption) {
      case 'Expiring Soon':
      // Sort items by expiry date (closest to expiry first)
        groceryItems.sort((a, b) {
          // Only compare items that are in stock
          if (a['status'] == 'In-stock' && b['status'] == 'In-stock') {
            final int daysA = _getDaysUntilExpiry(a['expiresOn']);
            final int daysB = _getDaysUntilExpiry(b['expiresOn']);
            return daysA.compareTo(daysB);
          } else if (a['status'] == 'In-stock') {
            return -1; // a comes first if it's in stock
          } else if (b['status'] == 'In-stock') {
            return 1; // b comes first if it's in stock
          } else {
            return 0; // Both are not in stock, keep existing order
          }
        });
        break;
      case 'Alphabetical (A-Z)':
        groceryItems.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
        break;
      case 'Recently Added':
      // If you have a timestamp for when items were added, you could sort by that here
      // For now, let's keep the default order which is likely the order items were added to Firestore
        break;
      default:
      // Default sorting is already applied from Firestore
        break;
    }
  }

  // Update expired items to "Wasted" status in Firebase
  Future<void> _updateExpiredItemsToWasted(List<QueryDocumentSnapshot> docs) async {
    final DateTime today = DateTime.now();
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    bool hasUpdates = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['status'] ?? 'Unknown';
      final String expiryDateStr = data['expiryDate'] ?? '';

      // Only update if the item is currently "In-stock" and is expired
      if (status == 'In-stock' && expiryDateStr.isNotEmpty && _isItemExpired(expiryDateStr)) {
        batch.update(doc.reference, {
          'status': 'Wasted',
          'autoUpdatedAt': FieldValue.serverTimestamp(), // Track when auto-updated
        });
        hasUpdates = true;
        print('Auto-updating expired item: ${data['name']} to Wasted status');
      }
    }

    // Commit the batch update if there are any updates
    if (hasUpdates) {
      try {
        await batch.commit();
        print('Successfully updated expired items to Wasted status');
      } catch (e) {
        print('Error updating expired items: $e');
      }
    }
  }

  // Check if an item was auto-updated from In-stock to Wasted due to expiry
  bool _wasAutoUpdatedToWasted(Map<String, dynamic> data) {
    final String status = data['status'] ?? '';
    final String expiryDateStr = data['expiryDate'] ?? '';
    final dynamic autoUpdatedAt = data['autoUpdatedAt'];

    // Item was auto-updated if:
    // 1. Current status is 'Wasted'
    // 2. Item is expired
    // 3. Has autoUpdatedAt timestamp (indicating it was auto-updated)
    return status == 'Wasted' &&
        expiryDateStr.isNotEmpty &&
        _isItemExpired(expiryDateStr) &&
        autoUpdatedAt != null;
  }

  // Fetch items from Firestore based on user ID and filters
  Future<void> _fetchItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
          groceryItems = [];
        });
        return;
      }

      // Create query based on user ID and selected category
      Query query = FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: currentUser.uid);

      if (selectedCategory != null) {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      // Execute query
      final QuerySnapshot snapshot = await query.get();

      // First, update expired items to "Wasted" status
      await _updateExpiredItemsToWasted(snapshot.docs);

      // If we made updates, fetch the data again to get the updated status
      final QuerySnapshot updatedSnapshot = await query.get();

      // Convert documents to list of maps
      List<Map<String, dynamic>> items = updatedSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'boughtOn': data['purchaseDate'] ?? 'Unknown',
          'expiresOn': data['expiryDate'] ?? 'Unknown',
          'quantity': data['quantity']?.toString() ?? '0',
          'unit': data['unit'] ?? '', // Added unit field
          'image': data['imageUrl'] ?? '',
          'subcategory': data['subcategory'] ?? '',
          'status': data['status'] ?? 'Unknown',
          'isExpired': data['expiryDate'] != null && data['expiryDate'].isNotEmpty
              ? _isItemExpired(data['expiryDate'])
              : false,
          'daysUntilExpiry': data['expiryDate'] != null && data['expiryDate'].isNotEmpty
              ? _getDaysUntilExpiry(data['expiryDate'])
              : 999, // Add days until expiry for sorting
          'wasAutoUpdated': _wasAutoUpdatedToWasted(data), // New field to track auto-updates
          'autoUpdatedAt': data['autoUpdatedAt'], // Keep the timestamp
        };
      }).toList();

      // Apply subcategory filter if needed
      if (selectedSubcategory != null && selectedSubcategory != 'All') {
        items = items.where((item) => item['subcategory'] == selectedSubcategory).toList();
      }

      // Apply status filter if needed
      if (selectedStatus != null && selectedStatus != 'All') {
        items = items.where((item) => item['status'] == selectedStatus).toList();
      }

      setState(() {
        groceryItems = items;
        // Apply sorting
        _sortItems();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching items: $e');
      setState(() {
        isLoading = false;
        groceryItems = [];
      });
    }
  }

  // Update item in Firebase
  Future<void> _updateItemInFirebase(String itemId, String newQuantity, String newStatus) async {
    try {
      // If user manually updates the status, remove the autoUpdatedAt timestamp
      Map<String, dynamic> updateData = {
        'quantity': int.parse(newQuantity),
        'status': newStatus,
      };

      // Remove autoUpdatedAt if user manually changes status
      updateData['autoUpdatedAt'] = FieldValue.delete();

      await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .update(updateData);

      // Refresh the list after update
      _fetchItems();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item updated successfully!'),
          backgroundColor: Color(0xFF008A02),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update item. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Show edit dialog
  void _showEditDialog(Map<String, dynamic> item) {
    final TextEditingController quantityController = TextEditingController(text: item['quantity']);
    String selectedEditStatus = item['status'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${item['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show expiry warning only if item was auto-updated to Wasted
                  if (item['wasAutoUpdated'] == true)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This item expired and was automatically marked as Wasted.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Quantity field
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.shopping_cart),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Status dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    value: selectedEditStatus,
                    items: _editStatusOptions.map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          selectedEditStatus = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate quantity
                    final String newQuantity = quantityController.text.trim();
                    if (newQuantity.isEmpty || int.tryParse(newQuantity) == null || int.parse(newQuantity) < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a valid quantity'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Update in Firebase
                    _updateItemInFirebase(item['id'], newQuantity, selectedEditStatus);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF008A02),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Format expiry date for display
  String formatExpiryDate(String expiryDateStr) {
    try {
      final DateTime expiryDate = DateFormat('yyyy-MM-dd').parse(expiryDateStr);
      return DateFormat('MMM dd, yyyy').format(expiryDate);
    } catch (e) {
      return expiryDateStr; // Return original string if parsing fails
    }
  }

  // Format days until expiry for display
  String formatDaysUntilExpiry(int days) {
    if (days < 0) {
      return 'Expired ${days.abs()} days ago';
    } else if (days == 0) {
      return 'Expires today!';
    } else if (days == 1) {
      return 'Expires tomorrow';
    } else {
      return 'Expires in $days days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(35.0, 35.0, 35.0, 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'This is your Groceries List',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Category Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = 'Wet Groceries';
                      selectedSubcategory = 'All';
                      _fetchItems();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedCategory == 'Wet Groceries'
                        ? Color(0xFF008A02)
                        : Colors.white,
                    foregroundColor: selectedCategory == 'Wet Groceries'
                        ? Colors.white
                        : Color(0xFF008A02),
                  ),
                  child: const Text('Wet Groceries'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = 'Dry Groceries';
                      selectedSubcategory = 'All';
                      _fetchItems();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedCategory == 'Dry Groceries'
                        ? Color(0xFF008A02)
                        : Colors.white,
                    foregroundColor: selectedCategory == 'Dry Groceries'
                        ? Colors.white
                        : Color(0xFF008A02),
                  ),
                  child: const Text('Dry Groceries'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Subcategory, Status, and Sort Dropdowns in a Column
            if (selectedCategory != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80.0),
                child: Column(
                  children: [
                    // Food Category Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Food Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.fastfood),
                      ),
                      value: selectedSubcategory,
                      items: _categoryOptions[selectedCategory]!.map((String subcategory) {
                        return DropdownMenuItem<String>(
                          value: subcategory,
                          child: Text(subcategory),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedSubcategory = newValue;
                            _fetchItems();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15), // Space between dropdowns

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                      value: selectedStatus,
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedStatus = newValue;
                            _fetchItems();
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 15), // Space between dropdowns

                    // Sort Option Dropdown (NEW)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.sort),
                      ),
                      value: selectedSortOption,
                      items: _sortOptions.map((String option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedSortOption = newValue;
                            _sortItems(); // Apply sorting immediately
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Loading indicator
            if (isLoading)
              Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF008A02),
                ),
              ),

            // No items message
            if (!isLoading && groceryItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No items found. Add some groceries!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),

            // Display Groceries
            if (!isLoading)
              ...groceryItems.map((item) => _buildGroceryItem(item)),
          ],
        ),
      ),
    );
  }

  // Reusable Widget for Grocery Item with BoxDecoration and tap functionality
  Widget _buildGroceryItem(Map<String, dynamic> item) {
    final bool wasAutoUpdated = item['wasAutoUpdated'] ?? false;
    final int daysUntilExpiry = item['daysUntilExpiry'] ?? 999;

    // Show expiry warning for items expiring soon (less than 3 days) but not yet expired
    final bool showExpiryWarning = item['status'] == 'In-stock' && daysUntilExpiry >= 0 && daysUntilExpiry <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: GestureDetector(
        onTap: () => _showEditDialog(item),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: wasAutoUpdated
                ? Border.all(color: Colors.red.shade300, width: 2)
                : showExpiryWarning
                ? Border.all(color: Colors.orange.shade300, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                // Auto-updated warning banner - only show for items that were auto-updated
                if (wasAutoUpdated)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'EXPIRED - Auto-updated to Wasted',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Expiring soon warning - only show for items that are expiring soon
                if (showExpiryWarning)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text(
                          formatDaysUntilExpiry(daysUntilExpiry),
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image on left side with fixed size
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item['image'].toString().isNotEmpty
                          ? Image.network(
                        item['image'],
                        width: 140,  // Fixed width
                        height: 140, // Fixed height
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 140,
                            height: 120,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 140,
                            height: 120,
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      )
                          : Container(
                        width: 140,
                        height: 120,
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(width: 15), // Space between image and text
                    // Text content on right side
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 15, color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Bought on: ',
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: item['boughtOn'],
                                  style: TextStyle(color: Color(0xFF008A02)), // Green color
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 15, color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Expires on: ',
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: formatExpiryDate(item['expiresOn']),
                                  style: TextStyle(
                                    color: item['isExpired'] ? Colors.red :
                                    (daysUntilExpiry <= 3) ? Colors.orange : Colors.green,
                                    fontWeight: (item['isExpired'] || daysUntilExpiry <= 3) ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Display days until expiry for items that are in stock
                          if (item['status'] == 'In-stock' && item['expiresOn'] != 'Unknown')
                            RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 15, color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: 'Status: ',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  TextSpan(
                                    text: formatDaysUntilExpiry(daysUntilExpiry),
                                    style: TextStyle(
                                      color: item['isExpired'] ? Colors.red :
                                      (daysUntilExpiry <= 3) ? Colors.orange : Colors.green,
                                      fontWeight: (item['isExpired'] || daysUntilExpiry <= 3) ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 15, color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Quantity: ',
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: '${item['quantity']} ${item['unit']}',
                                  style: TextStyle(color: Color(0xFFD6BC00)), // Yellow color
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 15, color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Status: ',
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: item['status'],
                                  style: TextStyle(
                                    color: _getStatusColor(item['status']),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-stock':
        return Color(0xFF008A02); // Green
      case 'wasted':
        return Colors.red; // Red
      case 'consumed':
        return Colors.blue; // Blue
      default:
        return Colors.grey; // Default color
    }
  }
}