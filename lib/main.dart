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
  String _scanStatus = "ضع الكرت داخل الإطار الأزرق";
  String _user = "";
  String _pass = "";
  bool _isLoginEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
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
    try {
      _isFlashOn ? await _controller.setFlashMode(FlashMode.off) : await _controller.setFlashMode(FlashMode.torch);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint("Flash Error: $e");
    }
  }

  Future<void> _takePicture() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStatus = "جاري قراءة بيانات الكرت...";
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      List<String> lines = recognizedText.text.split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) {
        _user = lines[0]; 
        _pass = lines.length > 1 ? lines[1] : lines[0]; 

        setState(() {
          _scanStatus = "تم استخراج البيانات ✅\nUser: $_user\nPass: $_pass";
          _isLoginEnabled = true;
          _isScanning = false;
        });
      } else {
        setState(() {
          _scanStatus = "فشلت القراءة، حاول مرة أخرى";
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = "خطأ في معالجة الكرت";
        _isScanning = false;
      });
    }
  }

  // المحرك المطور لتسجيل الدخول في الخلفية (POST Method)
  Future<void> _smartLogin() async {
    setState(() {
      _scanStatus = "جاري فتح الثغرة وتسجيل الدخول...";
      _isLoginEnabled = false;
    });

    try {
      // 1. اكتشاف رابط صفحة الميكروتيك الحالية
      var checkReq = http.Request('GET', Uri.parse("http://connectivitycheck.gstatic.com/generate_204"));
      checkReq.followRedirects = false;
      var checkRes = await checkReq.send().timeout(const Duration(seconds: 5));
      
      String loginUrl = checkRes.headers['location'] ?? "http://10.0.0.1/login";
      
      // تنظيف الرابط وتوجيهه لصفحة الـ Login مباشرة
      if (!loginUrl.contains("login")) {
         loginUrl = loginUrl.split('?')[0];
         if(!loginUrl.endsWith('/')) loginUrl += '/';
         loginUrl += "login"; 
      }

      // 2. إرسال البيانات عبر طلب POST (محاكاة المتصفح)
      var response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          'username': _user,
          'password': _pass,
          'dst': 'http://www.google.com',
          'popup': 'true',
        },
      ).timeout(const Duration(seconds: 12));

      // 3. تحليل النتيجة
      if (response.statusCode == 200 || response.statusCode == 302) {
        setState(() {
          _scanStatus = "تم تسجيل الدخول بنجاح! 🚀\nالإنترنت يعمل الآن في الخلفية";
        });
      } else {
        setState(() {
          _scanStatus = "تم إرسال الطلب، تحقق من الإنترنت";
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = "خطأ في الاتصال، تأكد من الواي فاي";
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
            // الكاميرا وإطار التحديد
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

            // واجهة التحكم
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                            IconButton(
                              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.yellow), 
                              onPressed: _toggleFlash, 
                              iconSize: 32
                            ),
                            GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                height: 80, width: 80,
                                decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.black, size: 40),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity, 
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoginEnabled ? _smartLogin : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              disabledBackgroundColor: Colors.white10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: const Text("تسجيل الدخول", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    
                    // التوقيع الأحمر العريض
                    const Text(
                      "Powered by : Sohail Shehada",
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.red, 
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.1,
                      ),
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
}
