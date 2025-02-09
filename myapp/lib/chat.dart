import 'package:flutter/material.dart';
import 'ChatDetailPage.dart';

class ChatPage extends StatelessWidget {
  final List<Map<String, String>> chats = [
    {'name': 'Alice', 'avatar': 'assets/images/alice_avatar.png'},
    {'name': 'Bob', 'avatar': 'assets/images/bob_avatar.png'},
    {'name': 'Charlie', 'avatar': 'assets/images/charlie_avatar.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
      ),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage(chats[index]['avatar']!),
            ),
            title: Text(chats[index]['name']!),
            onTap: () {
              // นำทางไปยัง ChatDetailPage พร้อมทั้งส่งชื่อและรูป avatar
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailPage(
                    name: chats[index]['name']!,
                    avatar: chats[index]['avatar']!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
