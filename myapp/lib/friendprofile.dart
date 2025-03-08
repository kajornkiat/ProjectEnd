import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatDetailPage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

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
                  : 'http://192.168.242.162:3000/default_profile.png';

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
                  : 'http://192.168.242.162:3000/default_profile.png';

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
                            leading: CircleAvatar(
                              backgroundImage: comment['profile_image'] !=
                                          null &&
                                      comment['profile_image'].isNotEmpty
                                  ? NetworkImage(
                                      'http://192.168.242.162:3000${comment['profile_image']}')
                                  : AssetImage(
                                          'assets/images/default_profile.png')
                                      as ImageProvider,
                            ),

                            title: Text(
                              comment['fullname'],
                              maxLines: 1, // จำกัดให้แสดงเพียง 1 บรรทัด
                              overflow: TextOverflow
                                  .ellipsis, // แสดง ... หากข้อความยาวเกิน
                              style: TextStyle(
                                fontSize: 16, // ปรับขนาดฟอนต์ตามต้องการ
                                fontWeight: FontWeight
                                    .bold, // ปรับน้ำหนักฟอนต์ตามต้องการ
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
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: post['profile_image'] != null
                      ? NetworkImage(
                          'http://192.168.242.162:3000${post['profile_image']}')
                      : AssetImage('assets/images/default_profile.png')
                          as ImageProvider,
                ),
                title: Text(
                  post['fullname'] ??
                      'Unknown User', // Fallback for null fullname
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow:
                      TextOverflow.ellipsis, // Add ellipsis if text overflows
                  maxLines: 1, // Limit to one line
                ),
              ),
              if (post['image'] != null)
                Image.network(
                    'http://192.168.242.162:3000/posts/${post['image']}'),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['province'] ?? 'Unknown Province', // ✅ แสดง province
                      style: TextStyle(
                        fontSize: 16, // ✅ เท่ากับ description
                        fontWeight: FontWeight.bold, // ✅ ตัวหนา
                        color: Colors.blue, // ✅ สีฟ้า
                      ),
                    ),
                    SizedBox(height: 5), // ✅ เว้นระยะห่าง
                    Text(
                      post['description'] ?? '',
                      style: TextStyle(fontSize: 16), // ✅ เท่ากับ province
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
                          ? NetworkImage(currentUserProfileImage)
                          : AssetImage('assets/images/default_profile.png')
                              as ImageProvider,
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
                            image: AssetImage('assets/images/default_background.png'),
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
