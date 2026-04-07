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

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    User? user = await _authService.signInWithGoogle();
    if (user != null) {
      bool hasPhone = await _authService.isPhoneNumberLinked(user.uid);
      if (hasPhone) {
        // هنا سنضيف لاحقاً الانتقال للرئيسية
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم تسجيل الدخول بنجاح!")));
      } else {
        _showPhoneInputSheet(user);
      }
    }
    setState(() => _isLoading = false);
  }

  void _showPhoneInputSheet(User user) {
    final TextEditingController phoneController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("أهلاً ${user.displayName}", style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "رقم الجوال 059XXXXXXX", hintStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _authService.linkPhoneNumber(user.uid, phoneController.text, user.displayName ?? "");
                Navigator.pop(context);
              },
              child: const Text("حفظ البيانات"),
            ),
            const SizedBox(height: 20),
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
          ? const CircularProgressIndicator()
          : ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("الدخول بواسطة Google"),
              onPressed: _handleGoogleSignIn,
            ),
      ),
    );
  }
}
