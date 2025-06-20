import 'package:flutter/material.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeDetails extends StatefulWidget {
  final String recipeId;

  const RecipeDetails({
    super.key,
    required this.recipeId
  });

  @override
  State<RecipeDetails> createState() => _RecipeDetailsState();
}

class _RecipeDetailsState extends State<RecipeDetails> {
  bool isLoading = true;
  Map<String, dynamic> recipeData = {};
  List<Map<String, dynamic>> ingredients = [];

  @override
  void initState() {
    super.initState();
    fetchRecipeAndIngredients();
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

  // Helper method to format instructions into proper steps
  List<String> _formatInstructions(String instructions) {
    if (instructions.isEmpty) return [];

    // Split by numbered steps (1., 2., 3., etc.)
    List<String> steps = [];

    // First, try to split by numbered patterns
    RegExp stepPattern = RegExp(r'(\d+\.)\s*');
    List<String> parts = instructions.split(stepPattern);

    if (parts.length > 2) {
      // If we found numbered steps, process them
      for (int i = 1; i < parts.length; i += 2) {
        if (i + 1 < parts.length) {
          String stepNumber = parts[i];
          String stepContent = parts[i + 1].trim();
          if (stepContent.isNotEmpty) {
            steps.add('$stepNumber $stepContent');
          }
        }
      }
    } else {
      // If no numbered steps found, try to split by sentences
      List<String> sentences = instructions.split(RegExp(r'[.!?]+\s+'));
      for (String sentence in sentences) {
        sentence = sentence.trim();
        if (sentence.isNotEmpty && !sentence.endsWith('.') && !sentence.endsWith('!') && !sentence.endsWith('?')) {
          sentence += '.';
        }
        if (sentence.isNotEmpty) {
          steps.add(sentence);
        }
      }
    }

    return steps;
  }

  Future<void> fetchRecipeAndIngredients() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch recipe details
      final recipeDoc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .get();

      if (recipeDoc.exists) {
        final data = recipeDoc.data() as Map<String, dynamic>;
        setState(() {
          recipeData = {
            'id': recipeDoc.id,
            'name': data['name'] ?? 'Unknown Recipe',
            'timeRequired': data['timeRequired'] ?? 'Unknown',
            'imageUrl': data['imageUrl'] ?? '',
            'category': data['category'] ?? 'Uncategorized',
            'description': data['description'] ?? '',
            'instructions': data['instructions'] ?? '',
          };
        });

        // Fetch ingredients for this recipe
        final ingredientsSnapshot = await FirebaseFirestore.instance
            .collection('ingredients')
            .where('recipeId', isEqualTo: widget.recipeId)
            .get();

        List<Map<String, dynamic>> ingredientsList = [];
        for (var doc in ingredientsSnapshot.docs) {
          final ingredientData = doc.data();
          ingredientsList.add({
            'id': doc.id,
            'name': ingredientData['name'] ?? 'Unknown Ingredient',
            'quantity': ingredientData['quantity'] ?? 0,
            'unit': ingredientData['unit'] ?? '',
          });
        }

        setState(() {
          ingredients = ingredientsList;
          isLoading = false;
        });
      } else {
        // Recipe not found
        print('Recipe not found: ${widget.recipeId}');
        setState(() {
          recipeData = {
            'id': widget.recipeId,
            'name': 'Recipe Not Found',
            'timeRequired': 'Unknown',
            'imageUrl': '',
            'category': 'Uncategorized',
            'description': 'This recipe could not be found in the database.',
            'instructions': '',
          };
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching recipe details: $error');
      setState(() {
        recipeData = {
          'id': widget.recipeId,
          'name': 'Error Loading Recipe',
          'timeRequired': 'Unknown',
          'imageUrl': '',
          'category': 'Error',
          'description': 'There was an error loading this recipe.',
          'instructions': '',
        };
        isLoading = false;
      });
    }
  }

  // Build category title based on category name
  Widget _buildCategoryTitle(String category) {
    if (category == 'Quick & Eazy') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Quick ',
            style: TextStyle(
              color: Color(0xFF048C03),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '& Eazy',
            style: TextStyle(
              color: Color(0xFFD6BC00),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (category == 'Rich & Régal') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Rich ',
            style: TextStyle(
              color: Color(0xFF048C03),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '& ',
            style: TextStyle(
              color: Colors.red,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Régal',
            style: TextStyle(
              color: Color(0xFFD6BC00),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // Default title for other categories
      return Text(
        category,
        style: TextStyle(
          color: Color(0xFF048C03),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> instructionSteps = _formatInstructions(recipeData['instructions'] ?? '');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey[100],
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Category title
            Padding(
              padding: const EdgeInsets.fromLTRB(42.0, 50.0, 45.0, 25.0),
              child: _buildCategoryTitle(recipeData['category'] ?? 'Uncategorized'),
            ),

            // Recipe image
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: recipeData['imageUrl'] != null && recipeData['imageUrl'].isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: recipeData['imageUrl'],
                          width: 270,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 270,
                            height: 180,
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            getDefaultImageForRecipe(recipeData['name']),
                            width: 270,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Image.asset(
                          getDefaultImageForRecipe(recipeData['name']),
                          width: 270,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Recipe name
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(30.0, 7.0, 25.0, 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      recipeData['name'] ?? 'Unknown Recipe',
                      style: TextStyle(
                        color: lightColorScheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Recipe description
            if (recipeData['description'] != null && recipeData['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(40.0, 5.0, 40.0, 10.0),
                child: Text(
                  recipeData['description'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ),

            // Time required
            Padding(
              padding: const EdgeInsets.fromLTRB(40.0, 5.0, 40.0, 10.0),
              child: Text(
                'Time required: ${recipeData['timeRequired'] ?? 'Unknown'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),

            // Ingredients section
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(90.0, 7.0, 25.0, 5.0),
              child: Row(
                children: [
                  Text(
                    'Ingredients ',
                    style: TextStyle(
                      color: lightColorScheme.primary,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: 170,
                ),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: ingredients.isEmpty
                      ? [
                    Text(
                      'No ingredients found for this recipe.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ]
                      : ingredients.map((ingredient) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        '• ${ingredient['name']}: ${ingredient['quantity']} ${ingredient['unit']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Cooking instructions section
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(90.0, 7.0, 25.0, 5.0),
              child: Row(
                children: [
                  Text(
                    'Ways To Cook ',
                    style: TextStyle(
                      color: lightColorScheme.primary,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: 170,
                ),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: instructionSteps.isEmpty
                      ? [
                    Text(
                      'No cooking instructions available for this recipe.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ]
                      : instructionSteps.asMap().entries.map((entry) {
                    int index = entry.key;
                    String step = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step number circle (only if step doesn't already start with a number)
                          if (!RegExp(r'^\d+\.').hasMatch(step))
                            Container(
                              margin: const EdgeInsets.only(right: 12.0, top: 2.0),
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: lightColorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          // Step content
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Bottom spacing
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}