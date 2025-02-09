import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // นำเข้าฟังก์ชัน File

class ChatDetailPage extends StatefulWidget {
  final String name;
  final String avatar;

  ChatDetailPage({required this.name, required this.avatar});

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        _messages.add({
          'text': _messageController.text,
          'isMe': true,
          'type': 'text',
        });
      });
      _messageController.clear();
    }
  }

  void _sendImage(XFile image) {
    setState(() {
      _messages.add({
        'imagePath': image.path,
        'isMe': true,
        'type': 'image',
      });
    });
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      _sendImage(pickedFile);
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
            child: Image.file(
              File(message['imagePath']),
              width: 150,
              height: 150,
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
              backgroundImage: AssetImage(widget.avatar),
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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
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
