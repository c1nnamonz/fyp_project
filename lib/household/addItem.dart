import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp_project/household/rootPageHH.dart';
import 'package:fyp_project/household/scanPageHH.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class AddItemPage extends StatefulWidget {
  final File imageFile;

  const AddItemPage({super.key, required this.imageFile});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  File? _imageFile;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _purchaseDateController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = false;

  String _selectedCategory = 'Dry Groceries';
  String _selectedSubcategory = '';
  String _selectedUnit = '';

  final Map<String, List<String>> _categoryOptions = {
    'Dry Groceries': [
      'Snacks & Sweets',
      'Canned & Jarred Goods',
      'Pasta & Rice',
      'Baking Supplies',
      'Breakfast Cereals',
      'Condiments & Sauces'
    ],
    'Wet Groceries': [
      'Dairy & Eggs',
      'Meat & Poultry',
      'Seafood',
      'Fruits & Vegetables',
      'Ready Meals',
      'Beverages'
    ],
  };

  final Map<String, List<String>> _unitOptions = {
    'Dry Groceries': [
      'pieces',
      'grams (g)',
      'kilograms (kg)',
      'ounces (oz)',
      'pounds (lb)',
      'packages',
      'boxes',
      'cans',
      'bottles'
    ],
    'Wet Groceries': [
      'pieces',
      'grams (g)',
      'kilograms (kg)',
      'milliliters (ml)',
      'liters (L)',
      'fluid ounces (fl oz)',
      'cups',
      'bottles',
      'cartons'
    ],
  };

  @override
  void initState() {
    super.initState();
    _imageFile = widget.imageFile;
    // Set default subcategory and unit
    if (_categoryOptions.containsKey(_selectedCategory) &&
        _categoryOptions[_selectedCategory]!.isNotEmpty) {
      _selectedSubcategory = _categoryOptions[_selectedCategory]!.first;
    }
    if (_unitOptions.containsKey(_selectedCategory) &&
        _unitOptions[_selectedCategory]!.isNotEmpty) {
      _selectedUnit = _unitOptions[_selectedCategory]!.first;
    }
  }

  Future<void> _cropImage() async {
    if (_imageFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _imageFile!.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: lightColorScheme.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _imageFile = File(croppedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // Upload image to Firebase Storage and get download URL
  Future<String?> _uploadImageToStorage(File imageFile, String itemId) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('items')
          .child('$itemId.jpg');

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Save item to Firestore
  Future<bool> _saveItemToFirestore(String? imageUrl) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Generate a unique ID for the item
      final String itemId = const Uuid().v4();

      // Create item data
      final Map<String, dynamic> itemData = {
        'id': itemId,
        'userId': currentUser.uid,
        'name': _nameController.text,
        'purchaseDate': _purchaseDateController.text,
        'expiryDate': _expiryDateController.text,
        'quantity': int.parse(_quantityController.text),
        'unit': _selectedUnit, // Added unit field
        'category': _selectedCategory,
        'subcategory': _selectedSubcategory,
        'status': 'In-stock', // Automatically set status to "In-stock"
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .set(itemData);

      return true;
    } catch (e) {
      print('Error saving item to Firestore: $e');
      return false;
    }
  }

  // Show success dialog with options
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Text('Item added successfully!'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            ElevatedButton(
              child: Text('OK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF048C03),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate back to RootPageHousehold which contains the bottom nav
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => RootPageHousehold()),
                      (route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Handle the submission
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Generate a unique ID for image reference
      final String itemId = const Uuid().v4();

      // Upload image to Firebase Storage
      final String? imageUrl = await _uploadImageToStorage(_imageFile!, itemId);

      // Save item data to Firestore
      final bool success = await _saveItemToFirestore(imageUrl);

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Show success dialog instead of SnackBar
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add item. Please try again.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _handleSubmit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _cropImage,
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _imageFile != null
                        ? Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                    )
                        : const Icon(
                      Icons.add_a_photo,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // Date fields in a row
              Row(
                children: [
                  // Purchase Date Field
                  Expanded(
                    child: TextFormField(
                      controller: _purchaseDateController,
                      decoration: InputDecoration(
                        labelText: 'Purchase Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () => _selectDate(context, _purchaseDateController),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select purchase date';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Expiry Date Field
                  Expanded(
                    child: TextFormField(
                      controller: _expiryDateController,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.event_busy),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () => _selectDate(context, _expiryDateController),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select expiry date';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Quantity and Unit fields in a row
              Row(
                children: [
                  // Quantity Field
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.confirmation_number),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Unit Dropdown
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.straighten),
                      ),
                      value: _selectedUnit.isNotEmpty ? _selectedUnit : null,
                      items: _unitOptions[_selectedCategory]?.map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList() ?? [],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedUnit = newValue;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a unit';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                value: _selectedCategory,
                items: _categoryOptions.keys.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                      // Update subcategory when category changes
                      if (_categoryOptions[newValue]!.isNotEmpty) {
                        _selectedSubcategory = _categoryOptions[newValue]!.first;
                      } else {
                        _selectedSubcategory = '';
                      }
                      // Update unit when category changes
                      if (_unitOptions[newValue]!.isNotEmpty) {
                        _selectedUnit = _unitOptions[newValue]!.first;
                      } else {
                        _selectedUnit = '';
                      }
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // Subcategory Dropdown (visible based on selected category)
              if (_selectedCategory.isNotEmpty && _categoryOptions[_selectedCategory]!.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Food Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.fastfood),
                  ),
                  value: _selectedSubcategory,
                  items: _categoryOptions[_selectedCategory]!.map((String subcategory) {
                    return DropdownMenuItem<String>(
                      value: subcategory,
                      child: Text(subcategory),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSubcategory = newValue;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a food category';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(240, 55),
                  backgroundColor: const Color(0xFF048C03),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text('Add Groceries'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchaseDateController.dispose();
    _expiryDateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}