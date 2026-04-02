import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  
  bool _isFlashOn = false;
  bool _isScanning = false;
  String _scanStatus = "ضع البطاقة داخل الإطار";
  String? _extractedCode;
  bool _isLoginEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    if (_isFlashOn) {
      await _controller.setFlashMode(FlashMode.off);
    } else {
      await _controller.setFlashMode(FlashMode.torch);
    }
    setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _takePicture() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStatus = "جاري استخراج الكود...";
    });

    try {
      await _initializeControllerFuture;
      await _controller.takePicture();
      
      // هنا تتم عملية الـ OCR (نستخدم كود تجريبي حالياً)
      await Future.delayed(const Duration(seconds: 1)); 
      String dummyCode = "88229944"; // مثال لكود كرت

      setState(() {
        _extractedCode = dummyCode;
        _scanStatus = "تم استخراج الكود: $_extractedCode";
        _isLoginEnabled = true;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _scanStatus = "خطأ في التصوير، حاول ثانية";
        _isScanning = false;
      });
    }
  }

  // الدالة الذكية لاكتشاف الرابط وتسجيل الدخول
  Future<void> _smartLogin() async {
    setState(() {
      _scanStatus = "جاري فحص الشبكة وتسجيل الدخول...";
      _isLoginEnabled = false;
    });

    try {
      // محاولة فتح رابط وهمي لإجبار الميكروتيك على التحويل
      var request = http.Request('GET', Uri.parse("http://connectivitycheck.gstatic.com/generate_204"));
      request.followRedirects = false; // لا نريد اتباع التحويل تلقائياً، نريد الإمساك به
      
      var response = await request.send().timeout(const Duration(seconds: 5));
      String finalUrl = "";

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307) {
        // إذا قام الميكروتيك بالتحويل، نأخذ الرابط من الـ Header
        finalUrl = response.headers['location'] ?? "http://10.0.0.1/login";
      } else {
        // إذا لم يحدث تحويل، نستخدم الرابط الافتراضي الأكثر شيوعاً في غزة
        finalUrl = "http://10.0.0.1/login";
      }

      // تجهيز رابط تسجيل الدخول النهائي مع الكود
      // ملاحظة: أغلب ميكروتيك يستخدم بارامتر username أو code
      Uri loginUri = Uri.parse(finalUrl).replace(queryParameters: {
        'username': _extractedCode,
        'password': '', // غالباً الكرت لا يحتاج باسوورد
      });

      var loginResponse = await http.get(loginUri).timeout(const Duration(seconds: 10));

      if (loginResponse.statusCode == 200) {
        setState(() => _scanStatus = "تم تسجيل الدخول بنجاح! ✅");
      } else {
        setState(() => _scanStatus = "تم إرسال الطلب، تحقق من الإنترنت.");
      }
    } catch (e) {
      setState(() => _scanStatus = "تأكد من اتصالك بشبكة الواي فاي");
      _isLoginEnabled = true;
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
            // 1. الكاميرا المحددة
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
                  // مستطيل البطاقة
                  Center(
                    child: Container(
                      width: size.width * 0.75,
                      height: (size.width * 0.75) / 1.58,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyan, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. الواجهة والتحكم
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_scanStatus, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyan)),
                    
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.yellow), 
                                       onPressed: _toggleFlash, iconSize: 32),
                            GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                height: 80, width: 80,
                                decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.black, size: 40),
                              ),
                            ),
                            const SizedBox(width: 48), // للتوازن
                          ],
                        ),
                        const SizedBox(height: 40),
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
                    const Text("Powered by : Sohail Shehada", style: TextStyle(color: Colors.white30, fontSize: 12)),
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
