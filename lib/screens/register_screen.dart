import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _companyController = TextEditingController();
  String _gender = '남';

  Future<void> _register() async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 사용자 추가 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'gender': _gender,
        'company': _companyController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("회원가입 실패: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "이메일")),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "비밀번호"), obscureText: true),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "이름")),
            TextField(controller: _ageController, decoration: const InputDecoration(labelText: "나이"), keyboardType: TextInputType.number),
            DropdownButton<String>(
              value: _gender,
              onChanged: (value) => setState(() => _gender = value!),
              items: ['남', '여'].map((label) => DropdownMenuItem(child: Text(label), value: label)).toList(),
            ),
            TextField(controller: _companyController, decoration: const InputDecoration(labelText: "소속 회사")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _register, child: const Text("회원가입")),
          ],
        ),
      ),
    );
  }
}
