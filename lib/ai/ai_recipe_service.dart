import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fyp_project/ai/recipe_image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIRecipeService {
  // Get your free API key from https://platform.openai.com/api-keys
  static const String _apiKey = ''; // Add your API key
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
    int randomSeed, // Add random seed parameter
  ) {
    StringBuffer prompt = StringBuffer();
    
    // Add randomization instruction to ensure variety
    prompt.writeln('GENERATE COMPLETELY NEW AND DIFFERENT RECIPES! Randomization seed: $randomSeed');
    prompt.writeln('Generate $maxRecipes DIVERSE and UNIQUE recipe suggestions using DIFFERENT COMBINATIONS of these available ingredients:');
    prompt.writeln('Available ingredients: ${availableIngredients.join(', ')}');
    
    if (expiringIngredients != null && expiringIngredients.isNotEmpty) {
      prompt.writeln('Try to prioritize these expiring ingredients: ${expiringIngredients.join(', ')}');
    }
    
    if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
      prompt.writeln('Dietary restrictions: $dietaryRestrictions');
    }
    
    if (cuisinePreference != null && cuisinePreference.isNotEmpty) {
      prompt.writeln('Preferred cuisine: $cuisinePreference');
    }
    
    // Add cooking style variations for more diversity
    final cookingStyles = ['grilled', 'stir-fried', 'baked', 'steamed', 'roasted', 'sautéed', 'braised'];
    final mealTypes = ['quick breakfast', 'hearty lunch', 'comfort dinner', 'healthy snack', 'sweet dessert'];
    final selectedStyle = cookingStyles[randomSeed % cookingStyles.length];
    final selectedMealType = mealTypes[randomSeed % mealTypes.length];
    
    prompt.writeln('Focus on creating ${selectedStyle} dishes and include at least one ${selectedMealType} option.');
    
    prompt.writeln('''
CRITICAL REQUIREMENTS FOR VARIETY:
- Generate COMPLETELY DIFFERENT recipes than any previous suggestions
- Each recipe must use DIFFERENT ingredient combinations (never repeat the same combinations)
- Vary cooking methods: $selectedStyle, pan-fried, boiled, raw/fresh, etc.
- Include diverse meal types: ${mealTypes.join(', ')}
- Be creative with flavors: Asian, Mediterranean, Mexican, Indian, American, etc.
- Use different quantities and measurements for the same ingredients
- Create unique recipe names that haven't been used before

RECIPE STRUCTURE GUIDELINES:
- Recipe 1: Use ingredients A, B, C with cooking method 1
- Recipe 2: Use ingredients D, E, F with cooking method 2  
- Recipe 3: Use ingredients A, G, H with cooking method 3
- Recipe 4: Use ingredients I, J, K with cooking method 4
- Recipe 5: Use ingredients B, L, M with cooking method 5

Include common pantry items (salt, pepper, oil, spices, herbs) that enhance each specific dish.
Make recipes practical but INNOVATIVE and DIFFERENT each time.

INGREDIENT INNOVATION:
- Same ingredient, different uses: chicken can be grilled, in soup, in salad, in curry, etc.
- Creative combinations: mix sweet and savory, different cuisines
- Vary portion sizes and cooking times
- Add different spices and seasonings for each recipe

Please format the response as valid JSON with this exact structure:
{
  "recipes": [
    {
      "name": "Creative Unique Recipe Name",
      "timeRequired": "X mins",
      "difficulty": "Easy/Medium/Hard",
      "category": "Breakfast/Lunch/Dinner/Snack/Dessert",
      "description": "Detailed description highlighting what makes this recipe special",
      "ingredients": [
        {"name": "ingredient1", "quantity": "varied_amount", "unit": "appropriate_unit", "available": true},
        {"name": "ingredient2", "quantity": "different_amount", "unit": "different_unit", "available": true},
        {"name": "seasoning/spice", "quantity": "1", "unit": "tsp", "available": false}
      ],
      "instructions": [
        "Step 1: Detailed unique instruction",
        "Step 2: Another creative instruction",
        "Step 3: Final preparation step"
      ],
      "nutritionInfo": {
        "calories": "realistic_number",
        "servings": "appropriate_servings"
      }
    }
  ]
}

ABSOLUTELY CRITICAL: 
- Every recipe must be COMPLETELY DIFFERENT from previous generations
- Use VARIED cooking techniques and flavor profiles
- Create UNIQUE ingredient combinations
- Generate DIVERSE quantities and measurements
- Never repeat recipe names or cooking methods
- Be CREATIVE and INNOVATIVE with available ingredients
- Return valid JSON only, no additional text''');
    
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
    print('Creating fallback recipes with ingredients: $ingredients');
    
    // Use random seed to create variety in fallback recipes
    final seed = randomSeed ?? DateTime.now().millisecondsSinceEpoch;
    final random = seed % 100;
    
    List<Map<String, dynamic>> fallbackRecipes = [];
    
    if (ingredients.isNotEmpty) {
      // Shuffle ingredients for variety
      final shuffledIngredients = List<String>.from(ingredients);
      if (random > 50) {
        shuffledIngredients.shuffle();
      }
      
      // Create diverse recipes using different ingredient combinations
      Set<String> usedMainIngredients = {};
      
      // Generate different recipe combinations based on random seed
      for (int i = 0; i < ingredients.length && fallbackRecipes.length < 5; i++) {
        final currentIndex = (i + (random % ingredients.length)) % ingredients.length;
        final mainIngredient = shuffledIngredients[currentIndex];
        
        if (!usedMainIngredients.contains(mainIngredient)) {
          // Create different supporting ingredient combinations
          final supportingIngredients = shuffledIngredients
              .where((ing) => ing != mainIngredient)
              .take(2)
              .toList();
          
          final recipe = await _createFallbackRecipe(
            mainIngredient, 
            supportingIngredients, 
            'fallback_${seed}_${i}', // Include seed in ID for uniqueness
            random, // Pass random for recipe variation
          );
          fallbackRecipes.add(recipe);
          usedMainIngredients.add(mainIngredient);
        }
      }
      
      // If we have fewer recipes, create combination recipes
      while (fallbackRecipes.length < 3 && ingredients.length >= 2) {
        final remainingIngredients = shuffledIngredients.where(
          (ing) => !usedMainIngredients.contains(ing)
        ).take(3).toList();
        
        if (remainingIngredients.length >= 2) {
          final comboRecipe = await _createCombinationRecipe(
            remainingIngredients, 
            'fallback_combo_${seed}_${fallbackRecipes.length}',
            random, // Pass random for variation
          );
          fallbackRecipes.add(comboRecipe);
          usedMainIngredients.addAll(remainingIngredients.take(2));
        } else {
          break;
        }
      }
      
    } else {
      // Default fallback when no ingredients available - randomize these too
      final defaultRecipes = await _getDefaultFallbackRecipes(random);
      fallbackRecipes.addAll(defaultRecipes);
    }

    print('Created ${fallbackRecipes.length} randomized fallback recipes');
    return fallbackRecipes;
  }
  
  static Future<Map<String, dynamic>> _createFallbackRecipe(
    String mainIngredient, 
    List<String> supportingIngredients, 
    String id,
    int randomVariation, // Add random parameter
  ) async {
    // Add cooking style variations based on random number
    final cookingStyles = ['Simple', 'Crispy', 'Tender', 'Spicy', 'Herbed', 'Garlic', 'Honey', 'Lemon'];
    final cookingMethods = ['Pan-fried', 'Oven-baked', 'Steamed', 'Grilled', 'Sautéed'];
    
    final styleIndex = randomVariation % cookingStyles.length;
    final methodIndex = randomVariation % cookingMethods.length;
    
    // Determine recipe type based on ingredient
    String category = 'Dinner';
    String recipeName = '${cookingStyles[styleIndex]} ${StringExtension(mainIngredient).capitalize()} ${cookingMethods[methodIndex]}';
    List<String> instructions = [];
    List<Map<String, dynamic>> ingredientsList = [];
    
    // Add randomized quantities for variety
    final quantities = ['1', '2', '1.5', '0.5', '1/2', '1/4', '3/4'];
    final getRandomQuantity = () => quantities[randomVariation % quantities.length];
    
    // Customize based on ingredient type with variations
    if (mainIngredient.toLowerCase().contains('egg')) {
      category = 'Breakfast';
      final eggStyles = ['Scrambled', 'Fluffy', 'Creamy', 'Herb', 'Cheese'];
      recipeName = '${eggStyles[randomVariation % eggStyles.length]} ${StringExtension(mainIngredient).capitalize()}';
      
      final spices = ['paprika', 'chives', 'oregano', 'thyme', 'parsley'];
      final selectedSpice = spices[randomVariation % spices.length];
      
      ingredientsList = [
        {'name': 'eggs', 'quantity': randomVariation % 2 == 0 ? '3' : '2', 'unit': 'pieces', 'available': true},
        {'name': 'butter', 'quantity': getRandomQuantity(), 'unit': 'tbsp', 'available': false},
        {'name': 'salt', 'quantity': '1', 'unit': 'pinch', 'available': false},
        {'name': selectedSpice, 'quantity': '1/2', 'unit': 'tsp', 'available': false},
      ];
      
      instructions = [
        randomVariation % 2 == 0 
          ? 'Heat butter in a non-stick pan over low heat'
          : 'Melt butter in a heavy-bottomed pan over medium-low heat',
        'Beat eggs with salt and $selectedSpice in a bowl until well combined',
        randomVariation % 3 == 0 
          ? 'Pour eggs into pan and let sit for 30 seconds before stirring'
          : 'Pour beaten eggs into the pan and immediately start stirring',
        'Gently fold eggs with spatula until just set but still creamy',
        'Serve immediately while hot and fluffy'
      ];
    } else if (mainIngredient.toLowerCase().contains('cereal') || 
               mainIngredient.toLowerCase().contains('oat')) {
      category = 'Breakfast';
      final bowlStyles = ['Classic', 'Tropical', 'Berry', 'Nutty', 'Protein'];
      recipeName = '${bowlStyles[randomVariation % bowlStyles.length]} ${StringExtension(mainIngredient).capitalize()} Bowl';
      
      final toppings = ['sliced almonds', 'fresh berries', 'chia seeds', 'coconut flakes', 'chopped walnuts'];
      final selectedTopping = toppings[randomVariation % toppings.length];
      
      ingredientsList = [
        {'name': mainIngredient, 'quantity': randomVariation % 2 == 0 ? '3/4' : '1', 'unit': 'cup', 'available': true},
        {'name': randomVariation % 2 == 0 ? 'cold milk' : 'oat milk', 'quantity': getRandomQuantity(), 'unit': 'cup', 'available': false},
        {'name': randomVariation % 3 == 0 ? 'maple syrup' : 'honey', 'quantity': '1', 'unit': 'tsp', 'available': false},
        {'name': selectedTopping, 'quantity': '2', 'unit': 'tbsp', 'available': false},
      ];
      
      instructions = [
        'Pour cereal into your favorite bowl',
        randomVariation % 2 == 0 
          ? 'Add milk gradually until cereal is just covered'
          : 'Pour in milk to your preferred level for desired crunchiness',
        'Drizzle with sweetener and mix gently',
        'Top with $selectedTopping for extra nutrition and flavor',
        'Enjoy immediately for best texture'
      ];
    } else if (mainIngredient.toLowerCase().contains('chicken')) {
      category = 'Dinner';
      final chickenStyles = ['Mediterranean', 'Asian-style', 'BBQ', 'Lemon Herb', 'Cajun'];
      recipeName = '${chickenStyles[randomVariation % chickenStyles.length]} ${StringExtension(mainIngredient).capitalize()}';
      
      final seasonings = ['rosemary', 'thyme', 'oregano', 'paprika', 'garlic powder'];
      final selectedSeasoning = seasonings[randomVariation % seasonings.length];
      
      ingredientsList = [
        {'name': 'chicken breast', 'quantity': randomVariation % 2 == 0 ? '2' : '1', 'unit': 'piece', 'available': true},
        {'name': randomVariation % 2 == 0 ? 'olive oil' : 'avocado oil', 'quantity': getRandomQuantity(), 'unit': 'tbsp', 'available': false},
        {'name': 'salt', 'quantity': '1', 'unit': 'tsp', 'available': false},
        {'name': 'black pepper', 'quantity': '1/2', 'unit': 'tsp', 'available': false},
        {'name': selectedSeasoning, 'quantity': randomVariation % 2 == 0 ? '1' : '1/2', 'unit': 'tsp', 'available': false},
      ];
      
      instructions = [
        'Pat chicken dry and season generously with salt, pepper, and $selectedSeasoning',
        randomVariation % 2 == 0 
          ? 'Let chicken marinate at room temperature for 15 minutes'
          : 'Allow seasoning to penetrate for 10 minutes',
        'Heat oil in a skillet over medium-high heat until shimmering',
        randomVariation % 3 == 0 
          ? 'Sear chicken for 7-8 minutes per side until golden and cooked through'
          : 'Cook chicken 6-7 minutes per side until internal temperature reaches 165°F',
        'Rest chicken for 5 minutes before slicing and serving'
      ];
    } else if (mainIngredient.toLowerCase().contains('rice')) {
      category = 'Dinner';
      final riceStyles = ['Coconut', 'Herb', 'Spiced', 'Garlic', 'Simple'];
      recipeName = '${riceStyles[randomVariation % riceStyles.length]} ${StringExtension(mainIngredient).capitalize()}';
      
      ingredientsList = [
        {'name': 'rice', 'quantity': '1', 'unit': 'cup', 'available': true},
        {'name': 'water', 'quantity': '2', 'unit': 'cups', 'available': false},
        {'name': 'salt', 'quantity': '1/2', 'unit': 'tsp', 'available': false},
        {'name': 'butter', 'quantity': '1', 'unit': 'tbsp', 'available': false},
      ];
      
      instructions = [
        'Rinse rice in cold water until water runs clear',
        'In a pot, combine rice, water, and salt',
        'Bring to a boil over high heat',
        'Reduce heat to low, cover, and simmer for 18-20 minutes',
        'Remove from heat, add butter, and let stand 5 minutes before fluffing with fork'
      ];
    } else if (mainIngredient.toLowerCase().contains('pasta') || 
               mainIngredient.toLowerCase().contains('noodle')) {
      category = 'Dinner';
      final pastaStyles = ['Garlic', 'Herb', 'Simple', 'Creamy', 'Spicy'];
      recipeName = '${pastaStyles[randomVariation % pastaStyles.length]} ${StringExtension(mainIngredient).capitalize()}';
      
      ingredientsList = [
        {'name': mainIngredient, 'quantity': '200', 'unit': 'grams', 'available': true},
        {'name': 'water', 'quantity': '4', 'unit': 'cups', 'available': false},
        {'name': 'salt', 'quantity': '1', 'unit': 'tsp', 'available': false},
        {'name': 'olive oil', 'quantity': '2', 'unit': 'tbsp', 'available': false},
        {'name': 'parmesan cheese', 'quantity': '1/4', 'unit': 'cup', 'available': false},
      ];
      
      instructions = [
        'Bring salted water to a boil in a large pot',
        'Add pasta and cook according to package directions',
        'Reserve 1/2 cup pasta water before draining',
        'Toss hot pasta with olive oil and pasta water',
        'Top with grated parmesan cheese and serve'
      ];
    } else if (mainIngredient.toLowerCase().contains('bread')) {
      category = 'Breakfast';
      final breadStyles = ['Buttered', 'Cinnamon', 'Garlic', 'Herb', 'Sweet'];
      recipeName = '${breadStyles[randomVariation % breadStyles.length]} ${StringExtension(mainIngredient).capitalize()}';
      
      ingredientsList = [
        {'name': 'bread', 'quantity': '2', 'unit': 'slices', 'available': true},
        {'name': 'butter', 'quantity': '2', 'unit': 'tbsp', 'available': false},
        {'name': 'jam', 'quantity': '1', 'unit': 'tbsp', 'available': false},
      ];
      
      instructions = [
        'Toast bread slices until golden brown',
        'Spread butter evenly on warm toast',
        'Add jam or honey if desired',
        'Serve immediately while warm'
      ];
    } else {
      // Generic recipe for unknown ingredients
      recipeName = '${cookingStyles[styleIndex]} ${StringExtension(mainIngredient).capitalize()} ${cookingMethods[methodIndex]}';
      ingredientsList = [
        {'name': mainIngredient, 'quantity': getRandomQuantity(), 'unit': 'portion', 'available': true},
        {'name': 'salt', 'quantity': '1', 'unit': 'pinch', 'available': false},
        {'name': 'cooking oil', 'quantity': getRandomQuantity(), 'unit': 'tbsp', 'available': false},
        {'name': 'black pepper', 'quantity': '1/4', 'unit': 'tsp', 'available': false},
      ];
      
      instructions = [
        'Prepare ${mainIngredient} by washing and cutting as needed',
        randomVariation % 2 == 0 
          ? 'Heat oil in a pan over medium heat until warm'
          : 'Heat oil in a large skillet over medium-high heat',
        'Add ${mainIngredient} and cook for ${5 + (randomVariation % 4)} minutes until tender',
        'Season with salt and pepper to taste',
        'Serve hot and enjoy this delicious dish'
      ];
      
      // Add supporting ingredients with variation
      for (String supporting in supportingIngredients.take(2)) {
        if (supporting != mainIngredient) {
          ingredientsList.insert(-2, {
            'name': supporting, 
            'quantity': getRandomQuantity(), 
            'unit': 'portion', 
            'available': true
          });
          instructions.insert(-2, 'Add ${supporting} and cook for ${2 + (randomVariation % 3)} more minutes');
        }
      }
    }
    
    final recipe = {
      'id': id,
      'name': recipeName,
      'timeRequired': '${10 + (randomVariation % 20)} mins', // Randomize time
      'difficulty': ['Easy', 'Medium'][randomVariation % 2], // Randomize difficulty
      'category': category,
      'description': 'Delicious ${cookingStyles[styleIndex].toLowerCase()} recipe with a unique twist using available ingredients',
      'ingredients': ingredientsList,
      'instructions': instructions,
      'nutritionInfo': {
        'calories': '${150 + (randomVariation % 200)}', // Randomize calories
        'servings': '${1 + (randomVariation % 3)}'  // Randomize servings
      },
      'isAIGenerated': false,
    };
    
    final imageUrl = await RecipeImageService.getRecipeImage(
      recipe['name'] as String,
      recipe['category'] as String,
    );
    recipe['imageUrl'] = imageUrl ?? 'assets/images/food_placeholder.png';
    
    return recipe;
  }
  
  static Future<Map<String, dynamic>> _createCombinationRecipe(
    List<String> ingredients, 
    String id,
    int randomVariation, // Add random parameter
  ) async {
    final cookingStyles = ['Fusion', 'Mediterranean', 'Asian-inspired', 'Rustic', 'Gourmet'];
    final dishTypes = ['Stir-fry', 'Bowl', 'Skillet', 'Medley', 'Combo'];
    
    final style = cookingStyles[randomVariation % cookingStyles.length];
    final dish = dishTypes[randomVariation % dishTypes.length];
    final recipeName = '$style ${ingredients.map((e) => StringExtension(e).capitalize()).take(2).join(" & ")} $dish';
    
    // Randomize quantities and cooking methods
    final quantities = ['1', '1.5', '2', '0.5', '3/4'];
    final getRandomQuantity = () => quantities[randomVariation % quantities.length];
    
    List<Map<String, dynamic>> ingredientsList = [];
    
    for (int i = 0; i < ingredients.length; i++) {
      ingredientsList.add({
        'name': ingredients[i], 
        'quantity': getRandomQuantity(), 
        'unit': _getUnitForIngredient(ingredients[i]), 
        'available': true
      });
    }
    
    // Add varied seasonings
    final seasonings = [
      ['garlic powder', 'onion powder'], 
      ['paprika', 'cumin'], 
      ['italian herbs', 'red pepper flakes'],
      ['ginger powder', 'soy sauce'],
      ['lemon zest', 'black pepper']
    ];
    final selectedSeasonings = seasonings[randomVariation % seasonings.length];
    
    ingredientsList.addAll([
      {'name': 'salt', 'quantity': '1', 'unit': 'pinch', 'available': false},
      {'name': 'cooking oil', 'quantity': getRandomQuantity(), 'unit': 'tbsp', 'available': false},
      {'name': selectedSeasonings[0], 'quantity': '1/2', 'unit': 'tsp', 'available': false},
      {'name': selectedSeasonings[1], 'quantity': '1/4', 'unit': 'tsp', 'available': false},
    ]);
    
    final recipe = {
      'id': id,
      'name': recipeName,
      'timeRequired': '${15 + (randomVariation % 15)} mins',
      'difficulty': ['Medium', 'Easy', 'Hard'][randomVariation % 3],
      'category': 'Dinner',
      'description': '$style combination featuring ${ingredients.join(", ")} with aromatic ${selectedSeasonings.join(" and ")}',
      'ingredients': ingredientsList,
      'instructions': [
        'Heat cooking oil in a large pan over medium heat',
        randomVariation % 2 == 0 
          ? 'Add ${ingredients[0]} first and cook for ${3 + (randomVariation % 3)} minutes'
          : 'Start by cooking ${ingredients[0]} until it begins to ${randomVariation % 2 == 0 ? "brown" : "soften"}',
        for (int i = 1; i < ingredients.length; i++)
          'Add ${ingredients[i]} and cook for ${2 + (randomVariation % 2)} minutes',
        'Season with salt, ${selectedSeasonings[0]}, and ${selectedSeasonings[1]}',
        randomVariation % 3 == 0 
          ? 'Stir everything together and cook for ${3 + (randomVariation % 4)} more minutes'
          : 'Mix well and let flavors meld for ${2 + (randomVariation % 3)} minutes',
        'Taste and adjust seasoning if needed',
        'Serve hot as a complete meal'
      ],
      'nutritionInfo': {
        'calories': '${250 + (randomVariation % 150)}', 
        'servings': '${2 + (randomVariation % 2)}'
      },
      'isAIGenerated': false,
    };
    
    final imageUrl = await RecipeImageService.getRecipeImage(
      recipe['name'] as String,
      recipe['category'] as String,
    );
    recipe['imageUrl'] = imageUrl ?? 'assets/images/food_placeholder.png';
    
    return recipe;
  }
  
  // Helper method to get appropriate unit for ingredient
  static String _getUnitForIngredient(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();
    
    if (lowerIngredient.contains('egg')) return 'pieces';
    if (lowerIngredient.contains('chicken')) return 'piece';
    if (lowerIngredient.contains('rice')) return 'cup';
    if (lowerIngredient.contains('pasta') || lowerIngredient.contains('noodle')) return 'grams';
    if (lowerIngredient.contains('bread')) return 'slices';
    if (lowerIngredient.contains('cereal')) return 'cup';
    if (lowerIngredient.contains('milk')) return 'cup';
    if (lowerIngredient.contains('oil')) return 'tbsp';
    
    return 'portion'; // Default unit
  }

  // Default fallback recipes when no ingredients are available
  static Future<List<Map<String, dynamic>>> _getDefaultFallbackRecipes(int randomVariation) async {
    final recipeVariations = [
      // Variation set 1
      [
        {
          'id': 'default_var1_1',
          'name': 'Fluffy Herb Omelet',
          'timeRequired': '12 mins',
          'difficulty': 'Easy',
          'category': 'Breakfast',
          'description': 'A light and fluffy omelet with fresh herbs',
          'ingredients': [
            {'name': 'eggs', 'quantity': '3', 'unit': 'pieces', 'available': false},
            {'name': 'butter', 'quantity': '2', 'unit': 'tbsp', 'available': false},
            {'name': 'salt', 'quantity': '1', 'unit': 'pinch', 'available': false},
            {'name': 'fresh chives', 'quantity': '1', 'unit': 'tbsp', 'available': false},
          ],
          'instructions': [
            'Beat eggs with salt until frothy',
            'Heat butter in pan over medium-low heat',
            'Pour eggs and let set, then fold',
            'Garnish with chives and serve'
          ],
          'nutritionInfo': {'calories': '180', 'servings': '1'},
          'isAIGenerated': false,
        },
        {
          'id': 'default_var1_2',
          'name': 'Coconut Rice Bowl',
          'timeRequired': '25 mins',
          'difficulty': 'Easy',
          'category': 'Lunch',
          'description': 'Fragrant coconut-infused rice bowl',
          'ingredients': [
            {'name': 'rice', 'quantity': '1', 'unit': 'cup', 'available': false},
            {'name': 'coconut milk', 'quantity': '1', 'unit': 'cup', 'available': false},
            {'name': 'water', 'quantity': '1', 'unit': 'cup', 'available': false},
            {'name': 'salt', 'quantity': '1/2', 'unit': 'tsp', 'available': false},
          ],
          'instructions': [
            'Combine rice, coconut milk, water and salt',
            'Bring to boil then simmer covered',
            'Cook until liquid absorbed',
            'Fluff and serve warm'
          ],
          'nutritionInfo': {'calories': '220', 'servings': '2'},
          'isAIGenerated': false,
        },
      ],
      // Variation set 2
      [
        {
          'id': 'default_var2_1',
          'name': 'Spiced Scrambled Eggs',
          'timeRequired': '8 mins',
          'difficulty': 'Easy',
          'category': 'Breakfast',
          'description': 'Creamy scrambled eggs with aromatic spices',
          'ingredients': [
            {'name': 'eggs', 'quantity': '2', 'unit': 'pieces', 'available': false},
            {'name': 'milk', 'quantity': '2', 'unit': 'tbsp', 'available': false},
            {'name': 'turmeric', 'quantity': '1/4', 'unit': 'tsp', 'available': false},
            {'name': 'cumin', 'quantity': '1/4', 'unit': 'tsp', 'available': false},
          ],
          'instructions': [
            'Whisk eggs with milk and spices',
            'Cook in pan over low heat, stirring constantly',
            'Remove when just set but creamy',
            'Serve immediately'
          ],
          'nutritionInfo': {'calories': '160', 'servings': '1'},
          'isAIGenerated': false,
        },
        {
          'id': 'default_var2_2',
          'name': 'Garlic Herb Pasta',
          'timeRequired': '18 mins',
          'difficulty': 'Medium',
          'category': 'Dinner',
          'description': 'Simple pasta with garlic and fresh herbs',
          'ingredients': [
            {'name': 'pasta', 'quantity': '250', 'unit': 'grams', 'available': false},
            {'name': 'garlic', 'quantity': '3', 'unit': 'cloves', 'available': false},
            {'name': 'olive oil', 'quantity': '3', 'unit': 'tbsp', 'available': false},
            {'name': 'parsley', 'quantity': '1/4', 'unit': 'cup', 'available': false},
          ],
          'instructions': [
            'Cook pasta according to package directions',
            'Heat oil and sauté minced garlic',
            'Toss hot pasta with garlic oil',
            'Garnish with fresh parsley'
          ],
          'nutritionInfo': {'calories': '280', 'servings': '2'},
          'isAIGenerated': false,
        },
      ],
    ];
    
    // Select variation set based on random number
    final selectedVariationSet = recipeVariations[randomVariation % recipeVariations.length];
    
    // Add images to recipes
    for (var recipe in selectedVariationSet) {
      final imageUrl = await RecipeImageService.getRecipeImage(
        recipe['name'] as String,
        recipe['category'] as String,
      );
      recipe['imageUrl'] = imageUrl ?? 'assets/images/food_placeholder.png';
    }
    
    return selectedVariationSet;
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? "${this[0].toUpperCase()}${substring(1)}" : "";
  }
}
