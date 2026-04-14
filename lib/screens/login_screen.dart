import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService(); 
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // جعلنا الخلفية سوداء لتناسب الثيم الداكن (Dark Theme)
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.blue)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // أيقونة الحماية والأمان
                  const Icon(Icons.shield_outlined, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  
                  // النص اللي اتفقنا عليه
                  const Text(
                    "سجل دخولك لحماية بياناتك",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "التسجيل عبر جوجل يحفظ نسخة من محفظتك في السحاب بشكل آمن",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),

                  // زر تسجيل الدخول بجوجل
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      User? user = await _authService.signInWithGoogle(context);
                      setState(() => _isLoading = false);
                      
                      if (user != null) {
                        // إذا نجح التسجيل، نعود للشاشة الرئيسية
                        Navigator.pop(context); 
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("✅ تم تسجيل الدخول بنجاح")),
                        );
                      }
                    },
                    icon: const Icon(Icons.login, color: Colors.red),
                    label: const Text("متابعة باستخدام Google"),
                  ),

                  const SizedBox(height: 20),

                  // زر التخطي (الدخول كضيف)
                  TextButton(
                    onPressed: () {
                      // العودة للرئيسية دون تسجيل
                      Navigator.pop(context); 
                    },
                    child: const Text(
                      "تخطي والدخول كضيف",
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
