import 'package:flutter/material.dart';
import 'add_friends.dart';
import 'chat.dart';
import 'profile.dart';
import 'widgets/tourist.dart';
import 'widgets/hotel.dart';
import 'widgets/food.dart';
import 'widgets/feeds.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final int userId;
  HomePage({required this.userId});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String profileImageUrl = 'assets/images/9669.jpg'; // รูปเริ่มต้น
  Map<String, dynamic>? userData; // ✅ เก็บข้อมูล userData

  List<Widget> get _pages {
    if (userData == null) {
      return [
        Center(child: CircularProgressIndicator()), // แสดง Loading ก่อน
      ];
    }
    return [
      HomePageContent(userData: userData!), // ✅ ส่ง userData (ไม่ใช่ userId)
      AddFriendsPage(),
      ChatPage(),
      ProfilePage(userId: widget.userId),
    ];
  }

  @override
  void initState() {
    super.initState();
    fetchUserProfile(); // ดึงข้อมูลผู้ใช้เมื่อหน้า Home ถูกสร้าง
  }

  Future<void> fetchUserProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // ดึง token จาก SharedPreferences

      if (token == null) {
        print('Token not found');
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.242.188:3000/profile/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token', // ใช้ token จริง
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data; // ✅ เก็บข้อมูล userData
          profileImageUrl =
              'http://192.168.242.188:3000${data['profile_image']}' ??
                  'assets/images/9669.jpg';
        });
      } else {
        print('Failed to load profile image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // เพิ่มรูปพื้นหลัง
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/signup.png'), // ใส่ path ของรูปพื้นหลัง
                fit: BoxFit.cover, // ทำให้รูปภาพครอบคลุมทั้งหน้าจอ
              ),
            ),
          ),
          // เนื้อหาของหน้า HomePage
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // เปลี่ยนหน้าเมื่อกด
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: ClipOval(
              child: Image.asset(
                'assets/images/home.png',
                width: 25,
                height: 25,
                fit: BoxFit.cover,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: ClipOval(
              child: Image.asset(
                'assets/images/add_friends.png',
                width: 25,
                height: 25,
                fit: BoxFit.cover,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: ClipOval(
              child: Image.asset(
                'assets/images/chat.png',
                width: 25,
                height: 25,
                fit: BoxFit.cover,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: ClipOval(
              child: profileImageUrl.startsWith('http')
                  ? Image.network(
                      profileImageUrl,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/9669.jpg',
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      profileImageUrl,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}

class HomePageContent extends StatelessWidget {
  final Map<String, dynamic> userData;
  HomePageContent({required this.userData});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    Feeds(userData: userData),
                    Tourist(),
                    Hotel(),
                    Food(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
