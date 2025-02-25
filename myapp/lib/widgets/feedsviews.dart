import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

late IO.Socket socket;

class FeedsviewsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  FeedsviewsPage({required this.userData});

  @override
  _FeedsviewsPageState createState() => _FeedsviewsPageState();
}

class _FeedsviewsPageState extends State<FeedsviewsPage> {
  List<dynamic> posts = [];
  //Map<int, List<dynamic>> postComments = {}; // เก็บคอมเมนต์ของแต่ละโพสต์
  Map<int, TextEditingController> commentControllers =
      {}; // TextController ของแต่ละโพสต์
  Map<int, List<Map<String, dynamic>>> postComments = {};
  TextEditingController postController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String? selectedProvince;
  TextEditingController descriptionController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();
  int? userId; // เก็บ user_id ที่ดึงมาจาก SharedPreferences

  List<String> provinces = [
    "Bangkok",
    "Chiang Mai",
    "Phuket",
    "Chonburi",
    "Khon Kaen",
    "Nakhon Ratchasima",
    "Samut Prakan",
    "Udon Thani",
    "Surat Thani",
    "Rayong",
    "Nonthaburi",
    "Pathum Thani",
    "Ayutthaya",
    "Songkhla",
    "Pattani",
    "Trang",
    "Ubon Ratchathani",
    "Roi Et",
    "Loei",
    "Nakhon Si Thammarat",
    "Sukhothai",
    "Lampang",
    "Saraburi",
    "Mae Hong Son",
    "Tak"
  ];

  @override
  void initSocket() {
    socket = IO.io('http://10.39.5.31:3000', <String, dynamic>{
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
  void initState() {
    super.initState();
    _initializeData(); // ✅ เรียกฟังก์ชันแยกเพื่อให้ `async` ทำงานได้ดีขึ้น
  }

  void _initializeData() async {
    await getCurrentUserId(); // ✅ โหลด userId ก่อน
    fetchPosts(); // ✅ โหลดโพสต์หลังจาก userId ถูกตั้งค่า
    initSocket();

    searchController.addListener(() {
      String query = searchController.text;
      if (query.isEmpty) {
        fetchPosts(); // ✅ ดึงข้อมูลทั้งหมดถ้าไม่มีการค้นหา
      } else {
        fetchPosts(searchQuery: query); // ✅ ค้นหาข้อมูลตาม query
      }
    });
  }

  @override
  void dispose() {
    postController.dispose();
    searchController.dispose(); // ✅ ล้าง memory เพื่อป้องกัน memory leak
    // ✅ ยกเลิก Event Listener ของ socket
    socket.off('delete_post');
    socket.off('new_comment');
    socket.off('delete_comment');
    commentControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> fetchPosts({String? searchQuery}) async {
    String url = 'http://10.39.5.31:3000/api/posts';
    String apiUrl = searchQuery != null && searchQuery.isNotEmpty
        ? '$url?province=$searchQuery'
        : url;

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = json.decode(response.body);

        setState(() {
          posts = fetchedPosts;
        });
      } else {
        print("Error fetching posts: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> submitPost() async {
    if (selectedProvince == null || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please select a province and enter a description.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User is not authenticated.")),
      );
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.39.5.31:3000/api/posts'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['province'] = selectedProvince!;
    request.fields['description'] = descriptionController.text;

    if (_image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', _image!.path),
      );
    }

    var response = await request.send();

    if (response.statusCode == 201) {
      // ✅ เคลียร์ข้อมูลหลังจากโพสต์สำเร็จ
      setState(() {
        descriptionController.clear();
        _image = null;
        selectedProvince = null;
      });

      Navigator.pop(context); // ปิด Popup หลังจากโพสต์สำเร็จ
      fetchPosts(); // โหลดโพสต์ใหม่
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Failed to create post. Status: ${response.statusCode}")),
      );
    }
  }

  Future<void> deletePost(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User is not authenticated.")),
      );
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('http://10.39.5.31:3000/api/posts/$postId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        // ✅ ใช้ socket แจ้งให้ client ทุกคนลบโพสต์ (แต่ backend ก็ทำอยู่แล้ว)
        socket.emit('delete_post', {"post_id": postId});
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

  Future<void> getCurrentUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? storedUserId = prefs.getInt('user_id');
    print("🔍 โหลด user_id จาก SharedPreferences: $storedUserId");

    setState(() {
      userId = storedUserId;
    });

    if (userId == null) {
      print("❌ userId ยังเป็น null ลองล็อกอินใหม่");
    } else {
      print("✅ userId โหลดสำเร็จ: $userId");
    }
  }

  void showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ ให้ popup แสดงเต็มหน้าจอ
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Create Post",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  DropdownSearch<String>(
                    items: provinces,
                    popupProps: PopupProps.menu(showSearchBox: true),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: "Select Province",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedProvince = value!;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 10),
                  _image != null
                      ? Image.file(_image!, height: 100)
                      : Text("No image selected"),
                  ElevatedButton(
                    onPressed: pickImage,
                    child: Text("Pick Image"),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: submitPost,
                    child: Text("Post"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> createPost() async {
    if (postController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse('http://10.39.5.31:3000/api/posts'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "user_id": widget.userData["id"],
        "province": "General",
        "description": postController.text,
        "image": null,
      }),
    );

    if (response.statusCode == 201) {
      postController.clear();
      fetchPosts();
    } else {
      print("Error creating post: ${response.statusCode}");
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
        Uri.parse('http://10.39.5.31:3000/api/comments/$postId'),
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

  Future<void> addComment(int postId, Function updateState) async {
    if (!commentControllers.containsKey(postId)) {
      commentControllers[postId] = TextEditingController();
    }

    if (commentControllers[postId]!.text.isEmpty) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.post(
      Uri.parse("http://10.39.5.31:3000/api/comments"),
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

  Future<void> deleteComment(
      int postId, int commentId, Function updateState) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse("http://10.39.5.31:3000/api/comments/$commentId"),
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
                              backgroundImage: NetworkImage(
                                'http://10.39.5.31:3000${comment['profile_image']}',
                              ),
                            ),
                            title: Text(comment['fullname']),
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

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Center(
          child: CircularProgressIndicator()); // 🔥 รอให้ userId โหลดเสร็จก่อน
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by province...',
              prefixIcon: Icon(Icons.search, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Box สำหรับโพสต์
          Padding(
            padding: EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: showCreatePostModal, // ✅ กดแล้วเปิด Popup
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 3)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.userData['profile_image'] != null
                          ? NetworkImage(
                              'http://10.39.5.31:3000${widget.userData['profile_image']}')
                          : AssetImage('assets/images/default_profile.png')
                              as ImageProvider,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text("Create Post",
                          style: TextStyle(color: Colors.grey)),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.blue),
                      onPressed: showCreatePostModal, // ✅ กดแล้วเปิด Popup
                    ),
                  ],
                ),
              ),
            ),
          ),

