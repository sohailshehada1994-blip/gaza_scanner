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

Future<User?> signInWithGoogle() async {
    try {
      // 1. فتح نافذة اختيار الحساب
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 2. طلب البيانات الأساسية فقط
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. الربط مع فايربيس (هنا السر: نستخدم الـ Tokens مباشرة)
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. تسجيل الدخول
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      return userCredential.user;
    } catch (e) {
      // إذا فشل، اطبع الخطأ عشان نعرفه من الـ Logcat
      print("Error during Google Sign-In: $e");
      return null;
    }
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
