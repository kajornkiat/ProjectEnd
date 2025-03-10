import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'friendprofile.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

late IO.Socket socket;

class ProfilePage extends StatefulWidget {
  final int userId;
  const ProfilePage({required this.userId, super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String profileImageUrl = ''; // URL ของรูปโปรไฟล์
  String backgroundImageUrl = ''; // URL ของรูปพื้นหลัง
  String userName = ''; // ชื่อของผู้ใช้
  bool _isLoading = false; // สถานะการโหลด
  bool _isModalOpen = false;
  List<Map<String, dynamic>> friends = []; // ✅ เพิ่มตัวแปรเก็บรายชื่อเพื่อน

  // เพิ่มตัวแปรและฟังก์ชันจาก feedsviews.dart
  List<dynamic> posts = [];
  Map<int, TextEditingController> commentControllers = {};
  Map<int, List<Map<String, dynamic>>> postComments = {};
  TextEditingController postController = TextEditingController();
  int? userId; // เก็บ user_id ที่ดึงมาจาก SharedPreferences
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
    fetchImages(); // เรียกใช้ฟังก์ชันดึงข้อมูลเมื่อเริ่มต้น
    fetchAcceptedFriends(); // ดึงรายชื่อเพื่อน
    getCurrentUserId().then((_) {
      fetchPosts(); // เรียก fetchPosts หลังจาก userId ถูกตั้งค่า
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

    socket.on('delete_post', (data) {
      int postId = data['post_id'];
      if (!mounted) return; // ✅ ป้องกันการเรียก setState() หลังจาก dispose()
      setState(() {
        posts.removeWhere((post) => post['post_id'] == postId);
      });
    });

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

  // ฟังก์ชันดึงข้อมูลจาก API
  Future<void> fetchImages() async {
    setState(() {
      _isLoading = true; // ตั้งค่าการโหลด
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('http://192.168.242.162:3000/profile/${widget.userId}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print('Response: ${response.body}'); // พิมพ์ค่า response

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        profileImageUrl =
            data['profile_image'] != null && data['profile_image'].isNotEmpty
                ? 'http://192.168.242.162:3000${data['profile_image']}'
                : '';
        backgroundImageUrl = data['background_image'] != null &&
                data['background_image'].isNotEmpty
            ? 'http://192.168.242.162:3000${data['background_image']}'
            : '';
        userName = data['fullname'] ?? '';
      });
    } else {
      print('Failed to load images');
    }

    setState(() {
      _isLoading = false; // สิ้นสุดการโหลด
    });
  }

  // ฟังก์ชันอัปโหลดรูปภาพ
  Future<void> uploadImage(File imageFile, String type) async {
    setState(() {
      _isLoading = true; // ตั้งค่าการโหลด
    });

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.242.162:3000/profile'),
    );
    // ใช้ widget.userId แทน '1'
    request.fields['id'] = widget.userId.toString();

    // เพิ่มไฟล์รูปภาพ
    request.files.add(await http.MultipartFile.fromPath(type, imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      print('Uploaded successfully');
      fetchImages(); // อัปเดตรูปภาพหลังอัปโหลด
    } else {
      print('Upload failed: ${await response.stream.bytesToString()}');
    }

    setState(() {
      _isLoading = false; // สิ้นสุดการโหลด
    });
  }

  // ฟังก์ชันอัปเดตข้อมูลโปรไฟล์ไปยังเซิร์ฟเวอร์
  Future<void> updateProfile({
    String? newName,
    File? profileImageFile,
    File? backgroundImageFile,
  }) async {
    setState(() {
      _isLoading = true; // ตั้งค่าการโหลด
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // สร้าง request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.242.162:3000/profile'), // ใช้ URL ที่ถูกต้อง
    );

    // ส่ง ID
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['id'] = widget.userId.toString();

    // ส่งข้อมูลชื่อใหม่ถ้ามี
    if (newName != null && newName.isNotEmpty) {
      request.fields['name'] = newName;
    }

    // ส่งรูปภาพถ้ามี
    if (profileImageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'profile_image', profileImageFile.path));
    }

    if (backgroundImageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'background_image', backgroundImageFile.path));
    }

    // ส่งคำขอ
    final response = await request.send();

    if (response.statusCode == 200) {
      print('Profile updated successfully');
      fetchImages(); // อัปเดตรูปภาพและชื่อหลังอัปโหลด
    } else {
      print(
          'Failed to update profile: ${await response.stream.bytesToString()}');
    }

    setState(() {
      _isLoading = false; // สิ้นสุดการโหลด
    });
  }

  // ฟังก์ชันเลือกภาพจาก Gallery/Camera
  Future<void> pickImage(String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      if (type == 'profile_image') {
        updateProfile(profileImageFile: imageFile); // อัปโหลดรูปโปรไฟล์
      } else {
        updateProfile(backgroundImageFile: imageFile); // อัปโหลดรูปพื้นหลัง
      }
    }
  }

