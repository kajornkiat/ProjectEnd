import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatDetailPage.dart';

class FriendProfilePage extends StatefulWidget {
  final int userId;
  final int currentUserId;
  final String fullname;
  final String profileImageUrl;
  final String backgroundImageUrl;

  const FriendProfilePage({
    required this.userId,
    required this.currentUserId,
    required this.fullname,
    required this.profileImageUrl,
    required this.backgroundImageUrl,
    super.key,
  });

  @override
  _FriendProfilePageState createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  String friendStatus = 'loading'; // เริ่มต้นเป็น 'loading'

  @override
  void initState() {
    super.initState();
    checkFriendStatus();
  }

  Future<void> checkFriendStatus() async {
    try {
      final response = await http.get(Uri.parse(
          'http://10.39.5.2:3000/api/friends/status?user_id=${widget.currentUserId}&friend_id=${widget.userId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          friendStatus = data['status'];
        });
      } else {
        throw Exception("Failed to load friend status");
      }
    } catch (e) {
      setState(() {
        friendStatus = 'error';
      });
      print("Error checking friend status: $e");
    }
  }

  Future<void> sendFriendRequest() async {
    try {
      final response = await http.post(
        Uri.parse('http://10.39.5.2:3000/api/friends/request'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sender_id": widget.currentUserId,
          "receiver_id": widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          friendStatus = 'pending';
        });
      } else {
        throw Exception("Failed to send friend request");
      }
    } catch (e) {
      print("Error sending friend request: $e");
    }
  }

  Future<void> deleteFriend() async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.39.5.2:3000/api/friends/delete'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.currentUserId,
          "friend_id": widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          friendStatus = 'not_friends'; // เปลี่ยนสถานะให้กลับเป็น "Add Friend"
        });
      } else {
        throw Exception("Failed to delete friend");
      }
    } catch (e) {
      print("Error deleting friend: $e");
    }
  }

  Widget buildFriendButton() {
    if (friendStatus == 'loading') {
      return const CircularProgressIndicator();
    } else if (friendStatus == 'pending') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        child: const Text("Pending"),
      );
    } else if (friendStatus == 'accepted') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🔹 ปุ่ม "Friend"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 206, 206, 206),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 5),
                const Text(
                  "Friend",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 🔹 ไอคอนจุดไข่ปลา (เมนู)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (String choice) {
              if (choice == 'delete') {
                deleteFriend(); // เรียกฟังก์ชันลบเพื่อน
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text("Delete Friend"),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: Text("Cancel"),
              ),
            ],
          ),

          // 🔹 ปุ่มแชท
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.black),
            onPressed: () {
              String imageUrl = widget.profileImageUrl.isNotEmpty
                  ? widget.profileImageUrl
                  : 'http://10.39.5.2:3000/default_profile.png';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailPage(
                    currentUserId: widget.currentUserId,
                    friendId: widget.userId,
                    name: widget.fullname,
                    avatar: imageUrl,
                  ),
                ),
              );
            },
          ),
        ],
      );
    } else if (friendStatus == 'error') {
      return const Text("Error loading friend status",
          style: TextStyle(color: Colors.red));
    } else {
      return ElevatedButton(
        onPressed: sendFriendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: const Text("Add Friend",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 🔹 ตรวจสอบว่ามีรูปพื้นหลังหรือไม่
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    image: widget.backgroundImageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(widget.backgroundImageUrl),
                            fit: BoxFit.cover,
                          )
                        : const DecorationImage(
                            image: AssetImage('assets/images/default_bg.jpg'),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black, size: 30),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                Positioned(
                  top: 100,
                  left: MediaQuery.of(context).size.width / 2 - 80,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: widget.profileImageUrl.isNotEmpty
                        ? NetworkImage(widget.profileImageUrl)
                        : const AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 65),
            Text(
              widget.fullname,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            buildFriendButton(),
          ],
        ),
      ),
    );
  }
}
