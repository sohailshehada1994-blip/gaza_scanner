import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'dart:convert';
import 'screens/login_screen.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  cameras = await availableCameras();
  
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const GazaScannerHome(), 
  ));
}

class GazaScannerHome extends StatefulWidget {
  const GazaScannerHome({super.key});

  @override
  State<GazaScannerHome> createState() => _GazaScannerHomeState();
}

class _GazaScannerHomeState extends State<GazaScannerHome> {
  late CameraController _controller;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _savedCards = []; // تم تغيير النوع لدعم bool اللون
  
  int _selectedIndex = 0; 

  // متغيرات مؤقتة لحمل بيانات الكرت الممسوح قبل اتخاذ قرار الحفظ
  String? _scannedUser;
  String? _scannedPass;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
    _loadCards(); 
    _listenForIncomingCards(); 
  }

  Future<void> _loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cardsData = prefs.getString('saved_cards');
    if (cardsData != null) {
      setState(() {
        _savedCards = List<Map<String, dynamic>>.from(json.decode(cardsData));
      });
    }
  }

  // تعديل منطق الحفظ ليدعم "الحالة" (مسجل أو ضيف)
  Future<void> _saveCard(String user, String pass, bool isRegistered) async {
    final prefs = await SharedPreferences.getInstance();
    _savedCards.add({
      'user': user,
      'pass': pass,
      'isRegistered': isRegistered, // لتحديد لون البطاقة لاحقاً
      'date': DateTime.now().toString().split('.')[0],
    });
    await prefs.setString('saved_cards', json.encode(_savedCards));
    setState(() {
      _scannedUser = null; // تفريغ البيانات المؤقتة بعد الحفظ
      _scannedPass = null;
    });
  }

  void _listenForIncomingCards() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('transfers')
        .where('receiver', isEqualTo: user.email) 
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        _saveCard(doc['user'], doc['pass'], true);
        doc.reference.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 وصلك كرت جديد عبر الإنترنت!")),
        );
      }
    });
  }

  Future<void> _sendViaCloud(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('transfers').add({
        'user': _savedCards[index]['user'],
        'pass': _savedCards[index]['pass'],
        'receiver': 'Gaza_User', 
        'sender': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
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

  Future<void> _scanImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String? user, pass;
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String cleanText = line.text.replaceAll(RegExp(r'\s+'), '');
          if (cleanText.contains(RegExp(r'[0-9]{5,15}'))) {
            if (user == null) { user = cleanText; } else { pass = cleanText; }
          }
        }
      }

      if (user != null && pass != null) {
        setState(() {
          _scannedUser = user;
          _scannedPass = pass;
        });
        ScannedResultFound(); // تنبيه بنجاح القراءة
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ لم يتم العثور على أرقام واضحة")),
        );
      }
      textRecognizer.close();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void ScannedResultFound() {
     ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم استخراج البيانات، اختر وسيلة الحفظ")),
     );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حماية البيانات"),
        content: const Text("يجب تسجيل الدخول باستخدام جيميل لتتمكن من استخدام ميزات السحاب والمحفظة الآمنة."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("لاحقاً")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            child: const Text("تسجيل دخول"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "ماسح الكروت" : "محفظتي الآمنة"),
      ),
      body: Column(
        children: [
          Expanded(child: _selectedIndex == 0 ? _buildScannerUI() : _buildWalletUI()),
          // التوقيع أسفل التطبيق
          Container(
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            color: Colors.black,
            child: const Text(
              "Powered by: Sohail Salim",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1 && FirebaseAuth.instance.currentUser == null) {
            _showLoginRequiredDialog();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "الماسح"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "المحفظة"),
        ],
      ),
    );
  }

  Widget _buildScannerUI() {
    return Column(
      children: [
        if (_controller.value.isInitialized)
          Container(
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: AspectRatio(
                aspectRatio: 16 / 9, // الكاميرا بالعرض
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CameraPreview(_controller),
                    // مستطيل تحديد الكرت
                    Container(
                      width: 250,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        if (_scannedUser == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _scanImage,
              icon: const Icon(Icons.camera),
              label: Text(_isProcessing ? "جاري القراءة..." : "مسح البطاقة"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.blueAccent,
              ),
            ),
          )
        else
          // ظهور الأزرار بعد المسح الناجح
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                       if (FirebaseAuth.instance.currentUser != null) {
                          _saveCard(_scannedUser!, _scannedPass!, true);
                       } else {
                          _showLoginRequiredDialog();
                       }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(0, 50)),
                    child: const Text("تسجيل الدخول"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveCard(_scannedUser!, _scannedPass!, false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(0, 50)),
                    child: const Text("حفظ البطاقة"),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWalletUI() {
    return _savedCards.isEmpty 
      ? const Center(child: Text("المحفظة خالية"))
      : ListView.builder(
          itemCount: _savedCards.length,
          itemBuilder: (context, index) {
            final card = _savedCards[index];
            final bool isGreen = card['isRegistered'] ?? false; // تحديد اللون
            return Card(
              color: isGreen ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                title: Text("يوزر: ${card['user']}"),
                subtitle: Text("باسورد: ${card['pass']}"),
                trailing: Icon(isGreen ? Icons.verified : Icons.save_alt, color: isGreen ? Colors.green : Colors.blue),
              ),
            );
          },
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
