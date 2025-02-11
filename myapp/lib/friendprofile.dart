import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class FriendProfilePage extends StatelessWidget {
  final int userId;
  final String fullname;
  final String profileImageUrl;
  final String backgroundImageUrl;

  const FriendProfilePage({
    required this.userId,
    required this.fullname,
    required this.profileImageUrl,
    required this.backgroundImageUrl,
    super.key,
  });

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
                // 🔹 Back Button
                Positioned(
                  top: 40, // ปรับตำแหน่ง
                  left: 16,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: const Color.fromARGB(255, 0, 0, 0), size: 30),
                    onPressed: () {
                      Navigator.pop(context); // กลับหน้าก่อนหน้า
                    },
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
              fullname,
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
