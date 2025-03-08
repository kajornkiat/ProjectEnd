import 'package:flutter/material.dart';
import 'control_users.dart';
import 'chat.dart';
import 'profile_admin.dart';
import 'widgets/tourist_admin.dart';
import 'widgets/hotel_admin.dart';
import 'widgets/food_admin.dart';
import 'widgets/feeds_admin.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeAdminPage extends StatefulWidget {
  final int userId;
  HomeAdminPage({required this.userId, Key? key}) : super(key: key);

  @override
  _HomeAdminPageState createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  int _currentIndex = 0;
  String profileImageUrl = '';
  Map<String, dynamic>? userData;
  int friendRequestsCount = 0; // จำนวนคำขอเป็นเพื่อน
  final PageController _pageController = PageController();

  List<Widget> get _pages {
    if (userData == null) {
      return [
        const Center(child: CircularProgressIndicator()), // Loading
      ];
    }
    return [
      HomePageContent(userData: userData!),
      ControlUsersPage(
        currentUserId: widget.userId,
        onRequestCountChange: (count) {
          setState(() {
            friendRequestsCount = count;
          });
        },
      ),
      ChatPage(currentUserId: widget.userId),
      ProfileAdminPage(userId: widget.userId),
    ];
  }

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    fetchFriendRequestsCount();
  }

  Future<void> fetchFriendRequestsCount() async {
    try {
      final response = await http.get(Uri.parse(
          'http://192.168.242.162:3000/api/friends/requests?receiver_id=${widget.userId}'));

      if (response.statusCode == 200) {
        List<dynamic> requests = json.decode(response.body);
        setState(() {
          friendRequestsCount = requests.length;
        });
      }
    } catch (e) {
      print("Error fetching friend requests: $e");
    }
  }

  Future<void> fetchUserProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('Token not found');
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.242.162:3000/profile/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          profileImageUrl =
              data['profile_image'] != null && data['profile_image'].isNotEmpty
                  ? 'http://192.168.242.162:3000${data['profile_image']}'
                  : 'assets/images/9669.jpg';
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
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/signup.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (index == 3) {
                // เมื่อสลับไปหน้า ProfilePage
                _pages[3] = ProfileAdminPage(userId: widget.userId);
              }
            },
            children: _pages,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // เปลี่ยนหน้าเหมือนไอคอนอื่น
            _pageController.jumpToPage(index);
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Center(
              // ใช้ Center เพื่อจัดตำแหน่งไอคอนให้อยู่กึ่งกลาง
              child: Icon(
                Icons.home, // ใช้ไอคอน home จาก Material Icons
                color: Color.fromARGB(
                    255, 158, 154, 91), // สีครีม (สีสามารถปรับได้ตามต้องการ)
                size: 30, // ปรับขนาดไอคอนตามต้องการ
              ),
            ),
            label: '', // ไม่แสดงข้อความ
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(
                  Icons.person_add, // ใช้ไอคอน person_add จาก Material Icons
                  color: Color.fromARGB(
                      255, 158, 154, 91), // สีครีม (สีสามารถปรับได้ตามต้องการ)
                  size: 30, // ปรับขนาดไอคอนตามต้องการ
                ),
                if (friendRequestsCount > 0) // 🔹 แสดง Badge ถ้ามีคำขอ
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$friendRequestsCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: "Add Friends",
          ),
          BottomNavigationBarItem(
            icon: Center(
              // ใช้ Center เพื่อจัดตำแหน่งไอคอนให้อยู่กึ่งกลาง
              child: Icon(
                Icons.chat_bubble_outline, // ใช้ไอคอน home จาก Material Icons
                color: Color.fromARGB(
                    255, 158, 154, 91), // สีครีม (สีสามารถปรับได้ตามต้องการ)
                size: 30, // ปรับขนาดไอคอนตามต้องการ
              ),
            ),
            label: '', // ไม่แสดงข้อความ
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
                        // หากโหลดรูปไม่สำเร็จ ให้แสดงไอคอน person
                        return Icon(
                          Icons.person,
                          size: 30,
                          color: Color.fromARGB(255, 158, 154, 91),
                        );
                      },
                    )
                  : Icon(
                      Icons.person, // ใช้ไอคอน person จาก Material Icons
                      size: 30, // ปรับขนาดไอคอนตามต้องการ
                      color: Color.fromARGB(255, 158, 154, 91), // สีไอคอน
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
  const HomePageContent({required this.userData, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                    offset: const Offset(0, 3),
                  ),
                ],
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                FeedsAdmin(userData: userData),
                TouristAdmin(),
                HotelAdmin(),
                FoodAdmin(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
