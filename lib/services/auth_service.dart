import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "120266672680-rgc1dh7pvui9soogopm2lfodre13cgpn.apps.googleusercontent.com",
  );

  // تسجيل الدخول بجوجل مع إظهار تفاصيل الخطأ للتشخيص
  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } on PlatformException catch (e) {
      // إظهار كود الخطأ التقني (مثل 12500 أو 10)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ نظام (Platform): ${e.code}\n${e.message}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
      return null;
    } catch (e) {
      // إظهار تفاصيل الخطأ العام (هنا سيظهر النص الكامل للعلة)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("تفاصيل الخطأ: ${e.toString()}"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 10),
        ),
      );
      print("Full Error Log: $e");
      return null;
    }
  }

  // فحص إذا كان رقم الجوال مرتبط
  Future<bool> isPhoneNumberLinked(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data.containsKey('phoneNumber');
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ربط رقم الهاتف والاسم في Firestore
  Future<void> linkPhoneNumber(String uid, String phone, String name) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'phoneNumber': phone,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Firestore Error: $e");
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("SignOut Error: $e");
    }
  }
}
