import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: GazaWifiScanner(camera: cameras.first),
  ));
}

// نموذج البطاقة المطور
class WifiCard {
  String user;
  String pass;
  String status; // 'new' (blue), 'active' (green), 'expired' (red)
  DateTime? activationTime;

  WifiCard({required this.user, required this.pass, this.status = 'new', this.activationTime});

  Map<String, dynamic> toJson() => {
    'user': user, 'pass': pass, 'status': status, 
    'time': activationTime?.toIso8601String()
  };

  factory WifiCard.fromJson(Map<String, dynamic> json) => WifiCard(
    user: json['user'], pass: json['pass'], status: json['status'],
    activationTime: json['time'] != null ? DateTime.parse(json['time']) : null
  );
}

class GazaWifiScanner extends StatefulWidget {
  final CameraDescription camera;
  const GazaWifiScanner({super.key, required this.camera});
  @override
  State<GazaWifiScanner> createState() => _GazaWifiScannerState();
}

class _GazaWifiScannerState extends State<GazaWifiScanner> with WidgetsBindingObserver {
  CameraController? _controller;
  final TextRecognizer _textRecognizer = TextRecognizer();
  List<WifiCard> _wallet = [];
  String _statusMsg = "جاهز لمسح الكروت";
  bool _isScanning = false;
  Timer? _globalTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadData();
    // تحديث الواجهة والتدقيق كل دقيقة
    _globalTimer = Timer.periodic(const Duration(minutes: 1), (t) => _refreshLogic());
  }

  // --- منطق الإدارة والتنظيف ---
  void _refreshLogic() {
    DateTime now = DateTime.now();
    bool changed = false;

    for (var card in _wallet) {
      // 1. تحويل الأخضر للأحمر بعد 8 ساعات
      if (card.status == 'active' && card.activationTime != null) {
        if (now.difference(card.activationTime!).inHours >= 8) {
          card.status = 'expired';
          changed = true;
        }
      }
    }

    // 2. التنظيف التلقائي (حذف الأحمر بعد 24 ساعة)
    _wallet.removeWhere((card) {
      if (card.status == 'expired' && card.activationTime != null) {
        if (now.difference(card.activationTime!).inHours >= 32) { // 8 + 24
          changed = true;
          return true;
        }
      }
      return false;
    });

    if (changed) {
      _saveData();
      setState(() {});
    }
  }

  // --- مراقب الإنترنت الذكي ---
  Future<void> _checkNetwork() async {
    try {
      final res = await http.get(Uri.parse("http://google.com")).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) _investigate();
    } catch (e) { _investigate(); }
  }

  Future<void> _investigate() async {
    try {
      final res = await http.get(Uri.parse("http://10.0.0.1")).timeout(const Duration(seconds: 5));
      if (res.body.contains("expired") || res.body.contains("login")) {
        // تنبيه صوتي (ALARM)
        setState(() => _statusMsg = "⚠️ البطاقة انتهت! فعل كرت جديد");
      }
    } catch (e) { /* الشبكة طافية - لا تفعل شيئاً */ }
  }

  // --- الكاميرا والتعرف على النص ---
  void _initCamera() {
    _controller = CameraController(widget.camera, ResolutionPreset.max);
    _controller!.initialize().then((_) => setState(() {}));
  }

  Future<void> _scanCard() async {
    if (_isScanning) return;
    setState(() { _isScanning = true; _statusMsg = "جاري الحفظ ككرت جديد (أزرق)..."; });

    final img = await _controller!.takePicture();
    final recognized = await _textRecognizer.processImage(InputImage.fromFilePath(img.path));
    
    String code = "";
    for (var b in recognized.blocks) {
      for (var l in b.lines) {
        String c = l.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (c.length >= 4 && !l.text.contains('.')) { code = c; break; }
      }
    }

    if (code.isNotEmpty) {
      _wallet.add(WifiCard(user: code, pass: code, status: 'new'));
      await _saveData();
      setState(() { _statusMsg = "تم الإضافة للمحفظة ✅"; _isScanning = false; });
    } else {
      setState(() { _statusMsg = "فشلت القراءة"; _isScanning = false; });
    }
  }

  // --- تسجيل الدخول ---
  void _activateCard(WifiCard card) {
    setState(() {
      // تحويل أي كرت أخضر قديم لأحمر
      for (var c in _wallet) { if (c.status == 'active') c.status = 'expired'; }
      card.status = 'active';
      card.activationTime = DateTime.now();
      _statusMsg = "البطاقة نشطة الآن (خضراء) 🟢";
    });
    _saveData();
  }

  // --- التخزين ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wallet_v2');
    if (raw != null) {
      setState(() { _wallet = List<WifiCard>.from(json.decode(raw).map((x) => WifiCard.fromJson(x))); });
    }
    _refreshLogic();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_v2', json.encode(_wallet.map((x) => x.toJson()).toList()));
  }

  @override
  void dispose() { _globalTimer?.cancel(); _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wifi Master V2"), actions: [
        IconButton(icon: const Icon(Icons.account_balance_wallet), onPressed: _showWallet)
      ]),
      body: Column(
        children: [
          Expanded(flex: 2, child: Stack(children: [
            if (_controller != null && _controller!.value.isInitialized) CameraPreview(_controller!),
            Center(child: Container(width: 250, height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(15)))),
          ])),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Text(_statusMsg, style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: _scanCard, icon: const Icon(Icons.add_a_photo), label: const Text("تصوير كرت جديد")),
            const SizedBox(height: 15),
            const Text("Powered by : Sohail Shehada", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          ]))
        ],
      ),
    );
  }

  void _showWallet() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => Container(
      height: 500, padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text("المحفظة الذكية", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Divider(),
        Expanded(child: ListView.builder(
          itemCount: _wallet.length,
          itemBuilder: (c, i) {
            final card = _wallet[i];
            Color col = card.status == 'active' ? Colors.green : (card.status == 'expired' ? Colors.red : Colors.blue);
            String timeText = "";
            if (card.status == 'active' && card.activationTime != null) {
              int mins = 480 - DateTime.now().difference(card.activationTime!).inMinutes;
              timeText = " - متبقي ${mins ~/ 60}س ${mins % 60}د";
            }
            return ListTile(
              leading: Icon(Icons.wifi, color: col),
              title: Text("كود: ${card.user} $timeText"),
              subtitle: Text(card.status == 'active' ? "نشطة حالياً" : (card.status == 'new' ? "جديدة" : "منتهية")),
              onTap: card.status == 'new' ? () => _activateCard(card) : null,
            );
          },
        ))
      ]),
    ));
  }
}
