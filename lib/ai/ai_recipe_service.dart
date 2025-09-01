import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fyp_project/ai/recipe_image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIRecipeService {
  // Get your free API key from https://platform.openai.com/api-keys
  static const String _apiKey = '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'; // Add your API key
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<List<Map<String, dynamic>>> generateRecipeSuggestions({
    required List<String> availableIngredients,
    List<String>? expiringIngredients,
    String? dietaryRestrictions,
    String? cuisinePreference,
    int maxRecipes = 5,
  }) async {
    try {
      print('Starting AI recipe generation with ingredients: $availableIngredients');
      
      // If no ingredients available, get them directly from Firebase
      List<String> ingredients = availableIngredients;
      if (ingredients.isEmpty) {
        ingredients = await _getAvailableIngredientsFromFirebase();
        print('Fetched ingredients from Firebase: $ingredients');
      }
      
      // If still no ingredients, return fallback recipes
      if (ingredients.isEmpty) {
        print('No ingredients found, returning fallback recipes');
        return await _getFallbackRecipes([]);
      }

      // Add randomization to prompt for variety on refresh
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSeed = timestamp % 1000; // Use timestamp for randomness
      
      // Create a detailed prompt for the AI
      String prompt = _buildRecipePrompt(
        ingredients,
        expiringIngredients,
        dietaryRestrictions,
        cuisinePreference,
        maxRecipes,
        randomSeed, // Pass random seed for variety
      );

      print('Generated prompt for AI: $prompt');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a professional chef and recipe expert. Generate practical, delicious recipes based on available ingredients. Always respond with valid JSON format. Create DIFFERENT and UNIQUE recipes each time, never repeat the same combinations.'
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 2000,
          'temperature': 0.9, // Increased temperature for more creativity/randomness
          'top_p': 0.95, // Add top_p for more diverse outputs
        }),
      );

      print('OpenAI API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        print('AI Response content: $content');
        
        // Parse the AI response into structured recipe data
        final recipes = await _parseRecipeResponse(content);
        print('Parsed ${recipes.length} recipes successfully');
        return recipes;
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        // Return randomized fallback recipes instead of throwing
        return await _getFallbackRecipes(ingredients, randomSeed: randomSeed);
      }
    } catch (e) {
      print('Error generating AI recipes: $e');
      final fallbackIngredients = availableIngredients.isEmpty ? await _getAvailableIngredientsFromFirebase() : availableIngredients;
      return await _getFallbackRecipes(fallbackIngredients, randomSeed: DateTime.now().millisecondsSinceEpoch);
    }
  }

  // Add method to get ingredients directly from Firebase
  static Future<List<String>> _getAvailableIngredientsFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return [];
      }

      final itemsRef = FirebaseFirestore.instance.collection('items');
      final itemsQuery = await itemsRef
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'In-stock')
          .get();

      print('Found ${itemsQuery.docs.length} items in Firebase for user ${user.uid}');

      List<String> ingredients = [];
      for (var doc in itemsQuery.docs) {
        final data = doc.data();
        print('Item: ${data['name']} - Status: ${data['status']}');
        
        if (data['name'] != null) {
          ingredients.add(data['name'].toString().toLowerCase().trim());
        }
      }

      print('Available ingredients: $ingredients');
      return ingredients;
    } catch (e) {
      print('Error fetching ingredients from Firebase: $e');
      return [];
    }
  }

  static String _buildRecipePrompt(
    List<String> availableIngredients,
    List<String>? expiringIngredients,
    String? dietaryRestrictions,
    String? cuisinePreference,
    int maxRecipes,
    int randomSeed,
  ) {
    StringBuffer prompt = StringBuffer();
    
    prompt.writeln('GENERATE AUTHENTIC ASIAN CUISINE RECIPES! Randomization seed: $randomSeed');
    prompt.writeln('Create $maxRecipes DIVERSE Asian recipe suggestions using ONLY ingredients from this available inventory:');
    prompt.writeln('AVAILABLE INGREDIENTS IN USER\'S FIREBASE DATABASE: ${availableIngredients.join(', ')}');
    
    if (expiringIngredients != null && expiringIngredients.isNotEmpty) {
      prompt.writeln('PRIORITIZE these expiring ingredients: ${expiringIngredients.join(', ')}');
    }
    
    if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
      prompt.writeln('Dietary restrictions: $dietaryRestrictions');
    }
    
    prompt.writeln('''
🍜 ASIAN CUISINE FOCUS REQUIREMENTS:
- Create recipes inspired by Chinese, Japanese, Thai, Korean, Vietnamese, Malaysian, and Indonesian cuisines
- Use traditional Asian cooking techniques: stir-frying, steaming, braising, deep-frying, grilling
- Focus on authentic Asian flavor profiles: soy sauce, ginger, garlic, sesame, rice vinegar, miso, etc.
- Create dishes like: fried rice, noodle dishes, curry, soup, stir-fry, dumplings, etc.

🧑‍🍳 INGREDIENT COMBINATION LOGIC:
- NEVER combine incompatible ingredients (e.g., cereal + chicken, dessert items + meat)
- Follow these logical Asian ingredient pairings:

PROTEIN COMBINATIONS:
- Chicken: pairs with rice, vegetables, noodles, egg, ginger, soy sauce
- Beef: pairs with broccoli, onions, rice, noodles, garlic, oyster sauce
- Pork: pairs with bok choy, rice, noodles, sweet and sour flavors
- Fish: pairs with ginger, soy sauce, vegetables, rice, steaming techniques
- Egg: pairs with rice, vegetables, noodles, tomato, scallions
- Tofu: pairs with vegetables, soy sauce, miso, mushrooms, rice

CARBOHYDRATE BASES:
- Rice: perfect for fried rice, rice bowls, congee, sushi
- Noodles: ideal for stir-fries, soups, pad thai, ramen
- Bread: use for Asian-style sandwiches, steamed buns, toast

VEGETABLE COMBINATIONS:
- Asian greens (bok choy, cabbage, spinach) with garlic, ginger
- Root vegetables (carrot, potato) for curries, stews
- Tomatoes with egg, beef, or in sweet and sour dishes
- Onions as base for most Asian stir-fries and curries

🍽️ RECIPE CATEGORIES AND AUTHENTIC NAMES:
- Chinese: "Yangzhou Fried Rice", "Mapo Tofu", "Sweet and Sour Pork"
- Japanese: "Chicken Teriyaki", "Miso Soup", "Gyudon Beef Bowl"
- Thai: "Pad Thai", "Green Curry", "Tom Yum Soup"
- Korean: "Kimchi Fried Rice", "Bulgogi", "Bibimbap"
- Vietnamese: "Pho", "Banh Mi", "Vietnamese Spring Rolls"
- Malaysian: "Nasi Lemak", "Char Kway Teow", "Rendang"
- Indonesian: "Nasi Goreng", "Gado-Gado", "Ayam Bakar"

🥢 ASIAN PANTRY INGREDIENTS TO ADD:
- Soy sauce (light/dark), oyster sauce, fish sauce
- Sesame oil, rice wine, rice vinegar
- Ginger, garlic, lemongrass, chili
- Miso paste, hoisin sauce, sriracha
- Coconut milk, tamarind paste
- Five-spice powder, star anise, white pepper

EXAMPLE OF PROPER ASIAN COMBINATIONS:
If available ingredients are: ["chicken", "rice", "egg", "onion", "carrot"]

Recipe 1: "Chinese Chicken Fried Rice" - chicken + rice + egg + soy sauce + sesame oil
Recipe 2: "Japanese Chicken Oyakodon" - chicken + egg + onion + rice + mirin
Recipe 3: "Thai Basil Chicken" - chicken + onion + carrot + fish sauce + thai basil
Recipe 4: "Korean Chicken Rice Bowl" - chicken + rice + carrot + gochujang + sesame
Recipe 5: "Vietnamese Chicken Curry" - chicken + carrot + onion + coconut milk + curry

🚨 CRITICAL ASIAN RECIPE RULES:
- NEVER mix breakfast cereals with savory Asian dishes
- NEVER combine dairy (milk/cheese) with traditional Asian recipes (except fusion dishes)
- NEVER create nonsensical combinations like "cereal chicken curry"
- Each recipe must be culturally authentic and make culinary sense
- Use proper Asian cooking terminology and techniques
- Focus on umami flavors and balance (sweet, sour, salty, spicy, bitter)

Please format the response as valid JSON with authentic Asian recipe names and proper ingredient combinations.''');
    
    return prompt.toString();
  }

  static Future<List<Map<String, dynamic>>> _parseRecipeResponse(String content) async {
    try {
      // Clean the response to extract JSON
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      
      final parsed = jsonDecode(jsonStr);
      final recipes = parsed['recipes'] as List;
      
      List<Map<String, dynamic>> processedRecipes = [];
      
      for (var recipe in recipes) {
        // Get image for each recipe
        final imageUrl = await RecipeImageService.getRecipeImage(
          recipe['name'] ?? 'Unknown Recipe',
          recipe['category'] ?? 'Main Course',
        );
        
        // Process ingredients to separate available from pantry items
        List<Map<String, dynamic>> processedIngredients = [];
        if (recipe['ingredients'] != null) {
          for (var ingredient in recipe['ingredients']) {
            processedIngredients.add({
              'name': ingredient['name'] ?? '',
              'quantity': ingredient['quantity'] ?? '',
              'unit': ingredient['unit'] ?? '',
              'available': ingredient['available'] ?? false,
            });
          }
        }
        
        processedRecipes.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString() + recipe['name'].hashCode.toString(),
          'name': recipe['name'] ?? 'AI Generated Recipe',
          'timeRequired': recipe['timeRequired'] ?? 'Unknown',
          'difficulty': recipe['difficulty'] ?? 'Medium',
          'category': recipe['category'] ?? 'Main Course',
          'description': recipe['description'] ?? '',
          'ingredients': processedIngredients,
          'instructions': recipe['instructions'] ?? [],
          'nutritionInfo': recipe['nutritionInfo'] ?? {},
          'imageUrl': imageUrl ?? 'assets/images/food_placeholder.png',
          'isAIGenerated': true,
        });
      }
      
      return processedRecipes;
      
    } catch (e) {
      print('Error parsing AI response: $e');
      return await _getFallbackRecipes([]);
    }
  }

  static Future<List<Map<String, dynamic>>> _getFallbackRecipes(List<String> ingredients, {int? randomSeed}) async {
    print('Creating Asian-style fallback recipes with Firebase ingredients: $ingredients');
    
    final seed = randomSeed ?? DateTime.now().millisecondsSinceEpoch;
    final random = seed % 100;
    
    List<Map<String, dynamic>> fallbackRecipes = [];
    
    if (ingredients.isNotEmpty) {
      // Create sensible Asian ingredient combinations
      final asianCombinations = _createAsianIngredientCombinations(ingredients);
      
      Set<String> usedCombinations = {};
      
      for (int i = 0; i < 5 && fallbackRecipes.length < 5; i++) {
        if (i < asianCombinations.length) {
          final combination = asianCombinations[i];
          String combinationKey = combination.join('-');
          
          if (!usedCombinations.contains(combinationKey)) {
            final recipe = await _createAsianStyleRecipe(
              combination,
              'asian_fallback_${seed}_${i}',
              random + i,
            );
            fallbackRecipes.add(recipe);
            usedCombinations.add(combinationKey);
          }
        }
      }
    } else {
      final defaultRecipes = await _getAsianDefaultRecipes(random);
      fallbackRecipes.addAll(defaultRecipes);
    }

    return fallbackRecipes;
  }

  static List<List<String>> _createAsianIngredientCombinations(List<String> ingredients) {
    List<List<String>> combinations = [];
    
    // Group ingredients by type for better combinations
    List<String> proteins = [];
    List<String> carbs = [];
    List<String> vegetables = [];
    List<String> others = [];
    
    for (String ingredient in ingredients) {
      final lower = ingredient.toLowerCase();
      if (_isProtein(lower)) {
        proteins.add(ingredient);
      } else if (_isCarbohydrate(lower)) {
        carbs.add(ingredient);
      } else if (_isVegetable(lower)) {
        vegetables.add(ingredient);
      } else {
        others.add(ingredient);
      }
    }
    
    // Create logical Asian combinations
    // Protein + Carb combinations
    for (String protein in proteins) {
      for (String carb in carbs) {
        combinations.add([protein, carb]);
        // Add vegetable if available
        if (vegetables.isNotEmpty) {
          combinations.add([protein, carb, vegetables.first]);
        }
      }
    }
    
    // Vegetarian combinations
    if (carbs.isNotEmpty && vegetables.isNotEmpty) {
      combinations.add([carbs.first, vegetables.first]);
      if (others.isNotEmpty && _isEgg(others.first.toLowerCase())) {
        combinations.add([carbs.first, vegetables.first, others.first]);
      }
    }
    
    // Protein + vegetable combinations (without carbs)
    for (String protein in proteins) {
      if (vegetables.isNotEmpty) {
        combinations.add([protein, vegetables.first]);
      }
    }
    
    // If no good combinations, just pair ingredients sensibly
    if (combinations.isEmpty && ingredients.length >= 2) {
      for (int i = 0; i < ingredients.length - 1; i++) {
        if (_areCompatibleIngredients(ingredients[i], ingredients[i + 1])) {
          combinations.add([ingredients[i], ingredients[i + 1]]);
        }
      }
    }
    
    return combinations.take(5).toList();
  }

  static bool _isProtein(String ingredient) {
    return ['chicken', 'beef', 'pork', 'fish', 'tofu', 'shrimp', 'duck'].any((p) => ingredient.contains(p));
  }
  
  static bool _isCarbohydrate(String ingredient) {
    return ['rice', 'noodle', 'pasta', 'bread', 'potato', 'sweet potato'].any((c) => ingredient.contains(c));
  }
  
  static bool _isVegetable(String ingredient) {
    return ['carrot', 'onion', 'garlic', 'ginger', 'cabbage', 'bok choy', 'broccoli', 
            'spinach', 'tomato', 'bell pepper', 'mushroom', 'bean sprout'].any((v) => ingredient.contains(v));
  }
  
  static bool _isEgg(String ingredient) {
    return ingredient.contains('egg');
  }
  
  static bool _areCompatibleIngredients(String ing1, String ing2) {
    final lower1 = ing1.toLowerCase();
    final lower2 = ing2.toLowerCase();
    
    // Avoid nonsensical combinations
    if ((lower1.contains('cereal') || lower1.contains('milk')) && (_isProtein(lower2))) return false;
    if ((lower2.contains('cereal') || lower2.contains('milk')) && (_isProtein(lower1))) return false;
    
    return true;
  }

  static Future<Map<String, dynamic>> _createAsianStyleRecipe(
    List<String> firebaseIngredients,
    String id,
    int randomVariation,
  ) async {
    // Asian cuisine styles and techniques
    final asianCuisines = [
      'Chinese', 'Japanese', 'Thai', 'Korean', 'Vietnamese', 
      'Malaysian', 'Indonesian', 'Singaporean'
    ];
    
    final asianTechniques = [
      'Stir-Fried', 'Steamed', 'Braised', 'Teriyaki', 'Szechuan',
      'Pad Thai Style', 'Korean BBQ', 'Vietnamese Style', 'Thai Curry'
    ];
    
    // Generate authentic Asian recipe name
    final cuisine = asianCuisines[randomVariation % asianCuisines.length];
    final technique = asianTechniques[randomVariation % asianTechniques.length];
    
    String recipeName = _generateAsianRecipeName(firebaseIngredients, cuisine, technique, randomVariation);
    
    // Determine category based on ingredients and Asian meal types
    String category = _determineAsianRecipeCategory(firebaseIngredients, randomVariation);
    
    // Create authentic Asian description
    String description = _generateAsianRecipeDescription(firebaseIngredients, cuisine, technique);
    
    // Create ingredient list with Asian pantry items
    List<Map<String, dynamic>> ingredientsList = [];
    
    // Add Firebase ingredients as available
    for (String ingredient in firebaseIngredients) {
      final quantity = _getRealisticQuantity(ingredient, randomVariation);
      final unit = _getRealisticUnit(ingredient);
      
      ingredientsList.add({
        'name': ingredient,
        'quantity': quantity,
        'unit': unit,
        'available': true,
      });
    }
    
    // Add Asian-specific pantry ingredients
    final asianPantryItems = _generateAsianPantryItems(firebaseIngredients, technique, randomVariation);
    ingredientsList.addAll(asianPantryItems);
    
    // Generate Asian cooking instructions
    final instructions = _generateAsianCookingInstructions(firebaseIngredients, technique, recipeName);
    
    final recipe = {
      'id': id,
      'name': recipeName,
      'timeRequired': '${15 + (randomVariation % 25)} mins',
      'difficulty': ['Easy', 'Medium', 'Hard'][randomVariation % 3],
      'category': category,
      'description': description,
      'ingredients': ingredientsList,
      'instructions': instructions,
      'nutritionInfo': _calculateNutritionInfo(firebaseIngredients, randomVariation),
      'isAIGenerated': true,
    };
    
    final imageUrl = await RecipeImageService.getRecipeImage(
      recipe['name'] as String,
      recipe['category'] as String,
    );
    recipe['imageUrl'] = imageUrl ?? 'assets/images/food_placeholder.png';
    
    return recipe;
  }

  static String _generateAsianRecipeName(List<String> ingredients, String cuisine, String technique, int variation) {
    final mainIngredient = StringExtension(ingredients[0]).capitalize();
    
    // Authentic Asian dish names based on cuisine
    if (cuisine == 'Chinese') {
      final chineseDishes = ['Fried Rice', 'Sweet and Sour', 'Kung Pao', 'Mapo', 'Hong Shao'];
      final dish = chineseDishes[variation % chineseDishes.length];
      return '$dish $mainIngredient';
    } else if (cuisine == 'Japanese') {
      final japaneseDishes = ['Teriyaki', 'Katsu', 'Donburi', 'Yakitori', 'Tempura'];
      final dish = japaneseDishes[variation % japaneseDishes.length];
      return '$mainIngredient $dish';
    } else if (cuisine == 'Thai') {
      final thaiDishes = ['Pad Thai', 'Green Curry', 'Basil Stir Fry', 'Tom Yum', 'Massaman'];
      final dish = thaiDishes[variation % thaiDishes.length];
      return '$dish $mainIngredient';
    } else if (cuisine == 'Korean') {
      final koreanDishes = ['Bulgogi', 'Kimchi', 'Bibimbap', 'Korean BBQ', 'Japchae'];
      final dish = koreanDishes[variation % koreanDishes.length];
      return '$dish Style $mainIngredient';
    } else if (cuisine == 'Vietnamese') {
      final vietnameseDishes = ['Pho', 'Banh Mi', 'Com Tam', 'Bun Bo', 'Canh Chua'];
      final dish = vietnameseDishes[variation % vietnameseDishes.length];
      return '$mainIngredient $dish';
    }
    
    // Default format
    return '$cuisine $technique $mainIngredient';
  }

  static String _generateAsianRecipeDescription(List<String> ingredients, String cuisine, String technique) {
    final primaryIngredient = StringExtension(ingredients[0]).capitalize();
    
    final descriptions = [
      'An authentic $cuisine dish featuring $technique $primaryIngredient with traditional Asian aromatics and umami-rich seasonings.',
      'Experience the vibrant flavors of $cuisine cuisine in this $technique $primaryIngredient recipe, perfectly balanced with sweet, sour, and savory notes.',
      'This $cuisine-inspired $technique $primaryIngredient combines traditional cooking techniques with bold Asian flavors for an unforgettable meal.',
      'Savor the essence of $cuisine cooking with this expertly crafted $technique $primaryIngredient, infused with aromatic herbs and spices.',
      'A modern take on classic $cuisine flavors, this $technique $primaryIngredient dish delivers restaurant-quality taste at home.',
    ];
    
    return descriptions[ingredients.length % descriptions.length];
  }

  static List<Map<String, dynamic>> _generateAsianPantryItems(List<String> ingredients, String technique, int randomVariation) {
    List<Map<String, dynamic>> pantryItems = [];
    
    // Essential Asian base seasonings
    pantryItems.addAll([
      {'name': 'soy sauce', 'quantity': '2', 'unit': 'tbsp', 'available': false},
      {'name': 'sesame oil', 'quantity': '1', 'unit': 'tsp', 'available': false},
      {'name': 'garlic', 'quantity': '2', 'unit': 'cloves', 'available': false},
    ]);
    
    // Technique-specific seasonings
    if (technique.contains('Teriyaki')) {
      pantryItems.add({'name': 'mirin', 'quantity': '1', 'unit': 'tbsp', 'available': false});
      pantryItems.add({'name': 'brown sugar', 'quantity': '1', 'unit': 'tsp', 'available': false});
    } else if (technique.contains('Thai') || technique.contains('Curry')) {
      pantryItems.add({'name': 'fish sauce', 'quantity': '1', 'unit': 'tbsp', 'available': false});
      pantryItems.add({'name': 'coconut milk', 'quantity': '1/4', 'unit': 'cup', 'available': false});
    } else if (technique.contains('Korean')) {
      pantryItems.add({'name': 'gochujang', 'quantity': '1', 'unit': 'tbsp', 'available': false});
      pantryItems.add({'name': 'rice vinegar', 'quantity': '1', 'unit': 'tsp', 'available': false});
    } else if (technique.contains('Chinese') || technique.contains('Stir-Fried')) {
      pantryItems.add({'name': 'oyster sauce', 'quantity': '1', 'unit': 'tbsp', 'available': false});
      pantryItems.add({'name': 'cornstarch', 'quantity': '1', 'unit': 'tsp', 'available': false});
    }
    
    // Add ginger for most Asian dishes
    pantryItems.add({'name': 'fresh ginger', 'quantity': '1', 'unit': 'inch', 'available': false});
    
    // Add cooking oil
    pantryItems.add({'name': 'vegetable oil', 'quantity': '2', 'unit': 'tbsp', 'available': false});
    
    return pantryItems.take(6).toList();
  }

  static List<String> _generateAsianCookingInstructions(List<String> ingredients, String technique, String recipeName) {
    List<String> instructions = [];
    
    // Preparation with Asian focus
    instructions.add('Prepare ingredients: ${ingredients.join(", ")}. Slice meats thinly, cut vegetables uniformly for even cooking.');
    
    // Asian cooking techniques
    if (technique.contains('Stir-Fried')) {
      instructions.add('Heat wok or large skillet over high heat until smoking. Add vegetable oil and swirl to coat.');
      instructions.add('Add garlic and ginger, stir-fry for 30 seconds until fragrant.');
      instructions.add('Add ${ingredients[0]} and stir-fry for 2-3 minutes until cooked through.');
    } else if (technique.contains('Teriyaki')) {
      instructions.add('Mix soy sauce, mirin, and brown sugar in a small bowl to make teriyaki sauce.');
      instructions.add('Heat oil in a pan over medium-high heat. Cook ${ingredients[0]} until golden brown.');
    } else if (technique.contains('Thai') || technique.contains('Curry')) {
      instructions.add('Heat oil in a pan over medium heat. Add garlic and ginger, cook until fragrant.');
      instructions.add('Add ${ingredients[0]} and cook until almost done.');
      instructions.add('Pour in coconut milk and fish sauce, bring to a gentle simmer.');
    } else if (technique.contains('Steamed')) {
      instructions.add('Set up a steamer basket over boiling water. Arrange ${ingredients[0]} in the steamer.');
      instructions.add('Steam for 8-12 minutes until cooked through and tender.');
    }
    
    // Add remaining ingredients
    if (ingredients.length > 1) {
      instructions.add('Add ${ingredients.sublist(1).join(" and ")} to the pan. Stir-fry for 2-3 minutes.');
    }
    
    // Final seasoning and serving
    instructions.add('Season with soy sauce, sesame oil, and other Asian seasonings. Taste and adjust.');
    instructions.add('Garnish with chopped scallions or cilantro. Serve hot with steamed rice.');
    instructions.add('Enjoy your authentic $recipeName!');
    
    return instructions;
  }

  // Add missing helper methods
  static String _determineAsianRecipeCategory(List<String> ingredients, int randomVariation) {
    // Determine category based on ingredients
    final ingredientStr = ingredients.join(' ').toLowerCase();
    
    if (ingredientStr.contains('egg') || ingredientStr.contains('cereal') || 
        ingredientStr.contains('bread') || ingredientStr.contains('oat')) {
      return 'Breakfast';
    } else if (ingredientStr.contains('chicken') || ingredientStr.contains('beef') || 
               ingredientStr.contains('fish') || ingredientStr.contains('rice')) {
      return 'Dinner';
    } else if (randomVariation % 4 == 0) {
      return 'Lunch';
    } else if (randomVariation % 5 == 0) {
      return 'Snack';
    } else {
      return 'Dinner';
    }
  }
  
  static String _getRealisticQuantity(String ingredient, int randomVariation) {
    final quantities = {
      'chicken': ['1', '2', '300g', '400g'],
      'beef': ['250g', '300g', '1', '2'],
      'rice': ['1', '1.5', '2', '3/4'],
      'pasta': ['200g', '250g', '300g', '150g'],
      'egg': ['2', '3', '4', '1'],
      'tomato': ['2', '3', '1', '4'],
      'onion': ['1', '2', '1/2', '1'],
      'potato': ['2', '3', '1', '4'],
      'milk': ['1', '2', '1/2', '3/4'],
      'bread': ['2', '4', '1', '3'],
      'cheese': ['100g', '150g', '1/2', '1'],
    };
    
    final ingredientLower = ingredient.toLowerCase();
    for (String key in quantities.keys) {
      if (ingredientLower.contains(key)) {
        final options = quantities[key]!;
        return options[randomVariation % options.length];
      }
    }
    
    return ['1', '2', '1/2', '3/4'][randomVariation % 4];
  }
  
  static String _getRealisticUnit(String ingredient) {
    final units = {
      'chicken': 'piece',
      'beef': 'piece', 
      'rice': 'cup',
      'pasta': 'grams',
      'egg': 'pieces',
      'tomato': 'pieces',
      'onion': 'piece',
      'potato': 'pieces',
      'milk': 'cup',
      'bread': 'slices',
      'cheese': 'cup',
    };
    
    final ingredientLower = ingredient.toLowerCase();
    for (String key in units.keys) {
      if (ingredientLower.contains(key)) {
        return units[key]!;
      }
    }
    
    return 'portion';
  }
  
  static Map<String, String> _calculateNutritionInfo(List<String> ingredients, int randomVariation) {
    // Base calories calculation based on ingredients
    int baseCalories = 150;
    
    for (String ingredient in ingredients) {
      final ingredientLower = ingredient.toLowerCase();
      if (ingredientLower.contains('chicken') || ingredientLower.contains('beef')) {
        baseCalories += 200;
      } else if (ingredientLower.contains('rice') || ingredientLower.contains('pasta')) {
        baseCalories += 150;
      } else if (ingredientLower.contains('egg')) {
        baseCalories += 70;
      } else if (ingredientLower.contains('cheese')) {
        baseCalories += 100;
      } else {
        baseCalories += 50;
      }
    }
    
    // Add randomization
    final finalCalories = baseCalories + (randomVariation % 100);
    final servings = ingredients.length >= 3 ? '3' : '2';
    
    return {
      'calories': finalCalories.toString(),
      'servings': servings,
    };
  }

  static Future<List<Map<String, dynamic>>> _getAsianDefaultRecipes(int randomVariation) async {
    final recipes = [
      {
        'id': 'asian_default_1_$randomVariation',
        'name': 'Classic Chinese Egg Fried Rice',
        'timeRequired': '15 mins',
        'difficulty': 'Easy',
        'category': 'Dinner',
        'description': 'Authentic Chinese-style fried rice with fluffy scrambled eggs, seasoned with soy sauce and sesame oil for the perfect umami flavor.',
        'ingredients': [
          {'name': 'cooked rice', 'quantity': '2', 'unit': 'cups', 'available': false},
          {'name': 'eggs', 'quantity': '2', 'unit': 'pieces', 'available': false},
          {'name': 'soy sauce', 'quantity': '2', 'unit': 'tbsp', 'available': false},
          {'name': 'sesame oil', 'quantity': '1', 'unit': 'tsp', 'available': false},
          {'name': 'scallions', 'quantity': '2', 'unit': 'stalks', 'available': false},
        ],
        'instructions': [
          'Heat oil in a wok over high heat until smoking.',
          'Scramble eggs until just set, remove and set aside.',
          'Add rice to wok, breaking up clumps, stir-fry for 2 minutes.',
          'Return eggs to wok, add soy sauce and sesame oil.',
          'Stir-fry everything together for 1 minute, garnish with scallions.'
        ],
        'nutritionInfo': {'calories': '280', 'servings': '2'},
        'isAIGenerated': true,
      },
      {
        'id': 'asian_default_2_$randomVariation',
        'name': 'Japanese Chicken Teriyaki',
        'timeRequired': '20 mins',
        'difficulty': 'Medium',
        'category': 'Dinner',
        'description': 'Tender chicken glazed with sweet and savory teriyaki sauce, a beloved Japanese dish perfect over steamed rice.',
        'ingredients': [
          {'name': 'chicken thigh', 'quantity': '2', 'unit': 'pieces', 'available': false},
          {'name': 'soy sauce', 'quantity': '3', 'unit': 'tbsp', 'available': false},
          {'name': 'mirin', 'quantity': '2', 'unit': 'tbsp', 'available': false},
          {'name': 'brown sugar', 'quantity': '1', 'unit': 'tbsp', 'available': false},
          {'name': 'vegetable oil', 'quantity': '1', 'unit': 'tbsp', 'available': false},
        ],
        'instructions': [
          'Mix soy sauce, mirin, and brown sugar to make teriyaki sauce.',
          'Heat oil in a pan over medium-high heat.',
          'Cook chicken skin-side down for 5 minutes until golden.',
          'Flip chicken, add teriyaki sauce, and cook 3 more minutes.',
          'Let sauce reduce and glaze the chicken. Serve with rice.'
        ],
        'nutritionInfo': {'calories': '350', 'servings': '2'},
        'isAIGenerated': true,
      },
    ];
    
    for (var recipe in recipes) {
      final imageUrl = await RecipeImageService.getRecipeImage(
        recipe['name'] as String,
        recipe['category'] as String,
      );
      recipe['imageUrl'] = imageUrl ?? 'assets/images/food_placeholder.png';
    }
    
    return recipes;
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? "${this[0].toUpperCase()}${substring(1)}" : "";
  }
}