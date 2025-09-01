import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeImageService {
  // Unsplash API - FREE (No API key required for basic usage)
  static const String _unsplashBaseUrl = 'https://api.unsplash.com/search/photos';
  
  // Optional: Get free API key from https://unsplash.com/developers for higher limits
  static const String _unsplashApiKey = '8K_EljaGEmyOh77nLrZ2sGfq4F2yMGlCo8IxR_xA8c0'; // Leave empty for now, or add your free key

  // Update method to fetch available ingredients from Firebase items collection
  static Future<List<String>> _getAvailableIngredients() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return [];
      }

      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'In-stock')
          .get();
      
      print('Found ${snapshot.docs.length} items in Firebase');
      
      List<String> ingredients = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('Item data: $data'); // Debug log
        
        if (data['name'] != null) {
          final itemName = data['name'].toString().toLowerCase().trim();
          ingredients.add(itemName);
          print('Added ingredient: $itemName'); // Debug log
        }
      }
      
      print('Total available ingredients: $ingredients');
      return ingredients;
    } catch (e) {
      print('Error fetching ingredients from Firebase: $e');
      return [];
    }
  }

  // Add method to match ingredients with recipe name
  static bool _canMakeRecipe(String recipeName, List<String> availableIngredients) {
    if (availableIngredients.isEmpty) return true; // If no ingredients data, show all recipes
    
    final recipeWords = recipeName.toLowerCase().split(' ');
    
    // Check if any ingredient matches words in the recipe name
    for (String ingredient in availableIngredients) {
      for (String word in recipeWords) {
        if (word.contains(ingredient) || ingredient.contains(word)) {
          return true;
        }
      }
    }
    
    // Also check common ingredient combinations
    final commonCombinations = {
      'chicken': ['chicken', 'poultry', 'meat'],
      'beef': ['beef', 'meat', 'steak'],
      'rice': ['rice', 'grain'],
      'pasta': ['pasta', 'noodle', 'spaghetti'],
      'egg': ['egg', 'eggs'],
      'tomato': ['tomato', 'tomatoes'],
    };
    
    for (String ingredient in availableIngredients) {
      if (commonCombinations.containsKey(ingredient)) {
        for (String synonym in commonCombinations[ingredient]!) {
          if (recipeName.toLowerCase().contains(synonym)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  static Future<String?> getRecipeImage(String recipeName, String category) async {
    try {
      // Get available ingredients from Firebase
      final availableIngredients = await _getAvailableIngredients();
      
      // Check if we can make this recipe with available ingredients
      final canMake = _canMakeRecipe(recipeName, availableIngredients);
      
      String query;
      if (canMake && availableIngredients.isNotEmpty) {
        // Create Asian-focused query with available ingredients
        final ingredientString = availableIngredients.take(3).join(' ');
        query = '$recipeName $category asian food chinese japanese thai korean vietnamese dish meal recipe cooking $ingredientString';
      } else {
        // Focus on Asian cuisine keywords
        query = '$recipeName $category asian cuisine chinese japanese thai korean food dish meal recipe cooking';
      }
      
      final Uri url = Uri.parse('$_unsplashBaseUrl?query=${Uri.encodeComponent(query)}&per_page=5&orientation=landscape');
      
      final response = await http.get(
        url,
        headers: _unsplashApiKey.isNotEmpty ? {
          'Authorization': 'Client-ID $_unsplashApiKey',
        } : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final results = data['results'] as List;
          final randomIndex = DateTime.now().millisecond % results.length;
          return results[randomIndex]['urls']['regular'];
        }
      }

      // Fallback to Asian ingredient-based search
      if (availableIngredients.isNotEmpty) {
        return await _getAsianIngredientBasedImage(availableIngredients, category);
      } else {
        return await _getAsianFallbackFoodImage(category);
      }
      
    } catch (e) {
      print('Error fetching recipe image: $e');
      return _getLocalPlaceholder(category);
    }
  }

  static Future<String?> _getAsianIngredientBasedImage(List<String> availableIngredients, String category) async {
    try {
      final topIngredients = availableIngredients.take(3).join(' ');
      String query = '$topIngredients $category asian cuisine chinese japanese thai korean recipe dish cooking meal stir fry';
      
      final Uri url = Uri.parse('$_unsplashBaseUrl?query=${Uri.encodeComponent(query)}&per_page=3&orientation=landscape');
      
      final response = await http.get(
        url,
        headers: _unsplashApiKey.isNotEmpty ? {
          'Authorization': 'Client-ID $_unsplashApiKey',
        } : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'];
        }
      }
    } catch (e) {
      print('Error fetching Asian ingredient-based image: $e');
    }
    return null;
  }

  // Add method to get recipe suggestions based on available ingredients
  static Future<List<String>> getRecipeSuggestions() async {
    try {
      final availableIngredients = await _getAvailableIngredients();
      if (availableIngredients.isEmpty) return [];
      
      List<String> suggestions = [];
      
      // Create recipe suggestions based on available ingredients
      for (String ingredient in availableIngredients.take(5)) {
        final recipeSuggestions = _getRecipesByIngredient(ingredient);
        suggestions.addAll(recipeSuggestions);
      }
      
      return suggestions.toSet().toList(); // Remove duplicates
    } catch (e) {
      print('Error getting recipe suggestions: $e');
      return [];
    }
  }

  static Future<String?> _getAsianFallbackFoodImage(String category) async {
    try {
      final asianCategoryQueries = {
        'Breakfast': 'asian breakfast congee dim sum rice porridge morning meal',
        'Lunch': 'asian lunch bento box noodle soup ramen pho midday meal',
        'Dinner': 'asian dinner stir fry curry rice noodles chinese japanese thai evening meal',
        'Snack': 'asian snack dumplings spring rolls appetizer dim sum',
        'Dessert': 'asian dessert mochi sweet red bean matcha treat',
        'Main Course': 'asian main course stir fry curry teriyaki kung pao dish',
        'Side Dish': 'asian side dish kimchi pickled vegetables steamed rice garnish',
      };

      String query = asianCategoryQueries[category] ?? 'delicious asian food meal dish chinese japanese thai';
      
      final Uri url = Uri.parse('$_unsplashBaseUrl?query=${Uri.encodeComponent(query)}&per_page=3&orientation=landscape');
      
      final response = await http.get(
        url,
        headers: _unsplashApiKey.isNotEmpty ? {
          'Authorization': 'Client-ID $_unsplashApiKey',
        } : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'];
        }
      }
    } catch (e) {
      print('Error fetching Asian fallback image: $e');
    }
    return _getLocalPlaceholder(category);
  }

  static List<String> _getRecipesByIngredient(String ingredient) {
    final asianRecipeMap = {
      'chicken': ['Kung Pao Chicken', 'Chicken Teriyaki', 'Thai Basil Chicken', 'Korean Fried Chicken'],
      'beef': ['Beef Bulgogi', 'Mongolian Beef', 'Thai Beef Salad', 'Chinese Orange Beef'],
      'rice': ['Fried Rice', 'Chicken Rice', 'Korean Bibimbap', 'Thai Pineapple Rice'],
      'noodle': ['Pad Thai', 'Ramen', 'Pho', 'Chow Mein'],
      'egg': ['Egg Fried Rice', 'Tamagoyaki', 'Thai Omelet', 'Korean Egg Roll'],
      'tofu': ['Mapo Tofu', 'Agedashi Tofu', 'Korean Kimchi Tofu', 'Thai Tofu Curry'],
      'pork': ['Char Siu', 'Korean BBQ Pork', 'Vietnamese Pork Banh Mi', 'Sweet and Sour Pork'],
      'shrimp': ['Honey Walnut Shrimp', 'Thai Shrimp Curry', 'Japanese Tempura', 'Vietnamese Shrimp Rolls'],
    };
    
    return asianRecipeMap[ingredient.toLowerCase()] ?? ['${ingredient.capitalize()} Asian Style'];
  }

  static Future<String?> _getFallbackFoodImage(String category) async {
    try {
      final categoryQueries = {
        'Breakfast': 'breakfast pancakes eggs toast morning meal',
        'Lunch': 'lunch sandwich salad soup midday meal',
        'Dinner': 'dinner pasta steak chicken evening meal',
        'Snack': 'healthy snack fruits nuts appetizer',
        'Dessert': 'dessert cake chocolate sweet treat',
        'Main Course': 'main course dinner meal dish',
        'Side Dish': 'side dish vegetables rice garnish',
      };

      String query = categoryQueries[category] ?? 'delicious food meal dish';
      
      final Uri url = Uri.parse('$_unsplashBaseUrl?query=${Uri.encodeComponent(query)}&per_page=3&orientation=landscape');
      
      final response = await http.get(
        url,
        headers: _unsplashApiKey.isNotEmpty ? {
          'Authorization': 'Client-ID $_unsplashApiKey',
        } : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'];
        }
      }
    } catch (e) {
      print('Error fetching fallback image: $e');
    }
    return _getLocalPlaceholder(category);
  }

  static String _getLocalPlaceholder(String category) {
    // Return placeholder image paths
    final placeholders = {
      'Breakfast': 'assets/images/breakfast_placeholder.png',
      'Lunch': 'assets/images/lunch_placeholder.png',
      'Dinner': 'assets/images/dinner_placeholder.png',
      'Snack': 'assets/images/snack_placeholder.png',
      'Dessert': 'assets/images/dessert_placeholder.png',
    };
    
    return placeholders[category] ?? 'assets/images/food_placeholder.png';
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}