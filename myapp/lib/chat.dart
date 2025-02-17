import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'ChatDetailPage.dart';

class ChatPage extends StatefulWidget {
  final int currentUserId;

  const ChatPage({super.key, required this.currentUserId});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late io.Socket socket;
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> friendsList = [];
  List<Map<String, dynamic>> filteredFriends = [];
  List<Map<String, dynamic>> chatHistory = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    print("🟠 Current User ID: ${widget.currentUserId}"); // Debug Log
    fetchChatHistory();
    setupSocket();
  }

  void setupSocket() {
    socket = io.io('http://10.39.5.2:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();
    socket.onConnect((_) {
      print('Connected to Socket.io');
      socket.emit("joinRoom", widget.currentUserId);
    });

    socket.on("receiveMessage", (data) {
      print("New message received: $data");

      int senderId = data['sender_id'];
      int receiverId = data['receiver_id'];
      String senderName =
          data['fullname'] ?? 'Unknown'; // ✅ ใช้ fullname จาก WebSocket
      String messageText = data['message'] ?? '';

      if (mounted) {
        setState(() {
          chatHistory.insert(0, {
            'id': senderId == widget.currentUserId ? receiverId : senderId,
            'fullname': senderName, // ✅ แสดงชื่อผู้ส่ง
            'profile_image': data['profile_image'] ?? '',
            'message': messageText,
            'created_at': data['created_at'] ?? '',
          });
        });
      }
    });

    socket.onDisconnect((_) {
      print('Disconnected from Socket.io');
    });
  }

  Future<void> fetchFriends({String query = ''}) async {
    setState(() => isLoading = true);

    if (query.isEmpty) {
      setState(() {
        filteredFriends =
            List.from(chatHistory); // ✅ ควรใช้ `List.from()` ป้องกันข้อผิดพลาด
        isLoading = false;
      });
      return;
    }

    final url =
        'http://10.39.5.2:3000/api/friends/search?userId=${widget.currentUserId}&query=$query';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          filteredFriends =
              data.map((item) => item as Map<String, dynamic>).toList();
        });
      } else {
        print("Failed to load friends: ${response.statusCode}");
      }
    } catch (e) {
      print('Failed to load friends: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchChatHistory() async {
    setState(() => isLoading = true);

    final url =
        'http://10.39.5.2:3000/api/chat/history?userId=${widget.currentUserId}';
    print("📡 Fetching chat history from: $url"); // Debug Log

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (mounted) {
          setState(() {
            chatHistory = data
                .map((item) {
                  // ✅ ป้องกัน friend_id เป็น null
                  int friendId =
                      item.containsKey('friend_id') && item['friend_id'] != null
                          ? int.tryParse(item['friend_id'].toString()) ?? -1
                          : -1;

                  print(
                      "🟢 Loaded chat item: $item, friendId: $friendId"); // Debug Log

                  return {
                    'id': friendId > 0 ? friendId : null, // ✅ ป้องกันค่าผิดพลาด
                    'fullname': item['fullname'] ?? 'Unknown',
                    'profile_image': item['profile_image'] ?? '',
                    'message': item['message'] ?? '',
                    'created_at': item['created_at'] ?? '',
                  };
                })
                .where((item) => item['id'] != null)
                .toList(); // ✅ กรองค่าที่ id เป็น null ออก
          });
        }
      } else {
        print(
            "❌ Failed to load chat history, Status Code: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Error fetching chat history: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayList =
        searchController.text.isEmpty ? chatHistory : filteredFriends;

    return Scaffold(
      appBar: AppBar(title: const Text("Chat")),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                onChanged: (query) => fetchFriends(query: query),
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: "Search Friends",
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.orange),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchChatHistory, // ฟังก์ชันที่จะโหลดข้อมูลใหม่
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayList.isEmpty
                      ? const Center(child: Text('No friends or chats found'))
                      : ListView.builder(
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final user = displayList[index];
                            final userId = user['id'] is int
                                ? user['id']
                                : int.tryParse(user['id'].toString()) ?? 0;
                            print(
                                "🟢 userId: $userId from ${user['id']}"); // ✅ Debug log

                            String fullname = (user['fullname'] != null &&
                                    user['fullname'].toString().isNotEmpty)
                                ? user['fullname'].toString()
                                : 'Unknown';

                            String imageUrl = user['profile_image'] ?? '';
                            if (imageUrl.isNotEmpty &&
                                !imageUrl.startsWith('http')) {
                              imageUrl = 'http://10.39.5.2:3000$imageUrl';
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: imageUrl.isNotEmpty
                                      ? NetworkImage(imageUrl)
                                      : const AssetImage(
                                              'assets/images/default_profile.png')
                                          as ImageProvider,
                                ),
                                title: Text(user['fullname'] ?? 'Unknown'),
                                onTap: () {
                                  print(
                                      "📢 Attempting to open chat with: ${user['id']} (${user['fullname']})"); // Debug Log

                                  final userId = user['id'] is int
                                      ? user['id']
                                      : int.tryParse(user['id'].toString()) ??
                                          0;
                                  if (userId > 0) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatDetailPage(
                                          currentUserId: widget.currentUserId,
                                          friendId: userId,
                                          name: user['fullname'] ?? 'Unknown',
                                          avatar: imageUrl,
                                          refreshChatList: fetchChatHistory,
                                        ),
                                      ),
                                    );
                                  } else {
                                    print(
                                        "⚠️ Invalid user ID: ${user['id']} (Cannot open chat page)");
                                  }
                                },
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
