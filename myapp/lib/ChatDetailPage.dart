import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // นำเข้าฟังก์ชัน File
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

late IO.Socket socket;

class ChatDetailPage extends StatefulWidget {
  //final int currentUserId;
  final String name;
  final String avatar;
  final int currentUserId; // เพิ่ม friendId เข้ามา
  final int friendId;
  final VoidCallback? refreshChatList;

  ChatDetailPage({
    required this.name,
    required this.avatar,
    required this.currentUserId,
    required this.friendId,
    this.refreshChatList,
  });

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  Map<int, List<Map<String, dynamic>>> messagesMap = {};
  List<Map<String, dynamic>> chatHistory = [];

  @override
  void initState() {
    super.initState();
    connectSocket();
    fetchChatHistory(); // โหลดประวัติการแชท
  }

  void connectSocket() {
    socket = IO.io('http://192.168.242.162:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true, // เปิดให้มีการ reconnect
      'reconnectionAttempts': 5,
      'reconnectionDelay': 5000, // 5 วินาที
    });
    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to socket server');
      socket.emit(
          'joinRoom', widget.currentUserId); // 🔹 ให้ user join room ของตัวเอง
    });

    socket.on('receiveMessage', (data) {
      int senderId = data['sender_id'];
      int receiverId = data['receiver_id'];
      String messageText = data['message'] ?? ''; // 🔹 ป้องกัน `null`
      String messageType = data['message_type'] ?? 'text'; // 🔹 ป้องกัน `null`
      String messageId = data['message_id'] ?? ''; // ใช้ message_id ป้องกันซ้ำ

      print("📩 Received message: $data");

      int chatPartnerId =
          senderId == widget.currentUserId ? receiverId : senderId;

      if (chatPartnerId == widget.friendId) {
        if (mounted) {
          setState(() {
            messagesMap.putIfAbsent(chatPartnerId, () => []);
            // ✅ ป้องกันการเพิ่มข้อความซ้ำ
            if (!messagesMap[chatPartnerId]!
                .any((msg) => msg['text'] == messageText)) {
              messagesMap[chatPartnerId]!.add({
                'text': messageText,
                'isMe': senderId == widget.currentUserId,
                'type': 'text',
              });
            }
          });
        }
      }
    });
  }

  void _sendMessage() {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      print("🔵 Sending message: $message");

      socket.emit('sendMessage', {
        'senderId': widget.currentUserId,
        'receiverId': widget.friendId,
        'message': message,
        'message_Type': 'text',
      });

      if (mounted) {
        setState(() {
          messagesMap.putIfAbsent(widget.friendId, () => []);
          messagesMap[widget.friendId]!.add({
            'text': message,
            'isMe': true,
            'type': 'text',
          });
        });
      }

      _messageController.clear();

      // 🔹 แจ้งให้หน้า chat.dart โหลดข้อมูลใหม่
      Future.delayed(Duration(milliseconds: 500), () {
        if (widget.refreshChatList != null) {
          widget.refreshChatList!();
        }
      });
    }
  }

  Future<void> fetchChatHistory() async {
    final url = Uri.parse(
        'http://192.168.242.162:3000/api/chat/messages?sender_id=${widget.currentUserId}&receiver_id=${widget.friendId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("📜 Chat History Loaded: $data");

        if (mounted) {
          setState(() {
            messagesMap[widget.friendId] = []; // ✅ เคลียร์ของเพื่อนที่เลือก
            data.sort((a, b) {
              String? createdA = a['created_at'];
              String? createdB = b['created_at'];
              if (createdA == null || createdB == null)
                return 0; // 🔹 ป้องกัน `null`
              return DateTime.parse(createdA)
                  .compareTo(DateTime.parse(createdB));
            });
            for (var chat in data) {
              messagesMap[widget.friendId]!.add({
                'text': chat['message'] ?? '', // 🔹 ป้องกัน `null`
                'isMe': chat['sender_id'] == widget.currentUserId,
                'type': chat['message_type'] ?? 'text', // 🔹 ป้องกัน `null`
              });
            }
          });
        }
      } else {
        print("❌ Failed to load chat history. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error loading chat history: $e");
    }
  }

  void _sendImage(XFile image) async {
    // 1️⃣ อัปโหลดรูปไปที่เซิร์ฟเวอร์ก่อน
    String? imageUrl = await uploadImageToServer(image);

    if (imageUrl != null) {
      print("🔵 Image URL: $imageUrl");
      print("🔵 Sender ID: ${widget.currentUserId}");
      print("🔵 Receiver ID: ${widget.friendId}");
      // 2️⃣ ส่ง URL ของรูปผ่าน Socket
      socket.emit('sendMessage', {
        'senderId': widget.currentUserId,
        'receiverId': widget.friendId,
        'message': imageUrl,
        'message_type': 'image', // 🔹 ตรงกับคีย์ของเซิร์ฟเวอร์
      });

      // 3️⃣ อัปเดต UI เฉพาะแชทของ friendId
      if (mounted) {
        setState(() {
          messagesMap.putIfAbsent(widget.friendId, () => []);
          messagesMap[widget.friendId]!.add({
            'imagePath': imageUrl, // ใช้ URL ของรูป
            'isMe': true,
            'type': 'image',
          });
        });
      }
    } else {
      print("❌ อัปโหลดรูปไม่สำเร็จ");
    }
  }

  Future<String?> uploadImageToServer(XFile image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.242.162:3000/api/upload_image'),
    );

    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        return jsonResponse['imageUrl']; // สมมติว่าเซิร์ฟเวอร์คืน URL ของรูป
      } else {
        print("❌ อัปโหลดรูปไม่สำเร็จ: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Error อัปโหลดรูป: $e");
      return null;
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      _sendImage(pickedFile);
    }
  }

  void _handleIncomingMessage(dynamic data) {
    int senderId = data['sender_id'];
    int receiverId = data['receiver_id'];
    String messageText = data['message'] ?? ''; // 🔹 ป้องกัน `null`
    String messageType = data['type'] ?? 'text'; // 🔹 ป้องกัน `null`

    if ((senderId == widget.currentUserId && receiverId == widget.friendId) ||
        (receiverId == widget.currentUserId && senderId == widget.friendId)) {
      if (mounted) {
        setState(() {
          messagesMap.putIfAbsent(widget.friendId, () => []);
          messagesMap[widget.friendId]!.add({
            'text': messageText,
            'isMe': senderId == widget.currentUserId,
            'type': messageType,
          });
        });
      }
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    if (message['type'] == 'text') {
      return Row(
        mainAxisAlignment:
            message['isMe'] ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: message['isMe']
                  ? const Color.fromARGB(255, 189, 242, 253)
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(15),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 200), // จำกัดความกว้าง
              child: Text(
                message['text'],
                softWrap: true, // อนุญาตให้ข้อความเลื่อนไปบรรทัดใหม่
                overflow: TextOverflow.visible, // แสดงข้อความที่ยาวเกิน
              ),
            ),
          ),
        ],
      );
    } else if (message['type'] == 'image') {
      return Row(
        mainAxisAlignment:
            message['isMe'] ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: Image.network(
              message['imagePath'], // ใช้ URL ของรูปภาพ
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.broken_image, size: 100, color: Colors.grey);
              },
            ),
          ),
        ],
      );
    }
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  (widget.avatar != null && widget.avatar.isNotEmpty)
                      ? NetworkImage(widget.avatar)
                      : AssetImage('assets/images/default_profile.png')
                          as ImageProvider,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                overflow:
                    TextOverflow.ellipsis, // ซ่อนข้อความที่ยาวเกินด้วยจุดไข่ปลา
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone),
            onPressed: () {
              // ฟังก์ชันโทร
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              // ฟังก์ชันแสดงข้อมูล
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messagesMap[widget.friendId]?.length ?? 0,
              itemBuilder: (context, index) {
                return _buildMessage(messagesMap[widget.friendId]![index]);
              },
            ),
          ),
          // กล่องพิมพ์ข้อความและไอคอนต่าง ๆ
          Container(
            margin: EdgeInsets.all(10), // ระยะห่างจากขอบจอ
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(
                  255, 255, 255, 255), // สีพื้นหลังของกล่องแชท
              borderRadius: BorderRadius.circular(30), // ขอบมน
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5), // สีของเงา
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3), // ตำแหน่งของเงา
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt),
                  onPressed: () {
                    _pickImage(ImageSource.camera);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: () {
                    _pickImage(ImageSource.gallery);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ข้อความของคุณ...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
