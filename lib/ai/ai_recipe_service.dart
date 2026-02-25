import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fyp_project/ai/recipe_image_service.dart';

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
      // Create a detailed prompt for the AI
      String prompt = _buildRecipePrompt(
        availableIngredients,
        expiringIngredients,
        dietaryRestrictions,
        cuisinePreference,
        maxRecipes,
      );

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
              'content': 'You are a professional chef and recipe expert. Generate practical, delicious recipes based on available ingredients. Always respond with valid JSON format.'
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 2000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse the AI response into structured recipe data
        final recipes = await _parseRecipeResponse(content);
        return recipes;
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating AI recipes: $e');
      return await _getFallbackRecipes(availableIngredients);
    }
  }

  static String _buildRecipePrompt(
    List<String> availableIngredients,
    List<String>? expiringIngredients,
    String? dietaryRestrictions,
    String? cuisinePreference,
    int maxRecipes,
  ) {
    StringBuffer prompt = StringBuffer();
    
    prompt.writeln('Generate $maxRecipes recipe suggestions based on these criteria:');
    prompt.writeln('Available ingredients: ${availableIngredients.join(', ')}');
    
    if (expiringIngredients != null && expiringIngredients.isNotEmpty) {
      prompt.writeln('Prioritize using these expiring ingredients: ${expiringIngredients.join(', ')}');
    }
    
    if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
      prompt.writeln('Dietary restrictions: $dietaryRestrictions');
    }
    
    if (cuisinePreference != null && cuisinePreference.isNotEmpty) {
      prompt.writeln('Preferred cuisine: $cuisinePreference');
    }
    
    prompt.writeln('''
Please format the response as valid JSON with this exact structure:
{
  "recipes": [
    {
      "name": "Recipe Name",
      "timeRequired": "X mins",
      "difficulty": "Easy",
      "category": "Breakfast",
      "description": "Brief description",
      "ingredients": [
        {"name": "ingredient1", "quantity": "1", "unit": "cup"},
        {"name": "ingredient2", "quantity": "2", "unit": "pieces"}
      ],
      "instructions": [
        "Step 1: Detailed instruction",
        "Step 2: Another instruction"
      ],
      "nutritionInfo": {
        "calories": "200",
        "servings": "2"
      }
    }
  ]
}

Important: 
- Use only ingredients from the available list or common pantry items
- Keep instructions simple and clear
- Categories must be: Breakfast, Lunch, Dinner, Snack, or Dessert
- Difficulty must be: Easy, Medium, or Hard
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
        
        processedRecipes.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString() + recipe['name'].hashCode.toString(),
          'name': recipe['name'] ?? 'AI Generated Recipe',
          'timeRequired': recipe['timeRequired'] ?? 'Unknown',
          'difficulty': recipe['difficulty'] ?? 'Medium',
          'category': recipe['category'] ?? 'Main Course',
          'description': recipe['description'] ?? '',
          'ingredients': recipe['ingredients'] ?? [],
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

  static Future<List<Map<String, dynamic>>> _getFallbackRecipes(List<String> ingredients) async {
    // Fallback recipes when AI fails
    final fallbackRecipe = {
      'id': 'fallback_1',
      'name': 'Simple Stir Fry',
      'timeRequired': '15 mins',
      'difficulty': 'Easy',
      'category': 'Dinner',
      'description': 'Quick stir fry with available ingredients',
      'ingredients': ingredients.take(5).map((ing) => {
        'name': ing,
        'quantity': '1',
        'unit': 'piece'
      }).toList(),
      'instructions': [
        'Heat oil in a pan',
        'Add ingredients and stir fry for 5-7 minutes',
        'Season with salt and pepper',
        'Serve hot'
      ],
      'nutritionInfo': {'calories': '250', 'servings': '2'},
      'isAIGenerated': false,
    };

    // Add image to fallback recipe
    // ...existing code...
// Add image to fallback recipe
  final imageUrl = await RecipeImageService.getRecipeImage(
  fallbackRecipe['name'] as String? ?? 'Unknown Recipe',
  fallbackRecipe['category'] as String? ?? 'General',
  );
  fallbackRecipe['imageUrl'] = imageUrl ?? 'assets/images/food_placeholder.png';
    return [fallbackRecipe];
  }
}
