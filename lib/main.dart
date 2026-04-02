import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: GazaWifiScanner(camera: firstCamera),
    ),
  );
}

class GazaWifiScanner extends StatefulWidget {
  final CameraDescription camera;
  const GazaWifiScanner({super.key, required this.camera});

  @override
  State<GazaWifiScanner> createState() => _GazaWifiScannerState();
}

class _GazaWifiScannerState extends State<GazaWifiScanner> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  bool _isFlashOn = false;
  bool _isScanning = false;
  String _scanStatus = "ضع الكرت داخل الإطار";
  String _user = "";
  String _pass = "";
  bool _isLoginEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high); // دقة عالية للقراءة
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    _isFlashOn ? await _controller.setFlashMode(FlashMode.off) : await _controller.setFlashMode(FlashMode.torch);
    setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _takePicture() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStatus = "جاري قراءة الكرت...";
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      // معالجة الصورة لاستخراج النص
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // تنظيف النص (إزالة المسافات والأسطر الفارغة)
      List<String> lines = recognizedText.text.split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) {
        _user = lines[0]; // السطر الأول دائماً يوزر
        // إذا كان هناك سطر ثاني نأخذه ككلمة مرور، وإلا نستخدم اليوزر نفسه ككلمة مرور
        _pass = lines.length > 1 ? lines[1] : lines[0]; 

        setState(() {
          _scanStatus = "تم الاستخراج بنجاح ✅\nيوزر: $_
