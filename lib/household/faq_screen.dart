import 'package:flutter/material.dart';
import 'package:fyp_project/theme/theme.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs'),
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        // Background color/gradient for the app background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lightColorScheme.primary.withOpacity(0.3),
              Colors.white,
            ],
          ),
        ),
        width: size.width,
        height: size.height,
        child: Column(
          children: [
            // App logo at the top middle
            Container(
              padding: const EdgeInsets.only(top: 30, bottom: 20),
              alignment: Alignment.center,
              child: Image.asset(
                'images/applogo.png', // Replace with your app logo
                width: 150,
                height: 150,
              ),
            ),

            // FAQ content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFaqItem(
                        'What is this app for?',
                        'This app helps you track your household grocery items and manage their expiry dates to reduce food waste.'
                    ),
                    _buildFaqItem(
                        'How do I add items?',
                        'Go to the Add Item tab and fill in the details of your grocery item including name, quantity, expiry date, and category.'
                    ),
                    _buildFaqItem(
                        'How does the expiry notification work?',
                        'The app will automatically mark items as "Wasted" when they expire. Items nearing expiry will be highlighted with an orange border.'
                    ),
                    _buildFaqItem(
                        'Can I sort items by expiry date?',
                        'Yes, you can use the "Sort By" dropdown on the Items List page and select "Expiring Soon" to see items that will expire soon at the top.'
                    ),
                    _buildFaqItem(
                        'How do I edit or update an item?',
                        'Tap on any item in your list to open the edit dialog where you can change the quantity or status.'
                    ),
                    _buildFaqItem(
                        'What are the different item statuses?',
                        'Items can be "In-stock", "Consumed" (when you use them), or "Wasted" (when they expire or are thrown away).'
                    ),
                    _buildFaqItem(
                        'Can I filter items by category?',
                        'Yes, you can filter by "Wet" or "Dry" groceries, and also by specific subcategories like "Dairy & Eggs" or "Snacks & Sweets".'
                    ),
                    _buildFaqItem(
                        'How do I delete an item?',
                        'Currently, you can mark items as "Consumed" or "Wasted" to remove them from your active inventory.'
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}