  // ฟังก์ชันแสดง dialog สำหรับแก้ไข name, profile_image, หรือ background_image
  void showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showEditNameDialog(context); // แสดง dialog แก้ไขชื่อ
                },
                child: const Text('Name'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  pickImage('profile_image'); // เปลี่ยนรูปโปรไฟล์
                },
                child: const Text('Profile'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  pickImage('background_image'); // เปลี่ยนรูปพื้นหลัง
                },
                child: const Text('Background'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ฟังก์ชันแสดง dialog สำหรับแก้ไขชื่อ
  void showEditNameDialog(BuildContext context) {
    TextEditingController nameController =
        TextEditingController(text: userName);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'New Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () {
                String newName = nameController.text; // เก็บชื่อใหม่
                updateProfile(newName: newName); // อัปเดตชื่อไปยังเซิร์ฟเวอร์
                Navigator.of(context).pop();
              },
              child: const Text('YES'),
            ),
          ],
        );
      },
    );
  }

  //ฟังก์ชัน logout
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // ลบ token ออกจาก SharedPreferences

    // นำผู้ใช้กลับไปยังหน้า login.dart
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  /// ฟังก์ชันแสดง dialog logout
  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด dialog
              },
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () {
                logout(); // ออกจากระบบ
                Navigator.of(context).pop(); // ปิด dialog
              },
              child: const Text('YES'),
            ),
          ],
        );
      },
    );
  }

  //ฟังก์ขันดึงรายชื่อเพื่อน
  Future<void> fetchAcceptedFriends() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print("Token is null");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            'http://192.168.242.162:3000/api/friends/accepted/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          friends = data
              .map((friend) => {
                    'id': friend['id'] ?? 0,
                    'fullname': friend['fullname'] ?? 'Unknown',
                    'profileImage': friend['profile_image'] != null &&
                            friend['profile_image'].isNotEmpty
                        ? 'http://192.168.242.162:3000${friend['profile_image']}'
                        : '',
                    'backgroundImage': friend['background_image'] != null &&
                            friend['background_image'].isNotEmpty
                        ? 'http://192.168.242.162:3000${friend['background_image']}'
                        : '',
                    'status': friend['status'] ?? 'user',
                  })
              .toList();
        });
      } else {
        print(
            'Failed to load accepted friends: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("Error fetching accepted friends: $e");
    }
  }

  Widget buildFriendsList() {
    if (friends.isEmpty) {
      return const Center(
        child: Text("No friends available"), // แสดงข้อความเมื่อไม่มีเพื่อน
      );
    }
    return SizedBox(
      height: 100, // กำหนดความสูงของ list เพื่อน
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // เลื่อนแนวนอน
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];

          return GestureDetector(
            onTap: () {
              // 👉 ไปที่หน้า friendprofile.dart และส่ง userId ของเพื่อน
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendProfilePage(
                    userId: friend['id'],
                    currentUserId: widget
                        .userId, // ใช้ userId ของโปรไฟล์ปัจจุบันเป็น currentUserId
                    fullname: friend['fullname'],
                    profileImageUrl: friend['profileImage'],
                    backgroundImageUrl:
                        friend['backgroundImage'], // หรือค่าอื่นที่เหมาะสม
                    status: friend['status'],
                    //friend_status: friend['friend_status'],
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: friend['profileImage'] != null &&
                            friend['profileImage'].isNotEmpty
                        ? NetworkImage(friend['profileImage'])
                        : AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 70,
                    child: Text(
                      friend['fullname'],
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
    if (userId == null || userId == 0) {
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
            'http://192.168.242.162:3000/api/posts?user_id=${userId.toString()}'),
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

  // ฟังก์ชันสำหรับลบโพสต์
  Future<void> deletePost(int postId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('http://192.168.242.162:3000/api/posts/$postId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          posts.removeWhere((post) => post['post_id'] == postId);
        });
      } else {
        print("Failed to delete post: ${response.body}");
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

    setState(() {
      _isModalOpen = true; // ตั้งค่าเป็น true เมื่อเปิด ModalBottomSheet
    });

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
    ).whenComplete(() {
      setState(() {
        _isModalOpen = false; // ตั้งค่าเป็น false เมื่อปิด ModalBottomSheet
      });
    });
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
                // ✅ ซ่อนปุ่ม "ไข่ปลา" ถ้า post['user_id'] ไม่ตรงกับ userId ของผู้ใช้ปัจจุบัน
                trailing: post['user_id'] == userId
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == "delete") {
                            deletePost(post['post_id']);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: "delete",
                            child: Text("Delete"),
                          ),
                          const PopupMenuItem(
                            value: "cancel", // 🔹 เพิ่มตัวเลือก "Cancel"
                            child: Text("Cancel"),
                          ),
                        ],
                      )
                    : null, // 🔹 ซ่อนปุ่ม
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
                      backgroundImage: post['profile_image'] != null &&
                              post['profile_image'].isNotEmpty
                          ? NetworkImage(
                              'http://192.168.242.162:3000${post['profile_image']}')
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
      backgroundColor: Color.fromARGB(255, 248, 247, 245),
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
                      image: backgroundImageUrl.isNotEmpty
                          ? NetworkImage(backgroundImageUrl)
                          : AssetImage('assets/images/default_background.png')
                              as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Profile Picture
                Positioned(
                  top: 100,
                  left: MediaQuery.of(context).size.width / 2 - 80,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: Visibility(
                    visible: Navigator.canPop(context) &&
                        !_isModalOpen, // ไม่แสดงถ้า ModalBottomSheet เปิดอยู่
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black, size: 30),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                // Logout Icon
                Positioned(
                  top: 40,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.logout,
                        color: Color.fromARGB(255, 1, 191, 255)),
                    onPressed: () {
                      showLogoutDialog(context);
                    },
                  ),
                ),
                //Setting icon
                Positioned(
                  top: 70,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.settings,
                        color: Color.fromARGB(255, 1, 191, 255)),
                    onPressed: () {
                      //Action
                    },
                  ),
                ),
                // Edit icon
                Positioned(
                  top: 100,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.edit,
                        color: Color.fromARGB(255, 1, 191, 255)),
                    onPressed: () {
                      showEditDialog(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 65), // ปรับขนาดให้เว้นระยะห่างด้านบน
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 50), // เว้นขอบซ้าย-ขวา 16px
              child: Text(
                userName,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 20), // ✅ เพิ่มระยะห่างก่อนแสดงเพื่อน
            buildFriendsList(), // ✅ เพิ่มส่วนแสดงรายชื่อเพื่อนที่นี่
            buildPosts(), // แสดงโพสต์ของผู้ใช้
          ],
        ),
      ),
    );
  }
}
