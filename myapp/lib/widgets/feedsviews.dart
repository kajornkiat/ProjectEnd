import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:myapp/friendprofile.dart';
import 'package:myapp/profile.dart';

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
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
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

  List<String> provinces = [
    "Bangkok(กรุงเทพมหานคร)",
    "Chiang Mai(เชียงใหม่)",
    "Phuket(ภูเก็ต)",
    "Chonburi(ชลบุรี)",
    "Khon Kaen(ขอนแก่น)",
    "Nakhon Ratchasima(นครราชสีมา)",
    "Samut Prakan(สมุทรปราการ)",
    "Udon Thani(อุดรธานี)",
    "Surat Thani(สุราษฎร์ธานี)",
    "Rayong(ระยอง)",
    "Nonthaburi(นนทบุรี)",
    "Pathum Thani(ปทุมธานี)",
    "Ayutthaya(อยุธยา)",
    "Songkhla(สงขลา)",
    "Pattani(ปัตตานี)",
    "Trang(ตรัง)",
    "Ubon Ratchathani(อุบลราชธานี)",
    "Roi Et(ร้อยเอ็ด)",
    "Loei(เลย)",
    "Nakhon Si Thammarat(นครศรีธรรมราช)",
    "Sukhothai(สุโขทัย)",
    "Lampang(ลําปาง)",
    "Saraburi(สระบุรี)",
    "Mae Hong Son(แม่ฮ่องสอน)",
    "Tak(ตาก)"
  ];

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
  void initState() {
    super.initState();
    _initializeData(); // ✅ เรียกฟังก์ชันแยกเพื่อให้ `async` ทำงานได้ดีขึ้น
  }

  void _initializeData() async {
    await getCurrentUserId(); // ✅ โหลด userId ก่อน
    await fetchCurrentUserProfileImage();
    await _showProvinceSelectionPopup();
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

  // เพิ่มฟังก์ชันสำหรับดึงรูปโปรไฟล์ของผู้ใช้ที่ login
  Future<void> fetchCurrentUserProfileImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('http://192.168.242.162:3000/profile/$userId'),
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

  Future<void> fetchPosts({String? searchQuery}) async {
    String url = 'http://192.168.242.162:3000/api/posts';
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

  // ✅ ฟังก์ชันแสดง Popup เลือกจังหวัด
  Future<void> _showProvinceSelectionPopup() async {
    String? selectedProvince = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("คุณสนใจจังหวัดไหน"),
          content: DropdownSearch<String>(
            items: provinces,
            popupProps: PopupProps.menu(showSearchBox: true),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: "เลือกจังหวัด",
                border: OutlineInputBorder(),
              ),
            ),
            onChanged: (value) {
              Navigator.pop(context, value); // ✅ ส่งค่าจังหวัดที่เลือกกลับ
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ✅ ปิด Popup โดยไม่เลือกจังหวัด
              },
              child: Text("ยกเลิก"),
            ),
          ],
        );
      },
    );

    if (selectedProvince != null) {
      // ✅ อัปเดตช่องค้นหาและค้นหาโพสต์
      searchController.text = selectedProvince;
      fetchPosts(searchQuery: selectedProvince);
    } else {
      // ✅ หากผู้ใช้ไม่เลือกจังหวัด ให้โหลดข้อมูลโพสต์ทั้งหมด
      fetchPosts();
    }
  }

  Future<void> pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(); // เลือกหลายรูป
    if (pickedFiles != null) {
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)));
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
      Uri.parse('http://192.168.242.162:3000/api/posts'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['province'] = selectedProvince!;
    request.fields['description'] = descriptionController.text;

    for (var image in _images) {
      request.files.add(
        await http.MultipartFile.fromPath('images', image.path),
      );
    }

    var response = await request.send();

    if (response.statusCode == 201) {
      // ✅ เคลียร์ข้อมูลหลังจากโพสต์สำเร็จ
      setState(() {
        descriptionController.clear(); // ลบข้อความในช่อง description
        _images.clear(); // ลบรูปภาพที่เลือก
        selectedProvince = null; // รีเซ็ตจังหวัดที่เลือก
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
        Uri.parse('http://192.168.242.162:3000/api/posts/$postId'),
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
                  _buildImagePreview(), // แสดงรูปภาพที่เลือก
                  ElevatedButton(
                    onPressed: pickImages,
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
      Uri.parse('http://192.168.242.162:3000/api/posts'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "user_id": widget.userData["id"],
        "province": "General",
        "description": postController.text,
        "images": null,
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

  Widget _buildImagePreview() {
    return _images.isEmpty
        ? Text("No images selected")
        : SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Image.file(_images[index], height: 100, width: 100),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white, // สีไอคอนเป็นขาว
                          size: 20, // ปรับขนาดไอคอนให้เล็กลง
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5), // สีเงา
                              offset: Offset(2, 2), // ตำแหน่งเงา (x, y)
                              blurRadius: 1, // ความเบลอของเงา
                            ),
                          ],
                        ),
                        onPressed: () {
                          setState(() {
                            _images.removeAt(index); // ลบรูปภาพ
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
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
    if (userId == null) {
      return Center(
          child: CircularProgressIndicator()); // 🔥 รอให้ userId โหลดเสร็จก่อน
    }
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 239, 238, 229),
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
          // รายการโพสต์
          Expanded(
            child: posts.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      var post = posts[index];
                      final postId = post['post_id'];
                      final description = post['description'] ?? '';

                      // กำหนดค่าเริ่มต้นสำหรับ _isExpandedMap หากยังไม่มี
                      _isExpandedMap[postId] ??= false;

                      // ✅ ตรวจสอบค่าที่ได้จาก API
                      print(
                          "Comment count for post ${post['post_id']}: ${post['comment_count']}");

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
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
                                      : AssetImage(
                                              'assets/images/default_profile.png')
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    // ✅ เพิ่ม Text เพื่อแสดงวันที่
                                    if (post['date'] != null)
                                      Text(
                                        _formatDate(
                                            post['date']), // จัดรูปแบบวันที่
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
                                          value:
                                              "cancel", // 🔹 เพิ่มตัวเลือก "Cancel"
                                          child: Text("Cancel"),
                                        ),
                                      ],
                                    )
                                  : null, // 🔹 ซ่อนปุ่ม
                            ),
                            if (post['images'] != null &&
                                post['images'].isNotEmpty)
                              _buildPostImages(post['images'].cast<
                                  String>()), // แปลง List<dynamic> เป็น List<String>
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color:
                                            Color.fromARGB(255, 248, 30, 26),
                                        size: 15,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        post['province'] ??
                                            'Unknown Province', // ✅ แสดง province
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Color.fromARGB(255, 26, 141, 248),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5), // ✅ เว้นระยะห่าง
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isExpandedMap[postId] =
                                            !_isExpandedMap[postId]!;
                                      });
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 16, // ปรับขนาดฟอนต์
                                            color: const Color.fromARGB(255, 87,
                                                87, 87), // ปรับสีข้อความ
                                            height:
                                                1.5, // ปรับความสูงระหว่างบรรทัด
                                          ),
                                          maxLines: _isExpandedMap[postId]!
                                              ? null
                                              : 3,
                                          overflow: _isExpandedMap[postId]!
                                              ? TextOverflow.visible
                                              : TextOverflow.ellipsis,
                                        ),
                                        if (!_isExpandedMap[postId]! &&
                                            _needsExpansion(
                                                description, context))
                                          Text(
                                            'เพิ่มเติม...',
                                            style: TextStyle(
                                              color: const Color.fromARGB(
                                                  255, 115, 178, 230),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        if (_isExpandedMap[postId]!)
                                          Text(
                                            'แสดงน้อยลง',
                                            style: TextStyle(
                                              color: const Color.fromARGB(
                                                  255, 115, 178, 230),
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
                              child: Column(
                                children: [
                                  // ✅ แสดงคอมเมนต์ที่มีอยู่
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        // รูปโปรไฟล์แสดงทางซ้าย
                                        CircleAvatar(
                                          backgroundImage: currentUserProfileImage
                                                  .isNotEmpty
                                              ? NetworkImage(
                                                  currentUserProfileImage) // หากมีรูปจาก URL
                                              : AssetImage(
                                                      'assets/images/default_profile.png')
                                                  as ImageProvider, // หากไม่มีรูป
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
      floatingActionButton: FloatingActionButton(
        onPressed: showCreatePostModal, // เปิด Modal สร้างโพสต์
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue, // สีพื้นหลังของปุ่ม
        elevation: 5, // เงาของปุ่ม
      ),
    );
  }
}
