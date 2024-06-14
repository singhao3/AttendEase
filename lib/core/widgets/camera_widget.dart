import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraWidget extends StatefulWidget {
  const CameraWidget({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CameraWidgetState createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      final CameraDescription frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _controller = CameraController(frontCamera, ResolutionPreset.medium);
      await _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }).catchError((e) {
        print('Error initializing camera: $e');
      });
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          print('Camera error: ${_controller!.value.errorDescription}');
        }
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized) {
      print("Camera not initialized");
      return;
    }

    if (_controller!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      print("Capture already pending");
      return;
    }

    try {
      print("Attempting to take picture");
      final XFile image = await _controller!.takePicture();
      print("Picture taken: ${image.path}");
      if (!mounted) {
        print("Widget not mounted after picture taken");
        return;
      }
      Navigator.pop(context, image);
      print("Navigator pop called");
    } catch (e) {
      print("Failed to take picture: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Capture Selfie")),
      body: Column(
        children: [
          Expanded(
            child: !_isCameraInitialized
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(_controller!),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: _takePicture,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
