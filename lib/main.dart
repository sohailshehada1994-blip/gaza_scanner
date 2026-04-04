import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تأكد من تهيئة Firebase قبل تشغيل التطبيق
  await Firebase.initializeApp(); 
  final cameras = await availableCameras();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: GazaScannerHome(cameras: cameras),
  ));
}

class GazaScannerHome extends StatefulWidget {
  final List<CameraDescription> cameras;
  const GazaScannerHome({super.key, required this.cameras});

  @override
  State<GazaScannerHome> createState() => _GazaScannerHomeState();
}

class _GazaScannerHomeState extends State<GazaScannerHome> {
  late CameraController _controller;
  bool _isProcessing = false;
  List<Map<String, String>> _savedCards = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
    _loadCards(); // تحميل الكروت القديمة من الذاكرة
    _listenForIncomingCards(); // تشغيل "الرادار" لاستقبال الكروت عبر الإنترنت
  }

  // --- 1. إدارة الذاكرة المحلية (المحفظة) ---
  Future<void> _loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cardsData = prefs.getString('saved_cards');
    if (cardsData != null) {
      setState(() {
        _savedCards = List<Map<String, String>>.from(
          json.decode(cardsData).map((item) => Map<String, String>.from(item))
        );
      });
    }
  }

  Future<void> _saveCard(String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    _savedCards.add({
      'user': user,
      'pass': pass,
      'date': DateTime.now().toString().split('.')[0],
    });
    await prefs.setString('saved_cards', json.encode(_savedCards));
    setState(() {});
  }

  // --- 2. إدارة السحاب (Firebase) ---
  void _listenForIncomingCards() {
    // رادار بيسمع لأي كرت موجه لـ "Gaza_User"
    FirebaseFirestore.instance
        .collection('transfers')
        .where('receiver', isEqualTo: 'Gaza_User') 
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        _saveCard(doc['user'], doc['pass']);
        doc.reference.delete(); // حذف فوري لضمان المجانية
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 وصلك كرت جديد عبر الإنترنت!")),
        );
      }
    });
  }

  Future<void> _sendViaCloud(int index) async {
    try {
      await FirebaseFirestore.instance.collection('transfers').add({
        'user': _savedCards[index]['user'],
        'pass': _savedCards[index]['pass'],
        'receiver': 'Gaza_User', // في النسخة الجاي بنخلي المستخدم يختار المستلم
        'timestamp': FieldValue.serverTimestamp(),
      });
      // حذف الكرت من عندك بعد الإرسال الناجح
      setState(() => _savedCards.removeAt(index));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_cards', json.encode(_savedCards));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم الإرسال للسحاب وحذفه من محفظتك")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطأ في الإرسال: $e")),
      );
    }
  }

  // --- 3. محرك المسح الضوئي (OCR) ---
  Future<void> _scanImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String? user, pass;
      // منطق ذكي لاستخراج الأرقام الطويلة (اليوزر والباسورد)
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String cleanText = line.text.replaceAll(RegExp(r'\s+'), '');
          if (cleanText.contains(RegExp(r'[0-9]{5,15}'))) {
            if (user == null) {
              user = cleanText;
            } else {
              pass = cleanText;
            }
          }
        }
      }

      if (user != null && pass != null) {
        await _saveCard(user, pass);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ تم مسح وحفظ الكرت: $user")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ لم يتم العثور على أرقام واضحة.. حاول مرة أخرى")),
        );
      }
      textRecognizer.close();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gaza Scanner Pro"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // معاينة الكاميرا
          if (_controller.value.isInitialized)
            Container(
              height: 250,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CameraPreview(_controller),
              ),
            ),
          
          // زر المسح
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _scanImage,
              icon: const Icon(Icons.flash_on),
              label: Text(_isProcessing ? "جاري المعالجة..." : "إمسح كرت الآن"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text("📂 محفظة الكروت الممسوحة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // قائمة الكروت
          Expanded(
            child: _savedCards.isEmpty 
              ? const Center(child: Text("المحفظة خالية.. ابدأ المسح!"))
              : ListView.builder(
                  itemCount: _savedCards.length,
                  itemBuilder: (context, index) {
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: ListTile(
                        leading: const Icon(Icons.wifi_tethering, color: Colors.green),
                        title: Text("المستخدم: ${_savedCards[index]['user']}"),
                        subtitle: Text("كلمة السر: ${_savedCards[index]['pass']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر الـ QR
                            IconButton(
                              icon: const Icon(Icons.qr_code, color: Colors.blue),
                              onPressed: () => _showQRDialog(_savedCards[index]),
                            ),
                            // زر السحاب
                            IconButton(
                              icon: const Icon(Icons.cloud_upload, color: Colors.orange),
                              onPressed: () => _sendViaCloud(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(Map<String, String> card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("مسح سريع QR"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("اجعل الطرف الآخر يمسح هذا الكود:"),
            const SizedBox(height: 20),
            QrImageView(
              data: json.encode(card),
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
