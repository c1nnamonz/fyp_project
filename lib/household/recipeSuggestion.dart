import 'package:flutter/material.dart';
import 'package:fyp_project/household/recipeDetails.dart';
import 'package:fyp_project/household/rootPageHH.dart';
import '../theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeSuggestion extends StatefulWidget {
  const RecipeSuggestion({super.key});

  @override
  State<RecipeSuggestion> createState() => _RecipeSuggestionState();
}

class _RecipeSuggestionState extends State<RecipeSuggestion> {
  // Stores recipes by category
  Map<String, List<Map<String, dynamic>>> recipesByCategory = {};
  // Stores ingredient-based recipe suggestions
  List<Map<String, dynamic>> ingredientBasedRecipes = [];
  bool isLoading = true;
  bool loadingIngredientRecipes = false;

  @override
  void initState() {
    super.initState();
    fetchRecipesFromFirebase();
    fetchIngredientBasedRecipes();
  }

  // Helper method to get a default image based on recipe name
  String getDefaultImageForRecipe(String name) {
    name = name.toLowerCase();

    if (name.contains('cereal')) {
      return 'images/cereal.jpeg';
    } else if (name.contains('omelette')) {
      return 'images/omelette.jpg';
    } else if (name.contains('bawang') || name.contains('holland')) {
      return 'images/bawang.png';
    } else if (name.contains('chicken') || name.contains('rotisserie')) {
      return 'images/chickenros.jpg';
    } else if (name.contains('fish')) {
      return 'images/fish.jpg';
    }

    // Default image if no match
    return 'images/foodicon.png';
  }

  // UPDATED: Fetch ingredient-based recipe suggestions with corrected logic
  Future<void> fetchIngredientBasedRecipes() async {
    try {
      setState(() => loadingIngredientRecipes = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          ingredientBasedRecipes = [];
          loadingIngredientRecipes = false;
        });
        return;
      }

      print('Fetching ingredient-based recipes for user: ${user.uid}');

