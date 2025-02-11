import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class FriendProfilePage extends StatefulWidget {
  final int userId;
  const FriendProfilePage({required this.userId, super.key});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  String profileImageUrl = ''; // URL ของรูปโปรไฟล์
  String backgroundImageUrl = ''; // URL ของรูปพื้นหลัง
  String userName = ''; // ชื่อของผู้ใช้
  bool _isLoading = false; // สถานะการโหลด

  @override
  void initState() {
    super.initState();
    fetchImages(); // เรียกใช้ฟังก์ชันดึงข้อมูลเมื่อเริ่มต้น
  }

  // ฟังก์ชันดึงข้อมูลจาก API
  Future<void> fetchImages() async {
    setState(() {
      _isLoading = true; // ตั้งค่าการโหลด
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('http://192.168.242.248:3000/profile/${widget.userId}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print('Response: ${response.body}'); // พิมพ์ค่า response

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        profileImageUrl = 'http://192.168.242.248:3000${data['profile_image']}';
        backgroundImageUrl =
            'http://192.168.242.248:3000${data['background_image']}';
        userName = data['fullname'] ?? '';
      });
    } else {
      print('Failed to load images');
    }

    setState(() {
      _isLoading = false; // สิ้นสุดการโหลด
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section: Cover Image with Profile Picture and Settings Icon
            Stack(
              clipBehavior:
                  Clip.none, // เพื่อให้สามารถซ้อนรูปโปรไฟล์ข้างหน้าพื้นหลังได้
              children: [
                // Cover Image
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(backgroundImageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Profile Picture
                Positioned(
                  top: 100,
                  left: MediaQuery.of(context).size.width / 2 - 80,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: NetworkImage(profileImageUrl),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 65), // ปรับขนาดให้เว้นระยะห่างด้านบน
            Text(
              userName,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
