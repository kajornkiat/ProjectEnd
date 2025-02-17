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

  Widget buildFriendButton() {
    if (friendStatus == 'loading') {
      return const CircularProgressIndicator(); // โหลดสถานะเพื่อน
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
          // 🔹 ปุ่ม "Friend" มีพื้นหลังสีฟ้า
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 206, 206, 206),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: Color.fromARGB(255, 14, 230, 72)),
                const SizedBox(width: 5),
                const Text(
                  "Friend",
                  style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(width: 1), // 🔹 เว้นระยะห่างระหว่างปุ่มและไอคอนแชท

          // 🔹 ปุ่มแชทอยู่นอก Container
          IconButton(
            icon:
                const Icon(Icons.chat, color: Color.fromARGB(255, 24, 24, 24)),
            onPressed: () {
              String imageUrl = widget.profileImageUrl ?? '';

              // ตรวจสอบว่า URL มี 'http' หรือไม่
              if (!imageUrl.startsWith('http')) {
                imageUrl = 'http://10.39.5.2:3000$imageUrl';
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailPage(
                    currentUserId: widget.currentUserId,
                    friendId: widget.userId,
                    name: widget.fullname,
                    avatar: imageUrl, // ใช้ URL ที่ตรวจสอบแล้ว
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
          backgroundColor: Colors.blue, // 🔹 เปลี่ยนเป็นสีน้ำเงิน
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 🔹 ทำให้โค้งมน
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: const Text(
          "Add Friend",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold), // 🔹 เปลี่ยนข้อความเป็นสีขาว
        ),
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
