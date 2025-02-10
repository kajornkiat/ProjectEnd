import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

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

  @override
  void initState() {
    super.initState();
    fetchImages(); // เรียกใช้ฟังก์ชันดึงข้อมูลเมื่อเริ่มต้น
  }

  // ฟังก์ชันดึงข้อมูลจาก API
  Future<void> fetchImages() async {
    setState(() {
      _isLoading = true; // ตั้งค่าการโหลด
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('http://192.168.242.188:3000/profile/${widget.userId}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print('Response: ${response.body}'); // พิมพ์ค่า response

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        profileImageUrl = 'http://192.168.242.188:3000${data['profile_image']}';
        backgroundImageUrl =
            'http://192.168.242.188:3000${data['background_image']}';
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
      Uri.parse('http://192.168.242.188:3000/profile'),
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
      Uri.parse('http://192.168.242.188:3000/profile'), // ใช้ URL ที่ถูกต้อง
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      image: NetworkImage(backgroundImageUrl),
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
                    backgroundImage: NetworkImage(profileImageUrl),
                  ),
                ),
                // Logout Icon
                Positioned(
                  top: 40,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
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
                    icon: const Icon(Icons.settings, color: Colors.white),
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
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      showEditDialog(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 65), // ปรับขนาดให้เว้นระยะห่างด้านบน
            Text(
              userName,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
