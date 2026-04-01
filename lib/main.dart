import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const GazaWifiApp());
}

class GazaWifiApp extends StatelessWidget {
  const GazaWifiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WifiScannerScreen(),
    );
  }
}

class WifiScannerScreen extends StatefulWidget {
  const WifiScannerScreen({super.key});

  @override
  State<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen> {
  // متغيرات التحكم
  bool _isCardDetected = false; // هل التقطت الكاميرا الرابط؟
  String _hiddenUrl = "";       // الرابط المخفي عن المستخدم
  MobileScannerController cameraController = MobileScannerController();

  // دالة فتح الرابط في المتصفح
  Future<void> _launchLoginUrl() async {
    final Uri url = Uri.parse(_hiddenUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("عذراً، تعذر فتح الرابط")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. الكاميرا في الخلفية
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_isCardDetected) {
                  setState(() {
                    _hiddenUrl = barcode.rawValue!;
                    _isCardDetected = true; // "إضاءة" الزر وتفعيل الحالة
                  });
                }
              }
            },
          ),

          // 2. القناع المظلم (Overlay) لجعل الكاميرا تظهر فقط داخل المستطيل
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7), // تعتيم الشاشة حول البطاقة
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                // هذا هو "مستطيل البطاقة" الشفاف
                Center(
                  child: Container(
                    width: 280, // عرض المستطيل
                    height: 160, // طول المستطيل (متناسب مع كرت الشبكة)
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. الإطار الملون حول المستطيل (أبيض ثم يتحول لأخضر)
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isCardDetected ? Colors.greenAccent : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: _isCardDetected 
                ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50)
                : const SizedBox(),
            ),
          ),

          // 4. النصوص والأزرار في الأسفل
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  _isCardDetected ? "✅ تم التعرف على البطاقة" : "ضع كرت الإنترنت داخل المستطيل",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 20),
                
                // زر تسجيل الدخول "المضيء"
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCardDetected ? Colors.blueAccent : Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: _isCardDetected ? 10 : 0,
                    ),
                    onPressed: _isCardDetected ? _launchLoginUrl : null,
                    child: Text(
                      _isCardDetected ? "تسجيل الدخول الآن" : "في انتظار قراءة الكرت...",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                // زر لإعادة المحاولة (يظهر فقط بعد القراءة)
                if (_isCardDetected)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isCardDetected = false;
                        _hiddenUrl = "";
                      });
                    },
                    child: const Text("إعادة التصوير", style: TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}