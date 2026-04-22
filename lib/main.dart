import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.green),
    home: AdminAddProduct(),
  ));
}

class AdminAddProduct extends StatefulWidget {
  @override
  _AdminAddProductState createState() => _AdminAddProductState();
}

class _AdminAddProductState extends State<AdminAddProduct> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void addProduct() {
    if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
      FirebaseFirestore.instance.collection('products').add({
        'name': nameController.text,
        'price': priceController.text,
        'timestamp': FieldValue.serverTimestamp(),
      }).then((value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تمت إضافة السلعة بنجاح!")),
        );
        nameController.clear();
        priceController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text("لوحة المسؤول - إضافة منتجات")),
        body: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "اسم المنتج", border: OutlineInputBorder()),
              ),
              SizedBox(height: 15),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: "السعر (شيكل مثلاً)", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: addProduct,
                child: Text("حفظ المنتج في المتجر"),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
