import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/household/expiringSoonHH.dart';
import 'package:fyp_project/household/recipeDetails.dart';
import 'package:fyp_project/household/recipeSuggestion.dart';
import 'package:fyp_project/household/rootPageHH.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/ai/ai_recipe_service.dart';
import 'package:fyp_project/ai/ai_recipe_details.dart';

class HomePageHousehold extends StatefulWidget {
  const HomePageHousehold({super.key});

  @override
  State<HomePageHousehold> createState() => _HomePageHouseholdState();
}

class _HomePageHouseholdState extends State<HomePageHousehold> {
  int selectedIndex = 0;
  String _userName = '';
  bool _isLoading = true;
  int _dryGroceryCount = 0;
  int _wetGroceryCount = 0;
  List<Map<String, dynamic>> _expiringItems = [];
  bool _loadingExpiringItems = true;
  List<Map<String, dynamic>> _aiGeneratedRecipes = [];
  bool _loadingAIRecipes = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAIRecipeSuggestions();
    _fetchExpiringItems();
  }

  Future<void> _fetchAIRecipeSuggestions() async {
    try {
      setState(() => _loadingAIRecipes = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user for AI recipes');
        setState(() => _loadingAIRecipes = false);
        return;
      }

      print('🔥 FETCHING AI RECIPES: Starting full AI recipe generation for user: ${user.uid}');

      // Get user's available ingredients from Firebase
      final itemsRef = FirebaseFirestore.instance.collection('items');
      final itemsQuery = await itemsRef
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'In-stock')
          .get();

      print('📦 FIREBASE INVENTORY: Found ${itemsQuery.docs.length} items in user\'s inventory');

      // Extract ingredient names
      List<String> availableIngredients = itemsQuery.docs
          .map((doc) {
            final name = doc.data()['name'] as String?;
            print('✅ Available ingredient: $name');
            return name ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toList();

      print('🥘 INGREDIENT LIST: ${availableIngredients.join(', ')}');

      // Get expiring ingredients
      List<String> expiringIngredients = _expiringItems
          .map((item) => item['name'] as String)
          .toList();

      print('⏰ EXPIRING INGREDIENTS: ${expiringIngredients.join(', ')}');

      // Force clear previous recipes to ensure fresh generation
      setState(() {
        _aiGeneratedRecipes = [];
      });

      // Add small delay to show loading state
      await Future.delayed(Duration(milliseconds: 500));

      print('🤖 AI GENERATION: Creating recipes using Firebase inventory...');
      
      // Generate AI recipe suggestions using Firebase ingredients
      final aiRecipes = await AIRecipeService.generateRecipeSuggestions(
        availableIngredients: availableIngredients,
        expiringIngredients: expiringIngredients,
        maxRecipes: 5,
      );

      print('✨ AI SUCCESS: Generated ${aiRecipes.length} fully AI-powered recipes!');
      
      // Log each generated recipe
      for (int i = 0; i < aiRecipes.length; i++) {
        final recipe = aiRecipes[i];
        print('🍽️ Recipe ${i + 1}: ${recipe['name']}');
        print('   📋 Ingredients: ${(recipe['ingredients'] as List).where((ing) => ing['available'] == true).map((ing) => ing['name']).join(', ')}');
      }

      setState(() {
        _aiGeneratedRecipes = aiRecipes;
        _loadingAIRecipes = false;
      });

      // Show success message when refresh completes
      if (mounted && aiRecipes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('🤖 Generated ${aiRecipes.length} AI recipes using your inventory!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (error) {
      print('❌ ERROR: Failed to generate AI recipes: $error');
      setState(() {
        _aiGeneratedRecipes = [];
        _loadingAIRecipes = false;
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Unable to generate AI recipes. Please try again.'),
              ],
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _fetchAIRecipeSuggestions(),
            ),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Add this method to build the AI recipe section
  Widget _buildAIRecipeSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'AI Recipe ',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: lightColorScheme.primary,
                        ),
                      ),
                      Text(
                        'Suggestions',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _loadingAIRecipes ? null : () {
                      // Add haptic feedback
                      // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback
                      
                      // Show immediate visual feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Generating fresh AI recipes...'),
                            ],
                          ),
                          backgroundColor: lightColorScheme.primary,
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      
                      // Refresh AI recipes
                      _fetchAIRecipeSuggestions();
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _loadingAIRecipes 
                          ? Colors.grey.withOpacity(0.3)
                          : lightColorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _loadingAIRecipes 
                            ? Colors.grey
                            : lightColorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_loadingAIRecipes)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            )
                          else
                            Icon(
                              Icons.refresh,
                              size: 16,
                              color: lightColorScheme.primary,
                            ),
                          SizedBox(width: 4),
                          Text(
                            _loadingAIRecipes ? '...' : 'Refresh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _loadingAIRecipes 
                                ? Colors.grey
                                : lightColorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 280,
          child: _loadingAIRecipes
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(lightColorScheme.primary),
                            strokeWidth: 3,
                          ),
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Creating AI recipes from your inventory...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Using ingredients from your Firebase database',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : _aiGeneratedRecipes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No AI recipe suggestions available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Tap refresh to generate new recipes!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      itemCount: _aiGeneratedRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = _aiGeneratedRecipes[index];
                        return _buildAIRecipeCard(recipe);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAIRecipeCard(Map<String, dynamic> recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AIRecipeDetails(recipe: recipe),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 14.0),
        child: Container(
          width: 210,
          margin: const EdgeInsets.symmetric(vertical: 8),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe Image
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: recipe['imageUrl'] != null && recipe['imageUrl'].isNotEmpty
                      ? Image.network(
                          recipe['imageUrl'],
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 120,
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
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: Colors.purple),
                          SizedBox(width: 2),
                          Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    // Recipe Name
                    Text(
                      recipe['name'] ?? 'AI Recipe',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    
                    // Time and Difficulty
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: lightColorScheme.primary),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            recipe['timeRequired'] ?? 'Unknown',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.bar_chart, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          recipe['difficulty'] ?? 'Medium',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 120,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 30,
            color: Colors.grey[400],
          ),
          SizedBox(height: 4),
          Text(
            'Recipe Image',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['fullName'] ?? 'User';
          });
        }

        await _fetchGroceryCount(user.uid);
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _userName = 'User';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGroceryCount(String userId) async {
    try {
      final dryGroceriesSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'Dry Groceries')
          .get();

      final wetGroceriesSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'Wet Groceries')
          .get();

      setState(() {
        _dryGroceryCount = dryGroceriesSnapshot.docs.length;
        _wetGroceryCount = wetGroceriesSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching grocery count: $e');
      setState(() {
        _dryGroceryCount = 0;
        _wetGroceryCount = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchExpiringItems() async {
    try {
      setState(() => _loadingExpiringItems = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();

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

          if (daysLeft <= 5 && daysLeft >= 0) {
            items.add({
              ...data,
              'daysLeft': daysLeft,
              'expiryFormatted': _formatExpiryText(daysLeft),
            });
          }
        }
      }

      items.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));
      items = items.take(3).toList();

      setState(() {
        _expiringItems = items;
        _loadingExpiringItems = false;
      });
    } catch (e) {
      setState(() => _loadingExpiringItems = false);
      print('Error fetching expiring items: $e');
    }
  }

  String _formatExpiryText(int daysLeft) {
    if (daysLeft == 0) return 'Expires today!';
    if (daysLeft == 1) return '1 day';
    return '$daysLeft days';
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String currentDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(25.0, 25.0, 25.0, 15.0),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Row(
                children: [
                  Text(
                    'Hello, ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: lightColorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                height: 245,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF048C03),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          currentDate,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 0.7,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Groceries in-stock',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                        ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7D903)),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Dry',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$_dryGroceryCount',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF7D903),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 50,
                          width: 1,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        Column(
                          children: [
                            Text(
                              'Wet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$_wetGroceryCount',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF7D903),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
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
                            'Expiring ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Text(
                            'Soon',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ExpiringSoonHH()),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 17,
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
            const SizedBox(height: 5),
            Container(
              height: 280,
              child: _loadingExpiringItems
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(lightColorScheme.primary),
                ),
              )
                  : _expiringItems.isEmpty
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
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                itemCount: _expiringItems.length,
                itemBuilder: (context, index) {
                  final item = _expiringItems[index];

                  return Padding(
                    padding: EdgeInsets.only(right: index < _expiringItems.length - 1 ? 15.0 : 0),
                    child: Container(
                      width: 240,
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
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item['imageUrl'] != null
                                    ? Image.network(
                                  item['imageUrl'],
                                  width: 200,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 200,
                                      height: 150,
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
                                  width: 200,
                                  height: 150,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Text(
                                'Name: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item['name'] ?? 'Unknown Item',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                'Expired in: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                              Text(
                                item['expiryFormatted'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
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
            const SizedBox(height: 20),
            
            // AI Recipe Section (replacing the database recipe section)
            _buildAIRecipeSection(),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}