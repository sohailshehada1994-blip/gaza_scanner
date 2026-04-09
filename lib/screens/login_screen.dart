import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // تأكد أن المجلد اسمه services

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // تعريف السرفيس هنا فقط (خارج ملف السرفيس نفسه)
  final AuthService _authService = AuthService(); 
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading 
          ? const CircularProgressIndicator()
          : ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                User? user = await _authService.signInWithGoogle(context);
                // هنا نضع المنطق الخاص بك لاحقاً
                setState(() => _isLoading = false);
              },
              child: const Text("Google Sign In"),
            ),
      ),
    );
  }
}