          // รายการโพสต์
          Expanded(
            child: posts.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      var post = posts[index];

                      // ✅ ตรวจสอบค่าที่ได้จาก API
                      print(
                          "Comment count for post ${post['post_id']}: ${post['comment_count']}");

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage: post['profile_image'] != null
                                    ? NetworkImage(
                                        'http://10.39.5.31:3000${post['profile_image']}')
                                    : AssetImage(
                                            'assets/images/default_profile.png')
                                        as ImageProvider,
                              ),
                              title: Text(post['fullname'],
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
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
                                          value:
                                              "cancel", // 🔹 เพิ่มตัวเลือก "Cancel"
                                          child: Text("Cancel"),
                                        ),
                                      ],
                                    )
                                  : null, // 🔹 ซ่อนปุ่ม
                            ),
                            if (post['image'] != null)
                              Image.network(
                                  'http://10.39.5.31:3000/posts/${post['image']}'),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['province'] ??
                                        'Unknown Province', // ✅ แสดง province
                                    style: TextStyle(
                                      fontSize: 16, // ✅ เท่ากับ description
                                      fontWeight: FontWeight.bold, // ✅ ตัวหนา
                                      color: Colors.blue, // ✅ สีฟ้า
                                    ),
                                  ),
                                  SizedBox(height: 5), // ✅ เว้นระยะห่าง
                                  Text(
                                    post['description'] ?? '',
                                    style: TextStyle(
                                        fontSize: 16), // ✅ เท่ากับ province
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                children: [
                                  // ✅ แสดงคอมเมนต์ที่มีอยู่
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        // รูปโปรไฟล์แสดงทางซ้าย
                                        CircleAvatar(
                                          backgroundImage: post[
                                                          'profile_image'] !=
                                                      null &&
                                                  post['profile_image']
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                  'http://10.39.5.31:3000${post['profile_image']}')
                                              : AssetImage(
                                                      'assets/images/default_profile.png')
                                                  as ImageProvider,
                                          radius: 15,
                                        ),
                                        SizedBox(width: 8),
                                        // ช่องป้อนคอมเมนต์ กดแล้วแสดง showCommentPopup
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => showCommentPopup(
                                                post['post_id']),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12, horizontal: 16),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                "Leave a comment",
                                                style: TextStyle(
                                                    color: Colors.grey[600]),
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
                                                  color: Colors.black,
                                                  size: 32),
                                              if (post['comment_count'] !=
                                                      null &&
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
                                                    constraints: BoxConstraints(
                                                        minWidth: 22,
                                                        minHeight: 22),
                                                    child: Center(
                                                      child: Text(
                                                        '${post['comment_count']}',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          onPressed: () =>
                                              showCommentPopup(post['post_id']),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
