import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'userprofile.dart'; // ลิ้งค์ไปหน้าข้อมูลเพื่อน

class ControlUsersPage extends StatefulWidget {
  final int currentUserId; // รับ userId ของผู้ใช้ที่ล็อกอิน
  final Function(int) onRequestCountChange; // 🔹 Callback function

  const ControlUsersPage({
    super.key,
    required this.currentUserId,
    required this.onRequestCountChange, // 🔹 รับ callback
  });

  @override
  _ControlUsersPageState createState() => _ControlUsersPageState();
}

class _ControlUsersPageState extends State<ControlUsersPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];
  bool isSearching = false;
  List users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
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

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response =
          await http.get(Uri.parse('http://192.168.242.162:3000/api/users/all'));
      if (response.statusCode == 200) {
        setState(() {
          users = json
              .decode(response.body)
              .where((user) => user['id'] != widget.currentUserId)
              .toList();
          isLoading = false;
        });
      } else {
        print('Failed to load users');
      }
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  Future<void> updateStatus(String userId, String newStatus) async {
    final response = await http.put(
      Uri.parse('http://192.168.242.162:3000/api/users/update-status'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'status': newStatus}),
    );

    if (response.statusCode == 200) {
      // อัปเดตสถานะผู้ใช้ใน List ทันที
      setState(() {
        for (var user in users) {
          if (user['id'].toString() == userId) {
            user['status'] = newStatus;
            break;
          }
        }
        for (var user in searchResults) {
          if (user['id'].toString() == userId) {
            user['status'] = newStatus;
            break;
          }
        }
      });
    } else {
      print('Failed to update status');
    }
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

    final url =
        Uri.parse("http://192.168.242.162:3000/api/users/search?fullname=$query");
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

  Future<void> deleteUser(int userId) async {
    final url = Uri.parse('http://192.168.242.162:3000/api/users/delete');
    final response = await http.delete(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId}),
    );

    if (response.statusCode == 200) {
      setState(() {
        users.removeWhere((user) => user['id'] == userId);
        searchResults.removeWhere((user) => user['id'] == userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User deleted successfully')),
      );
    } else {
      print('Failed to delete user');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user')),
      );
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
              SizedBox(height: MediaQuery.of(context).padding.top + 10),

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

              SizedBox(height: isSearching ? 30 : 10), // ลดระยะห่าง

              if (!isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "All Users",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // 🔹 พื้นหลังสีขาวสำหรับรายการผู้ใช้
              Expanded(
                child: Container(
                    child: (isSearching ? searchResults : users).isEmpty
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: isSearching
                                ? searchResults.length
                                : users.length,
                            itemBuilder: (context, index) {
                              final user = isSearching
                                  ? searchResults[index]
                                  : users[index];
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 1),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 2,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: ListTile(
                                      leading: GestureDetector(
                                        onTap: () {
                                          // ส่งข้อมูลผู้ใช้ไปยังหน้า UserProfilePage
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  UserProfilePage(
                                                userId: user['id'],
                                                currentUserId:
                                                    widget.currentUserId,
                                                fullname: user['fullname'],
                                                profileImageUrl: user[
                                                            'profile_image'] !=
                                                        null
                                                    ? 'http://192.168.242.162:3000${user['profile_image']}'
                                                    : '',
                                                backgroundImageUrl: user[
                                                            'background_image'] !=
                                                        null
                                                    ? 'http://192.168.242.162:3000${user['background_image']}'
                                                    : '',
                                                status: user['status'],
                                              ),
                                            ),
                                          );
                                        },
                                        child: CircleAvatar(
                                          backgroundImage: user[
                                                      'profile_image'] !=
                                                  null
                                              ? NetworkImage(
                                                  'http://192.168.242.162:3000${user['profile_image']}',
                                                )
                                              : AssetImage(
                                                      'assets/images/default_profile.png')
                                                  as ImageProvider,
                                        ),
                                      ),
                                      title: GestureDetector(
                                        onTap: () {
                                          // ส่งข้อมูลผู้ใช้ไปยังหน้า UserProfilePage
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  UserProfilePage(
                                                userId: user['id'],
                                                currentUserId:
                                                    widget.currentUserId,
                                                fullname: user['fullname'],
                                                profileImageUrl: user[
                                                            'profile_image'] !=
                                                        null
                                                    ? 'http://192.168.242.162:3000${user['profile_image']}'
                                                    : '',
                                                backgroundImageUrl: user[
                                                            'background_image'] !=
                                                        null
                                                    ? 'http://192.168.242.162:3000${user['background_image']}'
                                                    : '',
                                                status: user['status'],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          user['fullname'].length > 20
                                              ? '${user['fullname'].substring(0, 20)}...'
                                              : user['fullname'],
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize
                                            .min, // ให้ Row ไม่กินพื้นที่มากเกินไป
                                        children: [
                                          // DropdownButton สำหรับเปลี่ยนสถานะผู้ใช้
                                          Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color.fromARGB(
                                                  255, 173, 217, 247),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: DropdownButton<String>(
                                              value: user['status'],
                                              dropdownColor:
                                                  const Color.fromARGB(
                                                      255, 200, 227, 245),
                                              underline: SizedBox(),
                                              onChanged: (newValue) {
                                                if (newValue != null) {
                                                  updateStatus(
                                                      user['id'].toString(),
                                                      newValue);
                                                }
                                              },
                                              items: ['admin', 'user']
                                                  .map((status) {
                                                return DropdownMenuItem<String>(
                                                  value: status,
                                                  child: Text(
                                                    status,
                                                    style: const TextStyle(
                                                        color: Color.fromARGB(
                                                            255, 0, 0, 0)),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          // PopupMenuButton สำหรับเมนูจุดไข่ปลา
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert,
                                                color: Colors.black),
                                            onSelected: (String choice) {
                                              if (choice == 'delete') {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title:
                                                        Text('Confirm Delete'),
                                                    content: Text(
                                                        'Are you sure you want to delete this user?'),
                                                    actions: [
                                                      TextButton(
                                                        child: Text('Cancel'),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                      ),
                                                      TextButton(
                                                        child: Text('Delete'),
                                                        onPressed: () {
                                                          deleteUser(
                                                              user['id']);
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) {
                                              return [
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete User',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ),
                                              ];
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
