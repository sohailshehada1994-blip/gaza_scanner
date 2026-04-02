import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: GazaWifiScanner(camera: firstCamera),
  ));
}

class GazaWifiScanner extends StatefulWidget {
  final CameraDescription camera;
  const GazaWifiScanner({super.key, required this.camera});

  @override
  State<GazaWifiScanner> createState() => _GazaWifiScannerState();
}

// أضفنا WidgetsBindingObserver لمراقبة حالة التطبيق
class _GazaWifiScannerState extends State<GazaWifiScanner> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
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
    WidgetsBinding.instance.addObserver(this); // بدء المراقبة
    _initCamera();
  }

  // دالة تشغيل الكاميرا
  void _initCamera() {
    _controller = CameraController(widget.camera, ResolutionPreset.max);
    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // إنهاء المراقبة
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // هذه الدالة السحرية التي تتحكم في الكاميرا عند الخروج والعودة
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // التطبيق في الخلفية: أطفئ الكاميرا فوراً
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // عاد المستخدم للتطبيق: أعِد تشغيل الكاميرا
      _initCamera();
    }
  }

  Future<void> _setFlash(bool turnOn) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      await _controller!.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      setState(() => _isFlashOn = turnOn);
    } catch (e) {
      debugPrint("Flash Error: $e");
    }
  }

  String _extractCleanNumbers(String text) {
    String onlyNumbers = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.contains('.') && text.split('.').length >= 3) return ""; 
    return onlyNumbers.trim();
  }

  Future<void> _takePicture() async {
    if (_isScanning || _controller == null) return;
    setState(() {
      _isScanning = true;
      _scanStatus = "جاري استخراج الأرقام...";
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      List<String> validCodes = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String cleaned = _extractCleanNumbers(line.text);
          if (cleaned.length >= 4) validCodes.add(cleaned);
        }
      }

      if (validCodes.isNotEmpty) {
        _user = validCodes[0];
        _pass = validCodes.length > 1 ? validCodes[1] : validCodes[0];
        setState(() {
          _scanStatus = "تم استخراج الكود بنجاح ✅\nUser: $_user";
          _isLoginEnabled = true;
          _isScanning = false;
        });
      } else {
        setState(() {
          _scanStatus = "لم يتم العثور على أرقام، حاول ثانية";
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() { _scanStatus = "خطأ في المعالجة"; _isScanning = false; });
    }
  }

  Future<void> _smartLogin() async {
    if (_isFlashOn) await _setFlash(false);
    setState(() {
      _scanStatus = "جاري تسجيل الدخول في الخلفية...";
      _isLoginEnabled = false;
    });

    try {
      var initialResponse = await http.get(Uri.parse("http://connectivitycheck.gstatic.com/generate_204")).timeout(const Duration(seconds: 5));
      String loginUrl = initialResponse.headers['location'] ?? "http://10.0.0.1/login";

      if (!loginUrl.contains("login")) {
         loginUrl = loginUrl.split('?')[0];
         if(!loginUrl.endsWith('/')) loginUrl += '/';
         loginUrl += "login"; 
      }

      var response = await http.post(
        Uri.parse(loginUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded", "Referer": loginUrl},
        body: {'username': _user, 'password': _pass, 'dst': 'http://www.google.com'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        setState(() => _scanStatus = "تم تسجيل الدخول بنجاح! 🚀");
      } else {
        setState(() => _scanStatus = "تم الإرسال، تحقق من الإنترنت");
      }
    } catch (e) {
      setState(() { _scanStatus = "تأكد من الشبكة وحاول مجدداً"; _isLoginEnabled = true; });
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
            SizedBox(
              height: size.height * 0.45,
              child: Stack(
                children: [
                  FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && _controller != null) {
                        return Center(child: CameraPreview(_controller!));
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
                              onPressed: () => _setFlash(!_isFlashOn), 
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
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity, height: 55,
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
                    const Text(
                      "Powered by : Sohail Shehada",
                      style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
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
