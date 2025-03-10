import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatDetailPage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'profile.dart';

late IO.Socket socket;

class FriendProfilePage extends StatefulWidget {
  final int userId;
  final int currentUserId;
  final String fullname;
  final String profileImageUrl;
  final String backgroundImageUrl;
  final String status;
  //final String friend_status;

  const FriendProfilePage({
    required this.userId,
    required this.currentUserId,
    required this.fullname,
    required this.profileImageUrl,
    required this.backgroundImageUrl,
    required this.status,
    //required this.friend_status,
    super.key,
  });

  @override
  _FriendProfilePageState createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  String friendStatus = 'loading'; // เริ่มต้นเป็น 'loading'
  List<dynamic> posts = [];
  Map<int, TextEditingController> commentControllers = {};
  Map<int, List<Map<String, dynamic>>> postComments = {};
  TextEditingController postController = TextEditingController();
  int? userId; // เก็บ user_id ที่ดึงมาจาก SharedPreferences
  String currentUserProfileImage = '';
  Map<int, bool> _isExpandedMap = {};

  // ฟังก์ชันตรวจสอบว่าข้อความจำเป็นต้องขยายหรือไม่
  bool _needsExpansion(String text, BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 16),
      ),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 32);
    return textPainter.didExceedMaxLines;
  }

  @override
  void initState() {
    super.initState();
    checkFriendStatus();
    getCurrentUserId().then((_) {
      fetchPosts(); // เรียก fetchPosts หลังจาก userId ถูกตั้งค่า
      fetchCurrentUserProfileImage();
    });
    initSocket();
  }

  @override
  void initSocket() {
    socket = IO.io('http://192.168.242.162:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.on('new_comment', (data) {
      if (!mounted) return; // ✅ ป้องกัน error
      int postId = data['post_id'];
      Map<String, dynamic> newComment = data['comment'];

      if (postComments.containsKey(postId)) {
        postComments[postId]!.add(newComment);
      } else {
        postComments[postId] = [newComment];
      }
      setState(() {}); // ✅ เช็คแล้วว่า mounted
    });

    socket.on('delete_comment', (data) {
      int postId = data['post_id'];
      int commentId = data['comment_id'];
      if (postComments.containsKey(postId)) {
        postComments[postId]!.removeWhere((c) => c['comment_id'] == commentId);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    postController.dispose();
    // ✅ ยกเลิก Event Listener ของ socket
    socket.off('delete_post');
    socket.off('new_comment');
    socket.off('delete_comment');
    commentControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // เพิ่มฟังก์ชันสำหรับดึงรูปโปรไฟล์ของผู้ใช้ที่ login
  Future<void> fetchCurrentUserProfileImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('http://192.168.242.162:3000/profile/${widget.currentUserId}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        currentUserProfileImage = data['profile_image'] != null
            ? 'http://192.168.242.162:3000${data['profile_image']}'
            : '';
      });
    } else {
      print('Failed to load current user profile image');
    }
  }

  Future<void> checkFriendStatus() async {
    try {
      final response = await http.get(Uri.parse(
          'http://192.168.242.162:3000/api/friends/friend_status?user_id=${widget.currentUserId}&friend_id=${widget.userId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ตรวจสอบ userstatus จาก widget.status
        final userStatus = widget.status; // 'user' หรือ 'admin'

        // ตรวจสอบ friendstatus จาก API
        final friendStatusFromAPI =
            data['status']; // 'pending', 'accepted', หรือ 'not_friends'

        // อัปเดต friendStatus ใน state
        setState(() {
          friendStatus = friendStatusFromAPI;
        });

        // แสดงผลลัพธ์ใน console (สำหรับ debugging)
        print("User Status: $userStatus");
        print("Friend Status: $friendStatusFromAPI");
      } else {
        throw Exception("Failed to load friend status");
      }
    } catch (e) {
      setState(() {
        friendStatus = 'error'; // แสดงข้อผิดพลาดหากเกิดปัญหา
      });
      print("Error checking friend status: $e");
    }
  }

  Future<void> sendFriendRequest() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.242.162:3000/api/friends/request'),
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
        Uri.parse('http://192.168.242.162:3000/api/friends/delete'),
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
      return const CircularProgressIndicator(); // แสดง Loading
    } else if (widget.status == 'admin') {
      // ถ้าเป็น admin ให้แสดงไอคอนแชทโดยไม่ต้องกด "Add Friend"
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // แสดงสถานะ "Admin"
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
                    color: Colors.blue), // ไอคอนสีฟ้า
                const SizedBox(width: 5),
                const Text(
                  "Admin", // แสดงข้อความ "Admin"
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // ปุ่มแชท
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.black),
            onPressed: () {
              String imageUrl = widget.profileImageUrl.isNotEmpty
                  ? widget.profileImageUrl
                  : '';

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
    } else if (friendStatus == 'pending') {
      // ถ้า friendStatus เป็น pending
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        child: const Text("Pending"),
      );
    } else if (friendStatus == 'accepted') {
      // ถ้า friendStatus เป็น accepted (เป็นเพื่อนแล้ว)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // แสดงสถานะ "Friend"
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

          // ไอคอนจุดไข่ปลา (เมนู)
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

          // ปุ่มแชท
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.black),
            onPressed: () {
              String imageUrl = widget.profileImageUrl.isNotEmpty
                  ? widget.profileImageUrl
                  : '';

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
      // แสดงข้อผิดพลาด
      return const Text("Error loading friend status",
          style: TextStyle(color: Colors.red));
    } else {
      // ถ้า friendStatus เป็น not_friends (ยังไม่ได้เป็นเพื่อน)
      return ElevatedButton(
        onPressed: sendFriendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          "Add Friend",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  // ดึง userId จาก SharedPreferences
  Future<void> getCurrentUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('user_id') ?? 0; // ป้องกัน null
      print("User ID: $userId");
    });

    // เรียก fetchPosts ทันทีหลังจากได้ userId
    if (userId != 0) {
      fetchPosts();
    } else {
      print("User ID is null or invalid.");
    }
  }

  // ดึงโพสต์เฉพาะของผู้ใช้
  Future<void> fetchPosts() async {
    if (widget.userId == null || widget.userId == 0) {
      print("User ID is null or invalid");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print("Token is null");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            'http://192.168.242.162:3000/api/posts?user_id=${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print("API Response: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = json.decode(response.body);
        setState(() {
          posts = fetchedPosts;
        });
        print("Posts updated: $posts");
      } else {
        print(
            "Error fetching posts: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('user_id');
    });
  }

  Future<void> fetchComments(int postId) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.242.162:3000/api/comments/$postId'),
      );

      if (response.statusCode == 200) {
        final comments = jsonDecode(response.body);

        setState(() {
          postComments[postId] = List<Map<String, dynamic>>.from(comments);
        });

        print("Updated comments: ${postComments[postId]}"); // ✅ Debugging
      }
    } catch (e) {
      print("Error fetching comments: $e");
    }
  }

  // ฟังก์ชันสำหรับคอมเมนต์
  Future<void> addComment(int postId, Function updateState) async {
    if (!commentControllers.containsKey(postId)) {
      commentControllers[postId] = TextEditingController();
    }

    if (commentControllers[postId]!.text.isEmpty) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.post(
      Uri.parse("http://192.168.242.162:3000/api/comments"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'post_id': postId,
        'comment': commentControllers[postId]!.text,
      }),
    );

    if (response.statusCode == 201) {
      commentControllers[postId]!.clear();
      await fetchComments(postId);

      // ✅ อัปเดตจำนวนคอมเมนต์แบบ realtime
      setState(() {
        posts.firstWhere(
            (post) => post['post_id'] == postId)['comment_count'] += 1;
      });

      updateState(() {}); // ✅ อัปเดต UI popup
    }
  }

  // ฟังก์ชันสำหรับลบคอมเมนต์
  Future<void> deleteComment(
      int postId, int commentId, Function updateState) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse("http://192.168.242.162:3000/api/comments/$commentId"),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      await fetchComments(postId);

      // ✅ อัปเดตจำนวนคอมเมนต์แบบ realtime
      setState(() {
        posts.firstWhere(
            (post) => post['post_id'] == postId)['comment_count'] -= 1;
      });

      updateState(() {}); // ✅ อัปเดต UI popup
    }
  }

  Future<void> showCommentPopup(int postId) async {
    await fetchComments(postId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 400,
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: postComments[postId]?.length ?? 0,
                        itemBuilder: (context, index) {
                          final comment = postComments[postId]![index];
                          return ListTile(
                            leading: GestureDetector(
                              onTap: () {
                                navigateToProfileOrFriendProfile(
                                  comment['user_id'],
                                  comment['fullname'] ?? 'Unknown User',
                                  comment['profile_image'] != null
                                      ? 'http://192.168.242.162:3000${comment['profile_image']}'
                                      : '',
                                  comment['background_image'] != null
                                      ? 'http://192.168.242.162:3000${comment['background_image']}'
                                      : '',
                                  comment['status'], // ใส่ status หากมี
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage: comment['profile_image'] !=
                                        null
                                    ? NetworkImage(
                                        'http://192.168.242.162:3000${comment['profile_image']}')
                                    : AssetImage(
                                            'assets/images/default_profile.png')
                                        as ImageProvider,
                              ),
                            ),
                            title: GestureDetector(
                              onTap: () {
                                navigateToProfileOrFriendProfile(
                                  comment['user_id'],
                                  comment['fullname'] ?? 'Unknown User',
                                  comment['profile_image'] != null
                                      ? 'http://192.168.242.162:3000${comment['profile_image']}'
                                      : '',
                                  comment['background_image'] != null
                                      ? 'http://192.168.242.162:3000${comment['background_image']}'
                                      : '',
                                  comment['status'],
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment['fullname'] ?? 'Unknown User',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  // ✅ เพิ่ม Text เพื่อแสดงวันที่
                                  if (comment['date'] != null)
                                    Text(
                                      _formatDate(
                                          comment['date']), // จัดรูปแบบวันที่
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            subtitle: Text(comment['comment']),
                            trailing: comment['user_id'] ==
                                    userId // ✅ แสดงจุดไข่ปลาเฉพาะคอมเมนต์ของตนเอง
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == "delete") {
                                        deleteComment(
                                            postId,
                                            comment['comment_id'],
                                            setModalState);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: "delete",
                                        child: Text("Delete",
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                      PopupMenuItem(
                                        value: "cancel",
                                        child: Text("Cancel"),
                                      ),
                                    ],
                                  )
                                : null, // 🔹 ถ้าไม่ใช่เจ้าของคอมเมนต์ จะไม่แสดงปุ่ม
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentControllers[postId],
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send),
                            onPressed: () => addComment(postId, setModalState),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void navigateToProfileOrFriendProfile(int postUserId, String fullname,
      String profileImageUrl, String backgroundImageUrl, String status) {
    if (postUserId == userId) {
      // ถ้าเป็นผู้ใช้ที่ล็อกอินอยู่ ให้ไปหน้า profile.dart
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(userId: userId!),
        ),
      );
    } else {
      // ถ้าไม่ใช่ผู้ใช้ที่ล็อกอินอยู่ ให้ไปหน้า friendprofile.dart
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendProfilePage(
            userId: postUserId,
            currentUserId: userId!,
            fullname: fullname,
            profileImageUrl: profileImageUrl,
            backgroundImageUrl: backgroundImageUrl,
            status: status,
          ),
        ),
      );
    }
  }

  Widget _buildPostImages(List<String> images) {
    return images.isEmpty
        ? SizedBox.shrink()
        : SizedBox(
            height: 260,
            child: PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, index) {
                return AspectRatio(
                  aspectRatio: 1, // อัตราส่วน 1:1 (ปรับตามต้องการ)
                  child: Image.network(
                    'http://192.168.242.162:3000/posts/${images[index]}',
                    fit: BoxFit.cover, // ปรับขนาดรูปให้พอดีกับกรอบ
                  ),
                );
              },
            ),
          );
  }

  // ฟังก์ชันสำหรับแสดงโพสต์
  Widget buildPosts() {
    if (posts.isEmpty) {
      return Center(
        child: Text("No posts available"), // แสดงข้อความเมื่อไม่มีโพสต์
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        var post = posts[index];
        final postId = post['post_id'];
        final description = post['description'] ?? '';
        // กำหนดค่าเริ่มต้นสำหรับ _isExpandedMap หากยังไม่มี
        _isExpandedMap[postId] ??= false;
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: const Color.fromARGB(255, 255, 255, 255),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: GestureDetector(
                  onTap: () {
                    navigateToProfileOrFriendProfile(
                      post['user_id'],
                      post['fullname'] ?? 'Unknown User',
                      post['profile_image'] != null
                          ? 'http://192.168.242.162:3000${post['profile_image']}'
                          : '',
                      post['background_image'] != null
                          ? 'http://192.168.242.162:3000${post['background_image']}'
                          : '',
                      post['status'], // ใส่ status หากมี
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: post['profile_image'] != null
                        ? NetworkImage(
                            'http://192.168.242.162:3000${post['profile_image']}')
                        : AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                  ),
                ),
                title: GestureDetector(
                  onTap: () {
                    navigateToProfileOrFriendProfile(
                      post['user_id'],
                      post['fullname'] ?? 'Unknown User',
                      post['profile_image'] != null
                          ? 'http://192.168.242.162:3000${post['profile_image']}'
                          : '',
                      post['background_image'] != null
                          ? 'http://192.168.242.162:3000${post['background_image']}'
                          : '',
                      post['status'], // ใส่ status หากมี
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['fullname'] ?? 'Unknown User',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      // ✅ เพิ่ม Text เพื่อแสดงวันที่
                      if (post['date'] != null)
                        Text(
                          _formatDate(post['date']), // จัดรูปแบบวันที่
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (post['images'] != null && post['images'].isNotEmpty)
                _buildPostImages(post['images']
                    .cast<String>()), // แปลง List<dynamic> เป็น List<String>
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Color.fromARGB(255, 248, 30, 26),
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          post['province'] ??
                              'Unknown Province', // ✅ แสดง province
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 26, 141, 248),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5), // ✅ เว้นระยะห่าง
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpandedMap[postId] = !_isExpandedMap[postId]!;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 16, // ปรับขนาดฟอนต์
                              color: const Color.fromARGB(
                                  255, 87, 87, 87), // ปรับสีข้อความ
                              height: 1.5, // ปรับความสูงระหว่างบรรทัด
                            ),
                            maxLines: _isExpandedMap[postId]! ? null : 3,
                            overflow: _isExpandedMap[postId]!
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          if (!_isExpandedMap[postId]! &&
                              _needsExpansion(description, context))
                            Text(
                              'เพิ่มเติม...',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 115, 178, 230),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (_isExpandedMap[postId]!)
                            Text(
                              'แสดงน้อยลง',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 115, 178, 230),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    // รูปโปรไฟล์แสดงทางซ้าย
                    CircleAvatar(
                      backgroundImage: currentUserProfileImage.isNotEmpty
                          ? NetworkImage(
                              currentUserProfileImage) // หากมีรูปจาก URL
                          : AssetImage('assets/images/default_profile.png')
                              as ImageProvider, // หากไม่มีรูป
                      radius: 15,
                    ),
                    SizedBox(width: 8),
                    // ช่องป้อนคอมเมนต์ กดแล้วแสดง showCommentPopup
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showCommentPopup(post['post_id']),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Leave a comment",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                    // ไอคอน Like, Comment และ Refresh
                    IconButton(
                      icon: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: Colors.black, size: 32),
                          if (post['comment_count'] != null &&
                              post['comment_count'] > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints:
                                    BoxConstraints(minWidth: 22, minHeight: 22),
                                child: Center(
                                  child: Text(
                                    '${post['comment_count']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () => showCommentPopup(post['post_id']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      // แปลง string เป็น DateTime object
      DateTime dateTime = DateTime.parse(dateString);

      // จัดรูปแบบวันที่ให้อ่านง่ายขึ้น
      String formattedDate =
          "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";

      return formattedDate;
    } catch (e) {
      print("Error formatting date: $e");
      return dateString; // หากไม่สามารถจัดรูปแบบได้ ให้คืนค่าเดิม
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
                            image: AssetImage(
                                'assets/images/default_background.png'),
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
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 50), // เว้นขอบซ้าย-ขวา 16px
              child: Text(
                widget.fullname,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 10),
            buildFriendButton(),
            buildPosts(), // แสดงโพสต์ของผู้ใช้
          ],
        ),
      ),
    );
  }
}