      // Step 1: Get user's items - ONLY IN-STOCK items
      final itemsRef = FirebaseFirestore.instance.collection('items');
      final itemsQuery = await itemsRef
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'In-stock')  // Updated to match your working logic
          .get();

      print('Found ${itemsQuery.docs.length} in-stock items for user');

      if (itemsQuery.docs.isEmpty) {
        setState(() {
          ingredientBasedRecipes = [];
          loadingIngredientRecipes = false;
        });
        return;
      }

      // Step 2: Get ingredients that match user's items
      final ingredientsRef = FirebaseFirestore.instance.collection('ingredients');
      final ingredientsQuery = await ingredientsRef.get();

      print('Found ${ingredientsQuery.docs.length} total ingredients');

      // Create a set to store recipe IDs that match user's items
      Set<String> matchingRecipeIds = {};

      // Get user's item names for comparison - only from in-stock items
      List<String> userItemNames = itemsQuery.docs
          .map((doc) => (doc.data()['name'] as String).toLowerCase())
          .toList();

      print('User in-stock items: $userItemNames');

      // Check each ingredient to see if it matches user's items
      for (var ingredientDoc in ingredientsQuery.docs) {
        final ingredientData = ingredientDoc.data();
        final ingredientName = (ingredientData['name'] as String).toLowerCase();
        final recipeId = ingredientData['recipeId'] as String?;

        if (recipeId != null) {
          for (String userItem in userItemNames) {
            if (_isIngredientMatch(ingredientName, userItem)) {
              matchingRecipeIds.add(recipeId);
              print('Match found: $ingredientName matches $userItem, recipe: $recipeId');
              break;
            }
          }
        }
      }

      print('Matching recipe IDs: $matchingRecipeIds');

      // Step 3: Fetch the matching recipes
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
              'timeRequired': recipeData['timeRequired'] ?? 'Unknown',
              'imageUrl': recipeData['imageUrl'] ?? '',
              'category': recipeData['category'] ?? 'Uncategorized',
              'description': recipeData['description'] ?? '',
              'instructions': recipeData['instructions'] ?? '',
            });
          }
        }
      }

      print('Found ${matchingRecipes.length} matching recipes');

      setState(() {
        ingredientBasedRecipes = matchingRecipes; // Show all matching recipes, not limited to 3
        loadingIngredientRecipes = false;
      });

    } catch (error) {
      print('Error fetching ingredient-based recipes: $error');
      setState(() {
        ingredientBasedRecipes = [];
        loadingIngredientRecipes = false;
      });
    }
  }

  // ADDED: Method to fetch recipes for a specific item (from your homepage logic)
  Future<List<Map<String, dynamic>>> fetchRecipesForSpecificItem(String itemName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Get all ingredients
      final ingredientsRef = FirebaseFirestore.instance.collection('ingredients');
      final ingredientsQuery = await ingredientsRef.get();

      // Create a set to store recipe IDs that match this specific item
      Set<String> matchingRecipeIds = {};

      // Check each ingredient to see if it matches this specific item
      for (var ingredientDoc in ingredientsQuery.docs) {
        final ingredientData = ingredientDoc.data();
        final ingredientName = (ingredientData['name'] as String).toLowerCase();
        final recipeId = ingredientData['recipeId'] as String?;

        if (recipeId != null) {
          // Check if ingredient name matches this specific item
          final itemNameLower = itemName.toLowerCase();
          if (_isIngredientMatch(ingredientName, itemNameLower)) {
            matchingRecipeIds.add(recipeId);
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
              'timeRequired': recipeData['timeRequired'] ?? 'Unknown',
              'imageUrl': recipeData['imageUrl'] ?? '',
              'category': recipeData['category'] ?? 'Uncategorized',
              'description': recipeData['description'] ?? '',
              'instructions': recipeData['instructions'] ?? '',
            });
          }
        }
      }

      return matchingRecipes.take(3).toList();
    } catch (error) {
      print('Error fetching recipes for specific item: $error');
      return [];
    }
  }

  // Helper method to check if ingredient matches user's item
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

  // Fetch recipes from Firebase
  Future<void> fetchRecipesFromFirebase() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Changed to query the 'recipes' collection directly
      final recipesRef = FirebaseFirestore.instance.collection('recipes');
      final QuerySnapshot querySnapshot = await recipesRef.get();

      print('Fetched ${querySnapshot.docs.length} recipes from Firestore'); // Debug log

      // Temporary map to store recipes by category
      Map<String, List<Map<String, dynamic>>> tempMap = {};

      // Process each recipe document
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Use a default category if none is specified
        final category = data['category'] ?? 'Uncategorized';

        // Debug log for each document
        print('Processing document: ${doc.id}, category: $category');

        // Convert Firestore document to map with the necessary fields
        final recipeMap = {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Recipe',
          'timeRequired': data['timeRequired'] ?? 'Unknown',
          'imageUrl': data['imageUrl'] ?? '',
          'category': category,
          'description': data['description'] ?? '',
          'instructions': data['instructions'] ?? '',
        };

        // Add recipe to the appropriate category list
        if (!tempMap.containsKey(category)) {
          tempMap[category] = [];
        }
        tempMap[category]!.add(recipeMap);
      }

      // Only use fallback data if no recipes were found
      if (tempMap.isEmpty) {
        print('No recipes found in database, using fallback data');

        // Add example Quick & Eazy recipes
        tempMap['Quick & Eazy'] = [
          {
            'id': 'cereal',
            'name': 'Cereal',
            'timeRequired': '2 mins',
            'imageUrl': '',
            'category': 'Quick & Eazy',
            'description': 'A quick breakfast option',
            'instructions': 'Pour cereal into bowl. Add milk. Enjoy!',
          },
          {
            'id': 'omelette',
            'name': 'Omelette',
            'timeRequired': '6 mins',
            'imageUrl': '',
            'category': 'Quick & Eazy',
            'description': 'Simple egg dish',
            'instructions': 'Beat eggs, pour into hot pan, add fillings, fold, serve.',
          },
        ];

        // Add example Rich & Régal recipes
        tempMap['Rich & Régal'] = [
          {
            'id': 'chicken',
            'name': 'Rotisserie Chicken',
            'timeRequired': '60 mins',
            'imageUrl': '',
            'category': 'Rich & Régal',
            'description': 'Delicious roasted chicken',
            'instructions': 'Season chicken, roast at 180°C for 1 hour, basting occasionally.',
          },
          {
            'id': 'fish',
            'name': 'Fish',
            'timeRequired': '75 mins',
            'imageUrl': '',
            'category': 'Rich & Régal',
            'description': 'Baked fish with herbs',
            'instructions': 'Season fish, bake at 180°C for 20 minutes with herbs and lemon.',
          },
        ];
      }

      setState(() {
        recipesByCategory = tempMap;
        isLoading = false;
      });
    } catch (error) {
      print('Error fetching recipes: $error');

      // If error occurs, provide fallback data
      final Map<String, List<Map<String, dynamic>>> fallbackData = {
        'Quick & Eazy': [
          {
            'id': 'cereal',
            'name': 'Cereal',
            'timeRequired': '2 mins',
            'imageUrl': '',
            'category': 'Quick & Eazy',
            'description': 'A quick breakfast option',
            'instructions': 'Pour cereal into bowl. Add milk. Enjoy!',
          },
          {
            'id': 'omelette',
            'name': 'Omelette',
            'timeRequired': '6 mins',
            'imageUrl': '',
            'category': 'Quick & Eazy',
            'description': 'Simple egg dish',
            'instructions': 'Beat eggs, pour into hot pan, add fillings, fold, serve.',
          },
          {
            'id': 'bawang',
            'name': 'Bawang Holland',
            'timeRequired': '3 mins',
            'imageUrl': '',
            'category': 'Quick & Eazy',
            'description': 'Quick side dish',
            'instructions': 'Slice onions, sauté until translucent.',
          },
        ],
        'Rich & Régal': [
          {
            'id': 'chicken',
            'name': 'Rotisserie Chicken',
            'timeRequired': '60 mins',
            'imageUrl': '',
            'category': 'Rich & Régal',
            'description': 'Delicious roasted chicken',
            'instructions': 'Season chicken, roast at 180°C for 1 hour, basting occasionally.',
          },
          {
            'id': 'fish',
            'name': 'Fish',
            'timeRequired': '75 mins',
            'imageUrl': '',
            'category': 'Rich & Régal',
            'description': 'Baked fish with herbs',
            'instructions': 'Season fish, bake at 180°C for 20 minutes with herbs and lemon.',
          },
          {
            'id': 'bawang2',
            'name': 'Bawang Holland',
            'timeRequired': '40 mins',
            'imageUrl': '',
            'category': 'Rich & Régal',
            'description': 'Rich side dish',
            'instructions': 'Caramelize onions slowly for 30-40 minutes until deeply golden.',
          },
        ],
      };

      setState(() {
        recipesByCategory = fallbackData;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        title: const Text(
          'Recipe Suggestions',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(45.0, 40.0, 45.0, 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'nyum nyum ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  ClipRRect(
                    child: Image.asset(
                      'images/foodicon.png',
                      width: 35,
                      height: 35,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ALWAYS show ingredient-based recipes section
            _buildIngredientBasedSection(),

            // ALWAYS show the separator
            _buildBeautifulSeparator(),

            // ALWAYS display recipes for each category
            for (final category in recipesByCategory.keys)
              _buildCategorySection(category, recipesByCategory[category]!),
          ],
        ),
      ),
    );
  }

  // Build a beautiful separator
  Widget _buildBeautifulSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 22.0),
      child: Column(
        children: [
          // Decorative line with center element
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        lightColorScheme.primary.withOpacity(0.3),
                        lightColorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 15.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      lightColorScheme.primary.withOpacity(0.1),
                      const Color(0xFFD6BC00).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: lightColorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: lightColorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All Recipes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: lightColorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.restaurant_menu,
                      color: lightColorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        lightColorScheme.primary.withOpacity(0.7),
                        lightColorScheme.primary.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Subtle description text
          Text(
            'Discover more delicious recipes from our complete collection',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build the ingredient-based recipes section (UPDATED to handle loading state)
  Widget _buildIngredientBasedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 5.0, 22.0, 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIngredientBasedHeader(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 240,
          child: loadingIngredientRecipes
              ? Center(child: CircularProgressIndicator())
              : ingredientBasedRecipes.isEmpty
              ? _buildEmptyIngredientsMessage()
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            itemCount: ingredientBasedRecipes.length,
            itemBuilder: (context, index) {
              final recipe = ingredientBasedRecipes[index];
              return _buildRecipeCard(recipe);
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // Build empty ingredients message
  Widget _buildEmptyIngredientsMessage() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No recipes found for your current ingredients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add more items to your inventory to get personalized recipe suggestions!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build the ingredient-based header
  Widget _buildIngredientBasedHeader() {
    return Row(
      children: [
        Text(
          'Based on ',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: lightColorScheme.primary,
          ),
        ),
        Text(
          'Your ',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD6BC00),
          ),
        ),
        Text(
          'Ingredients',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  // Build the category header with custom styling
  Widget _buildCategoryHeader(String category) {
    // For "Quick & Eazy" category
    if (category == 'Quick & Eazy') {
      return Row(
        children: [
          Text(
            'Quick ',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: lightColorScheme.primary,
            ),
          ),
          Text(
            '& Eazy',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD6BC00),
            ),
          ),
        ],
      );
    }
    // For "Rich & Régal" category
    else if (category == 'Rich & Régal') {
      return Row(
        children: [
          Text(
            'Rich ',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: lightColorScheme.primary,
            ),
          ),
          Text(
            '& ',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          Text(
            'Régal ',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD6BC00),
            ),
          ),
        ],
      );
    }
    // Default styling for other categories
    else {
      return Text(
        category,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: lightColorScheme.primary,
        ),
      );
    }
  }

  // Build a complete category section with header and horizontal recipe list
  Widget _buildCategorySection(String category, List<Map<String, dynamic>> recipes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 5.0, 22.0, 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategoryHeader(category),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _buildRecipeCard(recipe);
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // Build an individual recipe card
  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return GestureDetector(
      onTap: () {
        // Navigate to recipe details page with the recipe data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetails(recipeId: recipe['id']),
          ),
        );
      },
      child: Padding(
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
                    child: recipe['imageUrl'] != null && recipe['imageUrl'].isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: recipe['imageUrl'],
                      width: 170,
                      height: 130,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 170,
                        height: 130,
                        color: Colors.grey[200],
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        getDefaultImageForRecipe(recipe['name']),
                        width: 170,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Image.asset(
                      getDefaultImageForRecipe(recipe['name']),
                      width: 170,
                      height: 130,
                      fit: BoxFit.cover,
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
                      recipe['name'] ?? 'Unknown',
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
                    'Time required: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: lightColorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      recipe['timeRequired'] ?? 'Unknown',
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
            ],
          ),
        ),
      ),
    );
  }
}