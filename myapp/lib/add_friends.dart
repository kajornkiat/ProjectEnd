import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'friendprofile.dart'; // ลิ้งค์ไปหน้าข้อมูลเพื่อน

class AddFriendsPage extends StatefulWidget {
  final int currentUserId; // รับ userId ของผู้ใช้ที่ล็อกอิน
  final Function(int) onRequestCountChange; // 🔹 Callback function

  const AddFriendsPage({
    super.key,
    required this.currentUserId,
    required this.onRequestCountChange, // 🔹 รับ callback
  });

  @override
  _AddFriendsPageState createState() => _AddFriendsPageState();
}

class _AddFriendsPageState extends State<AddFriendsPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];
  List<dynamic> friendRequests = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    fetchFriendRequests();
    searchController.addListener(() {
      setState(() {
        isSearching = searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    searchController.removeListener(() {});
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          searchResults = [];
        });
      }
      return;
    }

    final url = Uri.parse(
        "http://192.168.242.162:3000/api/users/search?fullname=$query&currentUserId=${widget.currentUserId}"); // 🔹 ส่ง currentUserId
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      if (mounted) {
        setState(() {
          searchResults = results
              .where((user) => user['id'] != widget.currentUserId)
              .toList();
        });
      }
    } else {
      print("Error fetching data");
    }
  }

  Future<void> fetchFriendRequests() async {
    final response = await http.get(Uri.parse(
        'http://192.168.242.162:3000/api/friends/requests?receiver_id=${widget.currentUserId}'));

    if (response.statusCode == 200) {
      List<dynamic> requests = json.decode(response.body);
      if (mounted) {
        setState(() {
          friendRequests = requests;
        });

        widget.onRequestCountChange(requests.length);
      }
    }
  }

  Future<void> acceptFriendRequest(int senderId) async {
    final response = await http.put(
      Uri.parse('http://192.168.242.162:3000/api/friends/accept'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sender_id": senderId,
        "receiver_id": widget.currentUserId,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        fetchFriendRequests();
      });
    }
  }

  Future<void> deleteFriendRequest(int senderId) async {
    final response = await http.delete(
      Uri.parse('http://192.168.242.162:3000/api/friends/delete'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": senderId, // เปลี่ยน sender_id เป็น user_id
        "friend_id": widget.currentUserId, // เปลี่ยน receiver_id เป็น friend_id
      }),
    );

    if (response.statusCode == 200) {
      fetchFriendRequests();
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
                image: const AssetImage("assets/images/signup.png"),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => searchUsers(value),
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: "Search",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.orange),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // 🔹 เลื่อนลงหากกำลังค้นหา
              SizedBox(height: isSearching ? 250 : 20),

              // 🔹 Title "คำขอเป็นเพื่อน" จะเลื่อนลงเมื่อพิมพ์ในช่องค้นหา
              if (!isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "คำขอเป็นเพื่อน",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // 🔹 แสดงรายการคำขอเป็นเพื่อน จะเลื่อนลงเมื่อพิมพ์ในช่องค้นหา
              if (!isSearching)
                Expanded(
                  child: friendRequests.isNotEmpty
                      ? ListView.builder(
                          itemCount: friendRequests.length,
                          itemBuilder: (context, index) {
                            final friend = friendRequests[index];

                            void navigateToFriendProfile() {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FriendProfilePage(
                                    userId: friend['id'],
                                    currentUserId: widget.currentUserId,
                                    fullname: friend['fullname'],
                                    profileImageUrl: friend['profile_image'] !=
                                                null &&
                                            friend['profile_image'].isNotEmpty
                                        ? 'http://192.168.242.162:3000${friend['profile_image']}'
                                        : '',
                                    backgroundImageUrl: friend[
                                                    'background_image'] !=
                                                null &&
                                            friend['background_image']
                                                .isNotEmpty
                                        ? 'http://192.168.242.162:3000${friend['background_image']}'
                                        : '',
                                    status: friend['status'] ?? 'user',
                                  ),
                                ),
                              );
                            }

                            return ListTile(
                              leading: GestureDetector(
                                onTap: navigateToFriendProfile,
                                child: CircleAvatar(
                                  backgroundImage: friend['profile_image'] !=
                                          null
                                      ? NetworkImage(
                                          'http://192.168.242.162:3000${friend['profile_image']}',
                                        )
                                      : const AssetImage(
                                              'assets/images/default_profile.png')
                                          as ImageProvider,
                                ),
                              ),
                              title: GestureDetector(
                                onTap: navigateToFriendProfile,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal:
                                          16.0), // เพิ่มระยะห่างด้านซ้ายและขวา
                                  child: Text(
                                    friend['fullname'],
                                    maxLines: 1, // จำกัดให้แสดงเพียง 1 บรรทัด
                                    overflow: TextOverflow
                                        .ellipsis, // แสดง ... หากข้อความยาวเกิน
                                    style: TextStyle(
                                      fontSize: 16, // ปรับขนาดฟอนต์ตามต้องการ
                                      fontWeight: FontWeight
                                          .bold, // ปรับน้ำหนักฟอนต์ตามต้องการ
                                    ),
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    onPressed: () =>
                                        acceptFriendRequest(friend['id']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () =>
                                        deleteFriendRequest(friend['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            "ไม่มีคำขอเป็นเพื่อน",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),
            ],
          ),
          // 🔹 แสดงผลลัพธ์การค้นหา
          if (isSearching)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 20,
              right: 20,
              child: Container(
                height: 600, // จำกัดความสูงของรายการที่ค้นหา
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: searchResults.isNotEmpty
                    ? ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['profile_image'] != null
                                  ? NetworkImage(
                                      'http://192.168.242.162:3000${user['profile_image']}',
                                    )
                                  : const AssetImage(
                                          'assets/images/default_profile.png')
                                      as ImageProvider,
                            ),
                            title: Text(
                              user['fullname'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow
                                  .ellipsis, // Add ellipsis if text overflows
                              maxLines: 1,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FriendProfilePage(
                                    userId: user['id'],
                                    currentUserId: widget.currentUserId,
                                    fullname: user['fullname'],
                                    profileImageUrl: user['profile_image'] !=
                                                null &&
                                            user['profile_image'].isNotEmpty
                                        ? 'http://192.168.242.162:3000${user['profile_image']}'
                                        : '',
                                    backgroundImageUrl: user[
                                                    'background_image'] !=
                                                null &&
                                            user['background_image'].isNotEmpty
                                        ? 'http://192.168.242.162:3000${user['background_image']}'
                                        : '',
                                    status: user['status'] ?? 'user',
                                    //friend_status: user['friend_status']?? "",
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          "ไม่มีชื่อผู้ใช้นี้",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
