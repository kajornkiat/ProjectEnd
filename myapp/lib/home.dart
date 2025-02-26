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
  HomePage({required this.userId, Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String profileImageUrl = 'assets/images/9669.jpg';
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
      AddFriendsPage(
        currentUserId: widget.userId,
        onRequestCountChange: (count) {
          setState(() {
            friendRequestsCount = count;
          });
        },
      ),
      ChatPage(currentUserId: widget.userId),
      ProfilePage(userId: widget.userId),
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
          'http://10.39.5.8:3000/api/friends/requests?receiver_id=${widget.userId}'));

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
        Uri.parse('http://10.39.5.8:3000/profile/${widget.userId}'),
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
                  ? 'http://10.39.5.8:3000${data['profile_image']}'
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
                _pages[3] = ProfilePage(userId: widget.userId);
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
            icon: Stack(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/add_friends.png',
                    width: 25,
                    height: 25,
                    fit: BoxFit.cover,
                  ),
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
                Feeds(userData: userData),
                Tourist(),
                Hotel(),
                Food(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
