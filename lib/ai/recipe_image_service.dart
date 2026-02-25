import 'dart:convert';
import 'package:http/http.dart' as http;

class RecipeImageService {
  // Unsplash API - FREE (No API key required for basic usage)
  static const String _unsplashBaseUrl = 'https://api.unsplash.com/search/photos';
  
  // Optional: Get free API key from https://unsplash.com/developers for higher limits
  static const String _unsplashApiKey = ''; // Leave empty for now, or add your free key

  static Future<String?> getRecipeImage(String recipeName, String category) async {
    try {
      // Create search query for food images
      String query = '$recipeName $category food dish meal recipe cooking';
      
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
          // Return a random image from results for variety
          final results = data['results'] as List;
          final randomIndex = DateTime.now().millisecond % results.length;
          return results[randomIndex]['urls']['regular'];
        }
      }

      // Fallback to generic food category images
      return await _getFallbackFoodImage(category);
      
    } catch (e) {
      print('Error fetching recipe image: $e');
      return _getLocalPlaceholder(category);
    }
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
