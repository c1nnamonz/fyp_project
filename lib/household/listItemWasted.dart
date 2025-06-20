import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListItemWasted extends StatefulWidget {
  const ListItemWasted({super.key});

  @override
  State<ListItemWasted> createState() => _ListItemWastedState();
}

class _ListItemWastedState extends State<ListItemWasted> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> wastedItems = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadWastedItems();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWastedItems() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = _auth.currentUser;
      if (user == null) return;

      final itemsQuery = await _firestore
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> wastedItemsList = [];
      Map<String, Map<String, dynamic>> productWasteMap = {};

      for (var doc in itemsQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final expiryDate = DateTime.tryParse(data['expiryDate'] ?? '');
        final purchaseDate = DateTime.tryParse(data['purchaseDate'] ?? '');

        // Skip consumed items - they are not waste regardless of expiry date
        if (status == 'Consumed') {
          continue; // Skip this item entirely
        }

        bool isWasted = false;

        if (status == 'Expired' || status == 'Wasted') {
          // If explicitly marked as expired/wasted, count as waste
          isWasted = true;
        } else if (expiryDate != null && status != 'Consumed') {
          // Only consider items as expired waste if they're NOT consumed
          // Check if item has expired and is not consumed
          if (expiryDate.isBefore(DateTime.now())) {
            isWasted = true;
          }
        }

        if (isWasted) {
          final productName = data['name'] as String? ?? 'Unknown';
          final quantity = data['quantity'] as int? ?? 1;
          final category = data['category'] as String? ?? 'Unknown';
          final imageUrl = data['imageUrl'] as String? ?? '';

          if (productWasteMap.containsKey(productName)) {
            productWasteMap[productName]!['totalWasted'] += quantity;
            productWasteMap[productName]!['instances']++;
            if (purchaseDate != null) {
              final currentDate = DateTime.tryParse(productWasteMap[productName]!['lastPurchaseDate'] ?? '');
              if (currentDate == null || purchaseDate.isAfter(currentDate)) {
                productWasteMap[productName]!['lastPurchaseDate'] = purchaseDate.toIso8601String();
              }
            }
          } else {
            productWasteMap[productName] = {
              'name': productName,
              'category': category,
              'imageUrl': imageUrl,
              'totalWasted': quantity,
              'instances': 1,
              'lastPurchaseDate': purchaseDate?.toIso8601String() ?? '',
            };
          }
        }
      }

      wastedItemsList = productWasteMap.values.toList();
      wastedItemsList.sort((a, b) => (b['totalWasted'] as int).compareTo(a['totalWasted'] as int));

      setState(() {
        wastedItems = wastedItemsList;
        isLoading = false;
      });

      _animationController.forward();

    } catch (e) {
      print('Error loading wasted items: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    List<Map<String, dynamic>> filtered = List.from(wastedItems);

    switch (selectedFilter) {
      case 'Most Wasted':
        break;
      case 'Recent':
        filtered.sort((a, b) {
          final dateA = DateTime.tryParse(a['lastPurchaseDate'] ?? '');
          final dateB = DateTime.tryParse(b['lastPurchaseDate'] ?? '');
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        break;
      case 'All':
      default:
        break;
    }

    return filtered;
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fruits':
        return const Color(0xFFFF6B6B);
      case 'vegetables':
        return const Color(0xFF51CF66);
      case 'dairy':
        return const Color(0xFF74C0FC);
      case 'meat':
        return const Color(0xFFFF8787);
      case 'grains':
        return const Color(0xFFFFD43B);
      default:
        return const Color(0xFF9775FA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF01770A),
                    Color(0xFF6E09FD),
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: const Text(
                  'Wasted Items Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00A135),
                        Color(0xFF3F3E3E),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.analytics_outlined,
                      size: 80,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _loadWastedItems,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ),
            ],
          ),

          // Filter Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: const Color(0xFF667EEA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF667EEA).withOpacity(0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                          items: ['All', 'Most Wasted', 'Recent']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedFilter = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Area
          SliverToBoxAdapter(
            child: isLoading
                ? Container(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF186000), Color(0xFFB9B9B9)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Loading your waste analytics...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : filteredItems.isEmpty
                ? Container(
              height: 400,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.2),
                            const Color(0xFF059669).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        size: 60,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Excellent Work! 🎉',
                      style: TextStyle(
                        fontSize: 24,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No wasted items found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep up the great work reducing food waste!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
                : Column(
              children: [
                // Items List
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final categoryColor = _getCategoryColor(item['category']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Enhanced Item Image
                              Hero(
                                tag: 'item_${item['name']}_$index',
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: categoryColor.withOpacity(0.3),
                                        spreadRadius: 0,
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: item['imageUrl'].isNotEmpty
                                        ? Image.network(
                                      item['imageUrl'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                categoryColor.withOpacity(0.8),
                                                categoryColor,
                                              ],
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.fastfood_rounded,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    )
                                        : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            categoryColor.withOpacity(0.8),
                                            categoryColor,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Enhanced Item Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),

                                    // Category Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: categoryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: categoryColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        item['category'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: categoryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Stats Row
                                    Row(
                                      children: [
                                        _buildStatChip(
                                          Icons.delete_outline_rounded,
                                          '${item['totalWasted']}',
                                          const Color(0xFFEF4444),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatChip(
                                          Icons.repeat_rounded,
                                          '${item['instances']}x',
                                          const Color(0xFFF59E0B),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Date
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 14,
                                          color: const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Last: ${_formatDate(item['lastPurchaseDate'])}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Waste Indicator Badge
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withOpacity(0.3),
                                      spreadRadius: 0,
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${item['totalWasted']}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Enhanced Summary Footer
                if (filteredItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF334155),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Items',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filteredItems.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total Waste',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filteredItems.fold<int>(0, (sum, item) => sum + (item['totalWasted'] as int))}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}