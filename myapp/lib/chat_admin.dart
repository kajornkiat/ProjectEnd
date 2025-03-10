import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'ChatDetailPage.dart';

class ChatAdminPage extends StatefulWidget {
  final int currentUserId;

  const ChatAdminPage({super.key, required this.currentUserId});

  @override
  _ChatAdminPageState createState() => _ChatAdminPageState();
}

class _ChatAdminPageState extends State<ChatAdminPage> {
  late io.Socket socket;
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> friendsList = [];
  List<Map<String, dynamic>> filteredFriends = [];
  List<Map<String, dynamic>> chatHistory = [];
  bool isLoading = false;
  Map<int, bool> unreadMessages = {};

  @override
  void initState() {
    super.initState();
    print("🟠 Current User ID: ${widget.currentUserId}"); // Debug Log
    fetchChatHistory();
    setupSocket();
  }

  void setupSocket() {
    socket = io.io('http://192.168.242.162:3000', <String, dynamic>{
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
      String senderName = data['fullname'] ?? 'Unknown';
      String messageText = data['message'] ?? '';

      int friendId = senderId == widget.currentUserId ? receiverId : senderId;

      if (mounted) {
        setState(() {
          unreadMessages[friendId] = true;
          int existingChatIndex =
              chatHistory.indexWhere((chat) => chat['id'] == friendId);
          if (existingChatIndex != -1) {
            // 🔄 อัปเดตข้อความล่าสุด
            chatHistory[existingChatIndex]['message'] = messageText;
            chatHistory[existingChatIndex]['created_at'] =
                data['created_at'] ?? '';

            // 🔄 ย้ายแชทไปบนสุด
            var updatedChat = chatHistory.removeAt(existingChatIndex);
            chatHistory.insert(0, updatedChat);
          } else {
            // ✅ ตรวจสอบว่า friendId มีอยู่แล้วหรือไม่
            if (!chatHistory.any((chat) => chat['id'] == friendId)) {
              chatHistory.insert(0, {
                'id': friendId,
                'fullname': senderName,
                'profile_image': data['profile_image'] ?? '',
                'message': messageText,
                'created_at': data['created_at'] ?? '',
              });
            }
          }
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

    final url = 'http://192.168.242.162:3000/api/users/search?fullname=$query';

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
        'http://192.168.242.162:3000/api/chat/history?userId=${widget.currentUserId}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        Set<int> uniqueIds = {};

        if (mounted) {
          setState(() {
            chatHistory = data
                .map((item) {
                  int friendId =
                      int.tryParse(item['friend_id'].toString()) ?? -1;
                  if (friendId <= 0 || uniqueIds.contains(friendId)) {
                    return null;
                  }
                  uniqueIds.add(friendId);
                  if (item['is_unread'] == true) {
                    unreadMessages[friendId] = true;
                  }
                  return {
                    'id': friendId,
                    'fullname': item['fullname'] ?? 'Unknown',
                    'profile_image': item['profile_image'] ?? '',
                    'message': item['message'] ?? '',
                    'created_at': item['created_at'] ?? '',
                  };
                })
                .where((item) => item != null)
                .cast<Map<String, dynamic>>()
                .toList();

            // ✅ เรียงลำดับตามเวลาล่าสุด
            chatHistory.sort((a, b) =>
                (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          });
        }
      } else {
        print("❌ Failed to load chat history: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Error fetching chat history: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> markMessagesAsRead(int friendId) async {
    final url = 'http://192.168.242.162:3000/api/chat/markAsRead';
    final body = {
      'user_id': widget.currentUserId,
      'friend_id': friendId,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print("✅ Messages marked as read for friendId: $friendId");
      } else {
        print("❌ Failed to mark messages as read: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Error marking messages as read: $e");
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
                              imageUrl = 'http://192.168.242.162:3000$imageUrl';
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
                                title: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal:
                                          0.0), // เพิ่มระยะห่างด้านซ้ายและขวา
                                  child: Text(
                                    user['fullname'] ?? 'Unknown User',
                                    maxLines: 1, // จำกัดให้แสดงเพียง 1 บรรทัด
                                    overflow: TextOverflow
                                        .ellipsis, // แสดง ... หากข้อความยาวเกิน
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: unreadMessages[userId] == true
                                          ? FontWeight
                                              .bold // ข้อความหนาหากมีข้อความใหม่
                                          : FontWeight.normal,
                                      color: unreadMessages[userId] == true
                                          ? Colors
                                              .black // สีเข้มหากมีข้อความใหม่
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  user['message'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadMessages[userId] == true
                                        ? Colors.black // สีเข้มหากมีข้อความใหม่
                                        : Colors.grey[600],
                                  ),
                                ),
                                onTap: () {
                                  print(
                                      "📢 Attempting to open chat with: ${user['id']} (${user['fullname']})"); // Debug Log

                                  final userId = user['id'] is int
                                      ? user['id']
                                      : int.tryParse(user['id'].toString()) ??
                                          0;
                                  if (userId > 0) {
                                    setState(() {
                                      unreadMessages[userId] = false;
                                    });
                                    markMessagesAsRead(userId);
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
