import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_project/theme/theme.dart';
import 'addItem.dart';

class ScanPageHousehold extends StatefulWidget {
  const ScanPageHousehold({super.key});

  @override
  State<ScanPageHousehold> createState() => _ScanPageHouseholdState();
}

class _ScanPageHouseholdState extends State<ScanPageHousehold> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = false;
  XFile? _capturedImage;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isDisposed) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return;
      }

      final camera = _isFrontCamera
          ? cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first)
          : cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);

      if (_cameraController != null) {
        await _cameraController!.dispose();
      }

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
      );

      await _cameraController!.initialize();

      if (!mounted || _isDisposed) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (!mounted || _isDisposed) return;
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      if (!mounted || _isDisposed) return;
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _capturedImage = pickedFile;
      });
    }
  }

  Future<void> _switchCamera() async {
    setState(() {
      _isCameraInitialized = false;
      _isFrontCamera = !_isFrontCamera;
    });
    await _cameraController?.dispose();
    await _initializeCamera();
  }


  Widget _buildCameraFrame(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double frameWidth = size.width * 0.8;
    double frameHeight = frameWidth * 1.2; // Adjust aspect ratio as needed
    double frameBorderWidth = 4.0;

    return Stack(
      children: [
        // Semi-transparent overlay
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.4),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
                child: Center(
                  child: Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Frame border
        Center(
          child: Container(
            width: frameWidth + frameBorderWidth * 2,
            height: frameHeight + frameBorderWidth * 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: frameBorderWidth,
              ),
            ),
          ),
        ),
        // Instructions text
        Positioned(
          bottom: size.height * 0.25,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Align your item within the frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview or captured image
          if (_capturedImage != null)
            Positioned.fill(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
              ),
            )
          else if (_isCameraInitialized)
            Positioned.fill(
              child: Stack(
                children: [
                  CameraPreview(_cameraController!),
                  _buildCameraFrame(context),
                ],
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Top buttons (keep this the same)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: lightColorScheme.primary.withOpacity(.15),
                    ),
                    child: Icon(
                      Icons.close,
                      color: lightColorScheme.primary,
                    ),
                  ),
                ),
                if (_capturedImage != null)
                  GestureDetector(
                    onTap: () {
                      debugPrint('Share image');
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: lightColorScheme.primary.withOpacity(.15),
                      ),
                      child: Icon(
                        Icons.share,
                        color: lightColorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_capturedImage == null)
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_capturedImage != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _capturedImage = null;
                          });
                        },
                        child: Text(
                          'Retake',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    if (_capturedImage == null)
                      IconButton(
                        onPressed: _switchCamera,
                        icon: Icon(
                          Icons.cameraswitch,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    if (_capturedImage == null)
                      IconButton(
                        onPressed: _pickImageFromGallery,
                        icon: Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    if (_capturedImage != null)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddItemPage(
                                imageFile: File(_capturedImage!.path),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}