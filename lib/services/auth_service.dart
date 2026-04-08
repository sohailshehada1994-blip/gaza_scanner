import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تعريف تسجيل الدخول مع إضافة الـ Scopes والـ Client ID
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "120266672680-rgc1dh7pvui9soogopm2lfodre13cgpn.apps.googleusercontent.com",
    scopes: [
      'email',
      'profile',
    ],
  );

  // تسجيل الدخول بجوجل
  Future<User?> signInWithGoogle() async {
    try {
      // 1. بدء عملية تسجيل الدخول
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("DEBUG: تم إلغاء تسجيل الدخول من قبل المستخدم");
        return null;
      }

      // 2. الحصول على تفاصيل المصادقة
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. إنشاء كcredential جديد
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. تسجيل الدخول في Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // 5. تحديث بيانات المستخدم في Firestore (إجراء وقائي)
      if (userCredential.user != null) {
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return userCredential.user;
    } catch (e) {
      // أهم سطر لمعرفة سبب المشكلة في غزة
      print("CRITICAL_ERROR Google Sign-In: $e");
      return null;
    }
  }

  // فحص رقم الجوال
  Future<bool> isPhoneNumberLinked(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data.containsKey('phoneNumber') && data['phoneNumber'] != null;
      }
      return false;
    } catch (e) {
      print("Firestore Error: $e");
      return false;
    }
  }

  // ربط الرقم
  Future<void> linkPhoneNumber(String uid, String phone, String name) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'phoneNumber': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
