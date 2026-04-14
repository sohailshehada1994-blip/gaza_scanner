import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // أضفنا هاد للتحقق من المستخدم
import 'dart:convert';
import 'screens/login_screen.dart';

// تعريف الكاميرات كمتغير عالمي لسهولة الوصول
List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  cameras = await availableCameras();
  
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    // التغيير الأول: يفتح مباشرة على الرئيسية كضيف
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
  List<Map<String, String>> _savedCards = [];
  
  // متغير للتحكم في عرض (الماسح) أو (المحفظة)
  int _selectedIndex = 0; 

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

  // --- 2. إدارة السحاب (Firebase) - محمي بالتحقق ---
  void _listenForIncomingCards() {
    // السحاب لا يعمل إلا إذا كان هناك مستخدم مسجل دخول
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('transfers')
        .where('receiver', isEqualTo: user.email) // نستخدم إيميل المستخدم الحقيقي
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        _saveCard(doc['user'], doc['pass']);
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

  // --- 3. محرك المسح الضوئي (متاح للجميع كضيف) ---
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
          SnackBar(content: Text("✅ تم حفظ الكرت محلياً: $user")),
        );
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

  // حوار المطالبة بتسجيل الدخول
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
        actions: [
          IconButton(
            icon: Icon(FirebaseAuth.instance.currentUser != null ? Icons.logout : Icons.person_add),
            onPressed: () {
              if (FirebaseAuth.instance.currentUser != null) {
                FirebaseAuth.instance.signOut();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تسجيل الخروج")));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: _selectedIndex == 0 ? _buildScannerUI() : _buildWalletUI(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          // حماية المحفظة: لا تفتح إلا للمسجلين
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

  // واجهة الماسح (متاحة للضيف)
  Widget _buildScannerUI() {
    return Column(
      children: [
        if (_controller.value.isInitialized)
          Container(
            height: 300,
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: CameraPreview(_controller),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            onPressed: _scanImage,
            icon: const Icon(Icons.camera),
            label: Text(_isProcessing ? "جاري القراءة..." : "إمسح الكرت الحين"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: Colors.blueAccent,
            ),
          ),
        ),
        const Text("💡 يمكنك مسح الكروت وحفظها على الجهاز كضيف", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  // واجهة المحفظة (تحتاج تسجيل دخول)
  Widget _buildWalletUI() {
    return _savedCards.isEmpty 
      ? const Center(child: Text("المحفظة خالية"))
      : ListView.builder(
          itemCount: _savedCards.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                title: Text("يوزر: ${_savedCards[index]['user']}"),
                subtitle: Text("باسورد: ${_savedCards[index]['pass']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.cloud_upload, color: Colors.orange),
                  onPressed: () => _sendViaCloud(index),
                ),
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
