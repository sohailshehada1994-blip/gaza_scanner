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
          _scanStatus = "تم الاستخراج بنجاح ✅\nيوزر: $_user\nباسورد: $_pass";
          _isLoginEnabled = true;
          _isScanning = false;
        });
      } else {
        setState(() {
          _scanStatus = "لم يتم اكتشاف نص، حاول تقريب الكاميرا";
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = "حدث خطأ أثناء القراءة";
        _isScanning = false;
      });
    }
  }

  Future<void> _smartLogin() async {
    setState(() {
      _scanStatus = "جاري محاولة الدخول للشبكة...";
      _isLoginEnabled = false;
    });

    try {
      // 1. محاولة اكتشاف صفحة الميكروتيك (الحل الثالث الذكي)
      var request = http.Request('GET', Uri.parse("http://connectivitycheck.gstatic.com/generate_204"));
      request.followRedirects = false;
      var response = await request.send().timeout(const Duration(seconds: 4));
      
      String baseUrl = response.headers['location'] ?? "http://10.0.0.1/login";
      
      // 2. إرسال بيانات الدخول (يوزر وباسورد)
      Uri loginUri = Uri.parse(baseUrl).replace(queryParameters: {
        'username': _user,
        'password': _pass,
      });

      var loginResponse = await http.get(loginUri).timeout(const Duration(seconds: 10));

      if (loginResponse.statusCode == 200) {
        setState(() => _scanStatus = "تم تسجيل الدخول! استمتع بالإنترنت 🚀");
      } else {
        setState(() => _scanStatus = "تم إرسال الطلب، تأكد من حالة الكرت.");
      }
    } catch (e) {
      setState(() {
        _scanStatus = "تأكد من اتصالك بالواي فاي";
        _isLoginEnabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // الكاميرا
            SizedBox(
              height: size.height * 0.45,
              child: Stack(
                children: [
                  FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return Center(child: CameraPreview(_controller));
                      }
                      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                    },
                  ),
                  Center(
                    child: Container(
                      width: size.width * 0.8,
                      height: (size.width * 0.8) / 1.58,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyan, width: 3),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // التحكم والمعلومات
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_scanStatus, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.cyan, fontWeight: FontWeight.bold)),
                    
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.yellow), 
                                       onPressed: _toggleFlash, iconSize: 30),
                            GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                height: 75, width: 75,
                                decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.black, size: 35),
                              ),
                            ),
                            const SizedBox(width: 45),
                          ],
                        ),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity, height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoginEnabled ? _smartLogin : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              disabledBackgroundColor: Colors.white10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: const Text("تسجيل الدخول", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const Text("Powered by : Sohail Shehada", style: TextStyle(color: Colors.white30, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
