import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

// نموذج بيانات الكرت
class WifiCard {
  String user;
  String pass;
  String status; // 'new' (blue), 'active' (green), 'expired' (red)
  DateTime? expiryTime;

  WifiCard({required this.user, required this.pass, this.status = 'new', this.expiryTime});

  Map<String, dynamic> toJson() => {'user': user, 'pass': pass, 'status': status, 'expiryTime': expiryTime?.toIso8601String()};
  factory WifiCard.fromJson(Map<String, dynamic> json) => WifiCard(
    user: json['user'], pass: json['pass'], status: json['status'],
    expiryTime: json['expiryTime'] != null ? DateTime.parse(json['expiryTime']) : null,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(primaryColor: Colors.cyan),
    home: GazaWifiScanner(camera: cameras.first),
  ));
}

class GazaWifiScanner extends StatefulWidget {
  final CameraDescription camera;
  const GazaWifiScanner({super.key, required this.camera});
  @override
  State<GazaWifiScanner> createState() => _GazaWifiScannerState();
}

class _GazaWifiScannerState extends State<GazaWifiScanner> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isFlashOn = false;
  bool _isScanning = false;
  String _tempUser = "";
  String _tempPass = "";
  List<WifiCard> _wallet = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadWallet();
  }

  void _initCamera() {
    _controller = CameraController(widget.camera, ResolutionPreset.max);
    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _setFlash(false);
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('wifi_wallet');
    if (data != null) {
      List decoded = jsonDecode(data);
      setState(() {
        _wallet = decoded.map((item) => WifiCard.fromJson(item)).toList();
      });
      _cleanExpiredCards();
    }
  }

  Future<void> _saveWallet() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('wifi_wallet', jsonEncode(_wallet.map((e) => e.toJson()).toList()));
  }

  void _cleanExpiredCards() {
    setState(() {
      _wallet.removeWhere((card) => card.status == 'expired' && 
          card.expiryTime != null && DateTime.now().difference(card.expiryTime!).inHours >= 24);
    });
    _saveWallet();
  }

  Future<void> _setFlash(bool turnOn) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
    setState(() => _isFlashOn = turnOn);
  }

  Future<void> _takePicture() async {
    if (_isScanning || _controller == null) return;
    setState(() => _isScanning = true);
    try {
      final image = await _controller!.takePicture();
      final recognizedText = await _textRecognizer.processImage(InputImage.fromFilePath(image.path));
      List<String> codes = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          String clean = line.text.replaceAll(RegExp(r'[^0-9]'), '').trim();
          if (clean.length >= 4) codes.add(clean);
        }
      }
      if (codes.isNotEmpty) {
        setState(() {
          _tempUser = codes[0];
          _tempPass = codes.length > 1 ? codes[1] : codes[0];
          _isScanning = false;
        });
      } else {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("لم يتم العثور على كود واضع")));
      }
    } catch (e) { setState(() => _isScanning = false); }
  }

  Future<void> _smartLogin(WifiCard card) async {
    try {
      var init = await http.get(Uri.parse("http://connectivitycheck.gstatic.com/generate_204")).timeout(Duration(seconds: 4));
      String url = init.headers['location'] ?? "http://10.0.0.1/login";
      var res = await http.post(Uri.parse(url), body: {'username': card.user, 'password': card.pass}).timeout(Duration(seconds: 10));

      if (res.body.contains("expired") || res.body.contains("finished") || res.body.contains("انتهى")) {
        setState(() { card.status = 'expired'; card.expiryTime = DateTime.now(); });
      } else {
        for (var c in _wallet) if (c.status == 'active') c.status = 'new';
        setState(() => card.status = 'active');
      }
      _saveWallet();
    } catch (e) { 
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تأكد من اتصالك بالشبكة")));
    }
  }

  void _addToWallet({bool loginImmediately = false}) {
    final newCard = WifiCard(user: _tempUser, pass: _tempPass);
    setState(() {
      _wallet.add(newCard);
      _tempUser = "";
      _tempPass = "";
    });
    if (loginImmediately) _smartLogin(newCard);
    _saveWallet();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text("Gaza Scanner"),
        actions: [
          IconButton(icon: Icon(Icons.account_balance_wallet, color: Colors.cyan), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletPage(wallet: _wallet, onLogin: _smartLogin, onUpdate: _saveWallet)))),
          IconButton(icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.yellow), onPressed: () => _setFlash(!_isFlashOn))
        ],
      ),
      body: Stack(
        children: [
          // خلفية الكاميرا
          Column(
            children: [
              Expanded(
                child: FutureBuilder(
                  future: _initializeControllerFuture,
                  builder: (context, snap) => (snap.connectionState == ConnectionState.done) 
                    ? CameraPreview(_controller!) : Center(child: CircularProgressIndicator()),
                ),
              ),
              Container(
                height: 120,
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_tempUser.isEmpty) GestureDetector(
                        onTap: _takePicture,
                        child: Container(height: 70, width: 70, decoration: BoxDecoration(color: Colors.cyan, shape: BoxShape.circle), child: Icon(Icons.camera_alt, color: Colors.black, size: 35)),
                      ),
                      SizedBox(height: 8),
                      Text("Powered by Sohail Shehada", style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                ),
              )
            ],
          ),
          // إطار التركيز
          if (_tempUser.isEmpty) Center(child: Container(width: size.width*0.75, height: 180, decoration: BoxDecoration(border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2), borderRadius: BorderRadius.circular(15)))),
          
          // واجهة الأزرار عند اكتشاف كود
          if (_tempUser.isNotEmpty) Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("تم اكتشاف كود: $_tempUser", style: TextStyle(fontSize: 22, color: Colors.cyan, fontWeight: FontWeight.bold)),
                  SizedBox(height: 30),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    ElevatedButton.icon(icon: Icon(Icons.login), label: Text("دخول وحفظ"), onPressed: () => _addToWallet(loginImmediately: true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15))),
                    ElevatedButton.icon(icon: Icon(Icons.save), label: Text("حفظ فقط"), onPressed: () => _addToWallet(), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15))),
                  ]),
                  TextButton(onPressed: () => setState(()=> _tempUser = ""), child: Text("إلغاء", style: TextStyle(color: Colors.white70)))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- صفحة المحفظة المنفصلة ---
