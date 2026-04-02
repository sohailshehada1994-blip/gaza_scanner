import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<void> main() async {
  // تأمين تهيئة التطبيق
  WidgetsFlutterBinding.ensureInitialized();
  
  // الحصول على الكاميرات المتاحة
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
    // استخدام دقة عالية لضمان قراءة الأرقام الصغيرة
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // التحكم بالفلاش
  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint("Flash Error: $e");
    }
  }

  // عملية التصوير واستخراج النص الحقيقي
  Future<void> _takePicture() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStatus = "جاري استخراج البيانات...";
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // معالجة النص المستخرج وتنظيفه
      List<String> lines = recognizedText.text.split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) {
        _user = lines[0]; // السطر الأول يوزر
        // إذا كان هناك سطر ثاني نأخذه كباسورد، وإلا فالباسورد هو نفسه اليوزر
        _pass = lines.length > 1 ? lines[1] : lines[0]; 

        setState(() {
          _scanStatus = "تم استخراج البيانات بنجاح ✅\nUser: $_user\nPass: $_pass";
          _isLoginEnabled = true;
          _isScanning = false;
        });
      } else {
        setState(() {
          _scanStatus = "فشلت القراءة، حاول تقريب الكاميرا أكثر";
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = "خطأ في معالجة الصورة";
        _isScanning = false;
      });
    }
  }

  // عملية تسجيل الدخول الذكية
  Future<void> _smartLogin() async {
    setState(() {
      _scanStatus = "جاري الاتصال بالشبكة...";
      _isLoginEnabled = false;
    });

    try {
      // محاولة اكتشاف صفحة الميكروتيك تلقائياً
      var request = http.Request('GET', Uri.parse("http://connectivitycheck.gstatic.com/generate_204"));
      request.followRedirects = false;
      var response = await request.send().timeout(const Duration(seconds: 5));
      
      String baseUrl = response.headers['location'] ?? "http://10.0.0.1/login";
      
      // إرسال طلب الدخول باليوزر والباسورد المستخرجين
      Uri loginUri = Uri.parse(baseUrl).replace(queryParameters: {
        'username': _user,
        'password': _pass,
      });

      var loginResponse = await http.get(loginUri).timeout(const Duration(seconds: 10));

      if (loginResponse.statusCode == 200) {
        setState(() => _scanStatus = "تم تسجيل الدخول بنجاح! استمتع 🚀");
      } else {
        setState(() => _scanStatus = "تم إرسال الطلب، تحقق من اتصالك.");
      }
    } catch (e) {
      setState(() {
        _scanStatus = "تأكد من اتصالك بشبكة الواي فاي";
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
            // قسم الكاميرا (نصف الشاشة العلوي تقريباً)
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
                  // إطار تحديد البطاقة
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

            // قسم التحكم والبيانات
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // حالة القراءة
                    Text(_scanStatus, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.cyan, fontWeight: FontWeight.bold)),
                    
                    // الأزرار
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
                            const SizedBox(width: 48), // للتوازن البصري
                          ],
                        ),
                        const SizedBox(height: 30),
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
                    
                    // التوقيع الشخصي باللون الأحمر العريض
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
