import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;

class MLService {
  Interpreter? _interpreter;
  List _predictedData = [];

  List get predictedData => _predictedData;

  Future<void> initialize() async {
    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite', options: options);
  }

  void setCurrentPrediction(CameraImage cameraImage, Face face) {
    if (_interpreter == null) {
      throw Exception('Interpreter is not initialized');
    }
    List input = _preProcess(cameraImage, face);
    input = input.reshape([1, 112, 112, 3]);
    List output = List.generate(1, (index) => List.filled(192, 0));
    _interpreter!.run(input, output);
    _predictedData = output.reshape([192]);
  }

  Future<bool> matchFace(List referenceData) async {
    const double threshold = 1.0; // Adjust based on your accuracy needs
    double distance = _euclideanDistance(_predictedData, referenceData);
    return distance < threshold;
  }

  List _preProcess(CameraImage image, Face faceDetected) {
    imglib.Image croppedImage = _cropFace(image, faceDetected);
    imglib.Image img = imglib.copyResizeCropSquare(croppedImage, 112);
    Float32List imageAsList = imageToByteListFloat32(img);
    return imageAsList;
  }

  imglib.Image _cropFace(CameraImage image, Face faceDetected) {
    imglib.Image convertedImage = _convertCameraImage(image);
    double x = faceDetected.boundingBox.left - 10.0;
    double y = faceDetected.boundingBox.top - 10.0;
    double w = faceDetected.boundingBox.width + 10.0;
    double h = faceDetected.boundingBox.height + 10.0;
    return imglib.copyCrop(convertedImage, x.round(), y.round(), w.round(), h.round());
  }

  imglib.Image _convertCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    var img = imglib.Image(width, height); // Create Image buffer

    for (int plane = 0; plane < image.planes.length; plane++) {
      final bytes = image.planes[plane].bytes;
      for (int i = 0; i < bytes.length; i++) {
        final pixel = bytes[i];
        img.setPixel(i % width, i ~/ width, imglib.getColor(pixel, pixel, pixel));
      }
    }
    return imglib.copyRotate(img, -90);
  }

  Float32List imageToByteListFloat32(imglib.Image image) {
    final Float32List convertedBytes = Float32List(1 * 112 * 112 * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int i = 0; i < 112; i++) {
      for (int j = 0; j < 112; j++) {
        final pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (imglib.getRed(pixel) - 128) / 128;
        buffer[pixelIndex++] = (imglib.getGreen(pixel) - 128) / 128;
        buffer[pixelIndex++] = (imglib.getBlue(pixel) - 128) / 128;
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
