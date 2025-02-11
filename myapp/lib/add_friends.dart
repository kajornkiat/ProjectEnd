import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'friendprofile.dart'; // ลิ้งค์ไปหน้าข้อมูลเพื่อน

class AddFriendsPage extends StatefulWidget {
  final int currentUserId; // รับ userId ของผู้ใช้ที่ล็อกอิน

  AddFriendsPage({required this.currentUserId});

  @override
  _AddFriendsPageState createState() => _AddFriendsPageState();
}

class _AddFriendsPageState extends State<AddFriendsPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    final url = Uri.parse(
        "http://192.168.242.248:3000/api/users/search?fullname=$query");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      setState(() {
        searchResults = results
            .where((user) => user['id'] != widget.currentUserId)
            .toList();
      });
    } else {
      print("Error fetching data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 🔹 พื้นหลังเป็นรูปภาพ
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/signup.png"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.2),
                  BlendMode.srcOver,
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + 10,
              ),
              // 🔹 ค้นหาใน AppBar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => searchUsers(value),
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Search",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.orange),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            left: 0,
            right: 0,
            bottom: 0,
            child: searchResults.isEmpty
                ? Center(
                    child: Text(
                      "Search for friends...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['profile_image'] != null
                              ? NetworkImage(
                                  'http://192.168.242.248:3000${user['profile_image']}')
                              : AssetImage('assets/images/default_profile.png')
                                  as ImageProvider,
                        ),
                        title: Text(user['fullname'],
                            style: TextStyle(
                                color: const Color.fromARGB(255, 64, 61, 61))),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FriendProfilePage(
                                userId: user['id'],
                                fullname: user['fullname'], // ส่งชื่อไป
                                profileImageUrl:
                                    'http://192.168.242.248:3000${user['profile_image']}', // ส่งรูปโปรไฟล์ไป
                                backgroundImageUrl:
                                    'http://192.168.242.248:3000${user['background_image'] ?? ''}', // ส่งรูปพื้นหลังไป
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
