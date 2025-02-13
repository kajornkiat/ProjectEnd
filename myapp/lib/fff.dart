import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'friendprofile.dart';

class AddFriendsPage extends StatefulWidget {
  final int currentUserId;

  const AddFriendsPage({super.key, required this.currentUserId});

  @override
  _AddFriendsPageState createState() => _AddFriendsPageState();
}

class _AddFriendsPageState extends State<AddFriendsPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];
  List<dynamic> friendRequests = [];

  @override
  void initState() {
    super.initState();
    fetchFriendRequests();
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    final url = Uri.parse("http://10.39.5.40:3000/api/users/search?fullname=$query");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      setState(() {
        searchResults = results.where((user) => user['id'] != widget.currentUserId).toList();
      });
    }
  }

  Future<void> fetchFriendRequests() async {
    final response = await http.get(Uri.parse(
        'http://10.39.5.40:3000/api/friends/requests?receiver_id=${widget.currentUserId}'));

    if (response.statusCode == 200) {
      setState(() {
        friendRequests = json.decode(response.body);
      });
    }
  }

  Future<void> acceptFriendRequest(int senderId) async {
    final response = await http.put(
      Uri.parse('http://10.39.5.40:3000/api/friends/accept'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sender_id": senderId,
        "receiver_id": widget.currentUserId,
      }),
    );

    if (response.statusCode == 200) {
      fetchFriendRequests();
    }
  }

  Future<void> deleteFriendRequest(int senderId) async {
    final response = await http.delete(
      Uri.parse('http://10.39.5.40:3000/api/friends/delete'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sender_id": senderId,
        "receiver_id": widget.currentUserId,
      }),
    );

    if (response.statusCode == 200) {
      fetchFriendRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
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
              SizedBox(
                height: MediaQuery.of(context).padding.top + 10,
              ),
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
              const SizedBox(height: 10),
              // 🔹 แสดงรายการคำขอเป็นเพื่อน
              friendRequests.isNotEmpty
                  ? Expanded(
                      child: ListView.builder(
                        itemCount: friendRequests.length,
                        itemBuilder: (context, index) {
                          final friend = friendRequests[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: friend['profile_image'] != null
                                  ? NetworkImage('http://10.39.5.40:3000${friend['profile_image']}')
                                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                            ),
                            title: Text(friend['fullname']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => acceptFriendRequest(friend['id']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => deleteFriendRequest(friend['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : const Text("No friend requests", style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