class WalletPage extends StatefulWidget {
  final List<WifiCard> wallet;
  final Function(WifiCard) onLogin;
  final Function onUpdate;
  WalletPage({required this.wallet, required this.onLogin, required this.onUpdate});

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("محفظة البطاقات")),
      body: widget.wallet.isEmpty 
        ? Center(child: Text("المحفظة فارغة، قم بتصوير كروت أولاً"))
        : ListView.builder(
            itemCount: widget.wallet.length,
            itemBuilder: (context, index) {
              final card = widget.wallet[index];
              Color cardColor = card.status == 'active' ? Colors.green : (card.status == 'expired' ? Colors.red : Colors.blue);
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: cardColor.withOpacity(0.15),
                shape: RoundedRectangleBorder(side: BorderSide(color: cardColor), borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text("كود: ${card.user}", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(card.status == 'active' ? "متصل حالياً 🟢" : (card.status == 'expired' ? "منتهية الصلاحية 🔴" : "بطاقة جديدة 🔵")),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (card.status != 'expired') IconButton(icon: Icon(Icons.login, color: Colors.white), onPressed: () { widget.onLogin(card); setState(() {}); }),
                    IconButton(icon: Icon(Icons.info_outline), onPressed: () {
                      showDialog(context: context, builder: (c) => AlertDialog(title: Text("تفاصيل البطاقة"), content: Text("اسم المستخدم: ${card.user}\nكلمة المرور: ${card.pass}"), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: Text("إغلاق"))]));
                    }),
                    if (card.status == 'active') IconButton(icon: Icon(Icons.logout, color: Colors.orange), onPressed: () { setState(() => card.status = 'new'); widget.onUpdate(); }),
                    IconButton(icon: Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () { setState(() => widget.wallet.removeAt(index)); widget.onUpdate(); }),
                  ]),
                ),
              );
            },
          ),
    );
  }
}
