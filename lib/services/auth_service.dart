import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // تأكد من المسار الصحيح للملف

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // دالة تسجيل الدخول بجوجل
  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    User? user = await _authService.signInWithGoogle();
    
    if (user != null) {
      // فحص هل الرقم مرتبط؟
      bool hasPhone = await _authService.isPhoneNumberLinked(user.uid);
      
      if (hasPhone) {
        // توجه للشاشة الرئيسية (سنبرمجها لاحقاً)
        print("مستخدم قديم - توجه للرئيسية");
      } else {
        // افتح نموذج طلب رقم الجوال
        _showPhoneInputSheet(user);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل تسجيل الدخول، حاول مرة أخرى")),
      );
    }
    
    setState(() => _isLoading = false);
  }

  // نموذج إدخال رقم الجوال (BottomSheet)
  void _showPhoneInputSheet(User user) {
    final TextEditingController _phoneController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF1A1A1A), // لون داكن سينمائي
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("أهلاً بك ${user.displayName}", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("يرجى إدخال رقم جوالك لتفعيل الحساب", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "059XXXXXXXX",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () async {
                if (_phoneController.text.length >= 9) {
                  await _authService.linkPhoneNumber(user.uid, _phoneController.text, user.displayName ?? "");
                  Navigator.pop(context);
                  // توجه للرئيسية
                }
              },
              child: Text("تأكيد وحفظ"),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading 
          ? CircularProgressIndicator(color: Colors.blueAccent)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // لوجو التطبيق (ممكن تحط صورة الهوية اللي صممناها)
                Icon(Icons.wifi_tethering, size: 100, color: Colors.blueAccent),
                SizedBox(height: 30),
                Text("Gaza Scanner", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text("نظام إدارة شبكات الوايفاي الذكي", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 50),
                
                // زر الدخول بجوجل
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.login),
                    label: Text("الدخول بواسطة Google"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _handleGoogleSignIn,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
