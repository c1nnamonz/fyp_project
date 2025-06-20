import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/household/expiringSoonHH.dart';
import 'package:fyp_project/household/recipeDetails.dart';
import 'package:fyp_project/household/recipeSuggestion.dart';
import 'package:fyp_project/household/rootPageHH.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> _recipes = [];
  bool _loadingRecipes = true;
  List<Map<String, dynamic>> _expiringItems = [];
  bool _loadingExpiringItems = true;
  List<Map<String, dynamic>> _ingredientBasedRecipes = [];
  List<Map<String, dynamic>> _expiringItemRecipes = [];
  bool _loadingIngredientRecipes = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchIngredientBasedRecipes();
    _fetchExpiringItems();
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

      // Fetch recipes for expiring items
      if (items.isNotEmpty) {
        await _fetchRecipesForExpiringItems(items);
      }

      setState(() {
        _expiringItems = items;
        _loadingExpiringItems = false;
      });
    } catch (e) {
      setState(() => _loadingExpiringItems = false);
      print('Error fetching expiring items: $e');
    }
  }

  Future<void> _fetchRecipesForExpiringItems(List<Map<String, dynamic>> items) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all ingredients
      final ingredientsRef = FirebaseFirestore.instance.collection('ingredients');
      final ingredientsQuery = await ingredientsRef.get();

      // Create a set to store recipe IDs that match expiring items
      Set<String> matchingRecipeIds = {};

      // Check each ingredient to see if it matches expiring items
      for (var ingredientDoc in ingredientsQuery.docs) {
        final ingredientData = ingredientDoc.data();
        final ingredientName = (ingredientData['name'] as String).toLowerCase();
        final recipeId = ingredientData['recipeId'] as String?;

        if (recipeId != null) {
          // Check if ingredient name matches any of expiring items
          for (var item in items) {
            final itemName = (item['name'] as String).toLowerCase();
            if (_isIngredientMatch(ingredientName, itemName)) {
              matchingRecipeIds.add(recipeId);
              break;
            }
          }
        }
      }

      // Fetch the matching recipes
      List<Map<String, dynamic>> matchingRecipes = [];

      if (matchingRecipeIds.isNotEmpty) {
        final recipesRef = FirebaseFirestore.instance.collection('recipes');

        // Fetch recipes in batches (Firestore 'in' query has a limit of 10)
        List<String> recipeIdsList = matchingRecipeIds.toList();
        for (int i = 0; i < recipeIdsList.length; i += 10) {
          int end = (i + 10 < recipeIdsList.length) ? i + 10 : recipeIdsList.length;
          List<String> batch = recipeIdsList.sublist(i, end);

          final batchQuery = await recipesRef.where(FieldPath.documentId, whereIn: batch).get();

          for (var recipeDoc in batchQuery.docs) {
            final recipeData = recipeDoc.data();
            matchingRecipes.add({
              'id': recipeDoc.id,
              'name': recipeData['name'] ?? 'Unknown Recipe',
              'category': recipeData['category'] ?? 'Uncategorized',
              'imageUrl': recipeData['imageUrl'] ?? 'images/default_recipe.jpg',
            });
          }
        }
      }

      setState(() {
        _expiringItemRecipes = matchingRecipes.take(3).toList();
      });
    } catch (error) {
      print('Error fetching recipes for expiring items: $error');
    }
  }

  Future<void> _fetchIngredientBasedRecipes() async {
    try {
      setState(() => _loadingIngredientRecipes = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Step 1: Get user's items
      final itemsRef = FirebaseFirestore.instance.collection('items');
      final itemsQuery = await itemsRef.where('userId', isEqualTo: user.uid).get();

      if (itemsQuery.docs.isEmpty) {
        setState(() {
          _ingredientBasedRecipes = [];
          _loadingIngredientRecipes = false;
        });
        return;
      }

      // Step 2: Get ingredients that match user's items
      final ingredientsRef = FirebaseFirestore.instance.collection('ingredients');
      final ingredientsQuery = await ingredientsRef.get();

      // Create a set to store recipe IDs that match user's items
      Set<String> matchingRecipeIds = {};

      // Get user's item names for comparison
      List<String> userItemNames = itemsQuery.docs
          .map((doc) => (doc.data()['name'] as String).toLowerCase())
          .toList();

      // Check each ingredient to see if it matches user's items
      for (var ingredientDoc in ingredientsQuery.docs) {
        final ingredientData = ingredientDoc.data();
        final ingredientName = (ingredientData['name'] as String).toLowerCase();
        final recipeId = ingredientData['recipeId'] as String?;

        if (recipeId != null) {
          for (String userItem in userItemNames) {
            if (_isIngredientMatch(ingredientName, userItem)) {
              matchingRecipeIds.add(recipeId);
              break;
            }
          }
        }
      }

      // Step 3: Fetch the matching recipes
      List<Map<String, dynamic>> matchingRecipes = [];

      if (matchingRecipeIds.isNotEmpty) {
        final recipesRef = FirebaseFirestore.instance.collection('recipes');

        // Fetch recipes in batches
        List<String> recipeIdsList = matchingRecipeIds.toList();
        for (int i = 0; i < recipeIdsList.length; i += 10) {
          int end = (i + 10 < recipeIdsList.length) ? i + 10 : recipeIdsList.length;
          List<String> batch = recipeIdsList.sublist(i, end);

          final batchQuery = await recipesRef.where(FieldPath.documentId, whereIn: batch).get();

          for (var recipeDoc in batchQuery.docs) {
            final recipeData = recipeDoc.data();
            matchingRecipes.add({
              'id': recipeDoc.id,
              'name': recipeData['name'] ?? 'Unknown Recipe',
              'category': recipeData['category'] ?? 'Uncategorized',
              'imageUrl': recipeData['imageUrl'] ?? 'images/default_recipe.jpg',
            });
          }
        }
      }

      setState(() {
        _ingredientBasedRecipes = matchingRecipes.take(3).toList();
        _loadingRecipes = false;
        _loadingIngredientRecipes = false;
      });

    } catch (error) {
      print('Error fetching ingredient-based recipes: $error');
      setState(() {
        _ingredientBasedRecipes = [];
        _loadingRecipes = false;
        _loadingIngredientRecipes = false;
      });
    }
  }

  bool _isIngredientMatch(String ingredientName, String userItemName) {
    // Direct match
    if (ingredientName == userItemName) return true;

    // Contains match (ingredient contains user item or vice versa)
    if (ingredientName.contains(userItemName) || userItemName.contains(ingredientName)) {
      return true;
    }

    // Specific matches for common variations
    Map<String, List<String>> commonMatches = {
      'cereal': ['corn flakes', 'cereals', 'breakfast cereal'],
      'corn flakes': ['cereal', 'cereals'],
      'milk': ['dairy milk', 'fresh milk', 'whole milk'],
      'chicken': ['chicken breast', 'chicken thigh', 'whole chicken'],
      'fish': ['salmon', 'tuna', 'cod', 'tilapia'],
      'egg': ['eggs', 'chicken egg'],
      'onion': ['onions', 'yellow onion', 'white onion'],
    };

    for (String key in commonMatches.keys) {
      if ((ingredientName.contains(key) && commonMatches[key]!.any((match) => userItemName.contains(match))) ||
          (userItemName.contains(key) && commonMatches[key]!.any((match) => ingredientName.contains(match)))) {
        return true;
      }
    }

    return false;
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
              height: 330,
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
                          // Show matching recipes for this item if available
                          if (_expiringItemRecipes.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Matching Recipes:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: lightColorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 5,),
                            SizedBox(
                              height: 32,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _expiringItemRecipes.length,
                                itemBuilder: (context, recipeIndex) {
                                  final recipe = _expiringItemRecipes[recipeIndex];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RecipeDetails(recipeId: recipe['id']),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Chip(
                                        label: Text(
                                          recipe['name'],
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: Colors.green[100],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
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
                            'Quick ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          Text(
                            'Recipe',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xDEFFC717),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RecipeSuggestion()),
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
              child: _loadingIngredientRecipes
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(lightColorScheme.primary),
                ),
              )
                  : _ingredientBasedRecipes.isEmpty
                  ? Center(
                child: Text(
                  'No recipes found based on your ingredients',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              )
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                itemCount: _ingredientBasedRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = _ingredientBasedRecipes[index];
                  return Padding(
                    padding: EdgeInsets.only(right: index < _ingredientBasedRecipes.length - 1 ? 15.0 : 0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetails(recipeId: recipe['id']),
                          ),
                        );
                      },
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
                                  child: Image.network(
                                    recipe['imageUrl'],
                                    width: 200,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'images/default_recipe.jpg',
                                        width: 200,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      );
                                    },
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
                                    recipe['name'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD6BC00),
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
                                  'Categories: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: lightColorScheme.primary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    recipe['category'],
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}