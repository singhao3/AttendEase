import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;

class MLService {
  Interpreter? _interpreter;
  List _predictedData = [];

  List get predictedData => _predictedData;

  Future<void> initialize() async {
    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite',
        options: options);
  }

  Future<List> validateAndExtractFaceData(Uint8List imageBytes) async {
    print("Validating and extracting face data");
    final face = await detectFaceFromBytes(imageBytes);
    if (face == null) {
      throw Exception("No face detected in the uploaded profile picture.");
    }
    setCurrentPrediction(imageBytes, face);
    return predictedData;
  }

  Future<Face?> detectFaceFromBytes(Uint8List bytes) async {
    print("Starting face detection from bytes");
    imglib.Image? img = imglib.decodeImage(Uint8List.fromList(bytes));
    if (img == null) {
      print("Failed to decode image");
      return null;
    }
    print("Image decoded successfully");

    // Convert image to NV21 format
    final nv21Bytes = _convertImageToNv21(img);

    final metadata = InputImageMetadata(
      size: Size(img.width.toDouble(), img.height.toDouble()),
      rotation: InputImageRotation.rotation0deg, // Adjust if image is rotated
      format: InputImageFormat.nv21, // Using NV21 format
      bytesPerRow: img.width, // Bytes per row for NV21
    );

    print("Image metadata created: $metadata");

    final inputImage = InputImage.fromBytes(
      bytes: nv21Bytes, // Convert image to NV21 format
      metadata: metadata,
    );

    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.1, // Minimum size of face to detect
      ),
    );
    try {
      final List<Face> faces = await faceDetector.processImage(inputImage);
      print("Faces detected: ${faces.length}");
      return faces.isNotEmpty ? faces.first : null;
    } catch (e) {
      print("Error during face detection: $e");
      return null;
    } finally {
      faceDetector.close();
    }
  }

  void setCurrentPrediction(Uint8List imageBytes, Face face) {
    if (_interpreter == null) {
      throw Exception('Interpreter is not initialized');
    }
    List input = _preProcess(imageBytes, face);
    input = input.reshape([1, 112, 112, 3]);
    List output = List.generate(1, (index) => List.filled(192, 0));
    _interpreter!.run(input, output);
    _predictedData = output.reshape([192]);
  }

  Future<bool> matchFace(List referenceData) async {
    const double threshold = 1.0; // Adjust based on your accuracy needs
    double distance = _euclideanDistance(_predictedData, referenceData);
    print("Euclidean distance: $distance");
    return distance < threshold;
  }

  Uint8List _convertImageToNv21(imglib.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int frameSize = width * height;
    final Uint8List yuv = Uint8List(frameSize + 2 * (frameSize ~/ 4));

    int yIndex = 0;
    int uvIndex = frameSize;

    for (int j = 0; j < height; j++) {
      for (int i = 0; i < width; i++) {
        imglib.Pixel pixel = image.getPixel(i, j);

        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        int y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
        int u = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
        int v = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;

        yuv[yIndex++] = y.clamp(0, 255);

        if (j % 2 == 0 && i % 2 == 0) {
          yuv[uvIndex++] = v.clamp(0, 255);
          yuv[uvIndex++] = u.clamp(0, 255);
        }
      }
    }

    return yuv;
  }

  List _preProcess(Uint8List imageBytes, Face faceDetected) {
    imglib.Image img = imglib.decodeImage(imageBytes)!;
    imglib.Image croppedImage = _cropFace(img, faceDetected);
    imglib.Image imgResized = imglib.copyResizeCropSquare(croppedImage, size: 112);
    Float32List imageAsList = imageToByteListFloat32(imgResized);
    return imageAsList;
  }

  imglib.Image _cropFace(imglib.Image image, Face faceDetected) {
    double x = faceDetected.boundingBox.left - 10.0;
    double y = faceDetected.boundingBox.top - 10.0;
    double w = faceDetected.boundingBox.width + 10.0;
    double h = faceDetected.boundingBox.height + 10.0;
    return imglib.copyCrop(
      image,
      x: x.round(),
      y: y.round(),
      width: w.round(),
      height: h.round(),
    );
  }

  Float32List imageToByteListFloat32(imglib.Image image) {
    final Float32List convertedBytes = Float32List(1 * 112 * 112 * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int i = 0; i < 112; i++) {
      for (int j = 0; j < 112; j++) {
        final pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r.toInt() - 128) / 128;
        buffer[pixelIndex++] = (pixel.g.toInt() - 128) / 128;
        buffer[pixelIndex++] = (pixel.b.toInt() - 128) / 128;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  double _euclideanDistance(List e1, List e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow(e1[i] - e2[i], 2);
    }
    return sqrt(sum);
  }
}
