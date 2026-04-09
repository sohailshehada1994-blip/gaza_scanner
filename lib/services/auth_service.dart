import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // مهمة جداً عشان PlatformException
import 'package:get/get.dart'; // عشان نطلع الرسالة على الشاشة

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ملاحظة: تأكد إن الـ clientId هذا هو الـ Web Client ID من صفحة Google Cloud
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "120266672680-rgc1dh7pvui9soogopm2lfodre13cgpn.apps.googleusercontent.com",
  );

  // تسجيل الدخول بجوجل
  Future<User?> signInWithGoogle() async {
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
      // هاد الجزء اللي رح يحل اللغز ويطلع لك Error Code على الشاشة
      Get.defaultDialog(
        title: "كود الخطأ: ${e.code}",
        middleText: "الرسالة: ${e.message}\nالتفاصيل: ${e.details}",
        confirm: TextButton(onPressed: () => Get.back(), child: Text("تم")),
      );
      print("Google Sign-In Platform Error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      Get.snackbar("خطأ عام", e.toString());
      print("Google Sign-In General Error: $e");
      return null;
    }
  }

  // فحص رقم الجوال
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

  // ربط الرقم
  Future<void> linkPhoneNumber(String uid, String phone, String name) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'phoneNumber': phone,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Firestore Error: $e");
    }
  }
}
