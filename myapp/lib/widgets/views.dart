import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ViewsPage extends StatefulWidget {
  final String category;
  final int place_id;
  final String imageUrl;
  final String name;
  final String province;
  final String description;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final VoidCallback refreshCallback;

  ViewsPage({
    required this.category,
    required this.place_id,
    required this.imageUrl,
    required this.name,
    required this.province,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.refreshCallback,
  });

  @override
  _ViewsPageState createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> {
  List reviews = [];
  double averageRating = 0.0;
  int reviewCount = 0;
  TextEditingController reviewController = TextEditingController();
  late IO.Socket socket;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    getCurrentUserId();
    fetchReviews();
    setupSocket();
  }

  @override
  void dispose() {
    socket.off('newReview');
    socket.off('deleteReview');
    socket.dispose(); // ปิดการเชื่อมต่อ
    reviewController.dispose();
    super.dispose();
  }

  void setupSocket() {
    socket = IO.io('http://192.168.242.162:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    // ✅ ฟัง event "newReview" และเพิ่มรีวิวใหม่
    socket.on('newReview', (data) {
      if (data['category'] == widget.category &&
          data['place_id'] == widget.place_id) {
        if (mounted) {
          setState(() {
            reviews.insert(0, data);
            averageRating = ((averageRating * reviewCount) + data['rating']) /
                (reviewCount + 1);
            reviewCount++;
          });
          widget.refreshCallback();
        }
      }
    });

    // ✅ ฟัง event "deleteReview" และลบรีวิวที่ตรงกับ ID
    socket.on('deleteReview', (reviewId) {
      if (mounted) {
        setState(() {
          reviews.removeWhere((review) => review['id'] == reviewId);
          if (reviews.isNotEmpty) {
            final totalRating = reviews.fold<double>(0.0, (sum, review) {
              final rating = review['rating'];
              return sum + (rating is num ? rating : 0);
            });

            averageRating = totalRating / reviews.length;
          } else {
            averageRating = 0.0;
          }
          reviewCount = reviews.length;
        });
        widget.refreshCallback();
      }
    });
  }

  Future<void> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId =
        prefs.getInt('user_id'); // ดึง user_id จาก SharedPreferences

    if (storedUserId != null) {
      setState(() {
        currentUserId = storedUserId;
      });
    } else {
      print("❌ No user ID found in SharedPreferences");
    }
  }

  Future<void> fetchReviews() async {
    final response = await http.get(Uri.parse(
        'http://192.168.242.162:3000/api/reviews/${widget.category}/${widget.place_id}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          reviews = data['reviews'] ?? [];
          averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
        });
        widget.refreshCallback();
      } // 📌 อัปเดตหน้า select.dart
      print("Fetched reviews: $reviews"); // ✅ ตรวจสอบค่าที่ได้จาก API
    } else {
      print("Error fetching reviews: ${response.statusCode}");
    }
  }

  Future<void> addReview(String reviewText, double rating) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // ✅ ดึง Token จาก SharedPreferences

    if (token == null) {
      print("❌ No token found. Please log in.");
      return;
    }

    final url = Uri.parse("http://192.168.242.162:3000/api/reviews");
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // ✅ ส่ง Token ไปที่ API
      },
      body: jsonEncode({
        "category": widget.category,
        "place_id": widget.place_id,
        "review": reviewText,
        "rating": rating,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Review added successfully!");
      reviewController.clear();
      fetchReviews(); // รีเฟรช UI
      socket.emit("newReview"); // 🔥 แจ้งเซิร์ฟเวอร์ให้อัปเดตรีวิวแบบ Real-Time
      widget.refreshCallback(); // 📌 อัปเดตหน้า select.dart
    } else {
      print("❌ Failed to add review: ${response.body}");
    }
  }

  void _showReviewPopup() {
    double userRating = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reviewController,
                decoration: InputDecoration(
                  hintText: 'Write your review here...',
                ),
              ),
              SizedBox(height: 16),
              Text('Rate this place:'),
              RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemBuilder: (context, _) => Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  userRating = rating;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (reviewController.text.isNotEmpty) {
                  addReview(reviewController.text, userRating);
                  Navigator.pop(context);
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteReview(int reviewId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // ✅ ดึง Token จาก SharedPreferences

    if (token == null) {
      print("❌ No token found. Please log in.");
      return;
    }

    final url = Uri.parse("http://192.168.242.162:3000/api/reviews/$reviewId");
    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token", // ✅ ส่ง Token ไปที่ API
      },
    );

    if (response.statusCode == 200) {
      print("✅ Review deleted successfully!");
      fetchReviews(); // รีเฟรช UI
      socket.emit(
          "deleteReview"); // 🔥 แจ้งเซิร์ฟเวอร์ให้อัปเดตรีวิวแบบ Real-Time
      widget.refreshCallback(); // 📌 อัปเดตหน้า select.dart
    } else {
      print("❌ Failed to delete review: ${response.body}");
    }
  }

  void updateRatingAndReviews(double newRating, int newReviewCount) {
    Navigator.pop(context, {
      'averageRating': newRating,
      'reviewCount': newReviewCount,
    });
  }

  void _openMap() async {
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}";
    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication);
    } else {
      throw 'ไม่สามารถเปิด Google Maps ได้';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌆 ส่วนแสดงรูปภาพของสถานที่
                SizedBox(
                  height: 500,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        child: Image.network(
                          widget.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(child: Icon(Icons.broken_image));
                          },
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 40,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: Colors.white, size: 30),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.name,
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.yellow, size: 18),
                              SizedBox(width: 5),
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 5),
                              Text("($reviewCount Reviews)",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(widget.province,
                              style:
                                  TextStyle(fontSize: 16, color: Colors.blue)),
                          TextButton(
                            onPressed: _openMap,
                            child: Text("Show map",
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(widget.description),
                      SizedBox(height: 10),
                      Divider(),
                      Text("Reviews",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          final isOwner = review['user_id'] ==
                              currentUserId; // เช็คว่าเป็นเจ้าของรีวิวไหม
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: review['profile_image'] != null
                                  ? NetworkImage(
                                      'http://192.168.242.162:3000${review['profile_image']}')
                                  : AssetImage('assets/default_profile.png')
                                      as ImageProvider,
                              backgroundColor: Colors.grey[300],
                            ),
                            title: Text(review['username'] ?? 'Unknown User'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(
                                    review['rating'],
                                    (index) => Icon(Icons.star,
                                        color: Colors.yellow, size: 16),
                                  ),
                                ),
                                Text(review['review']),
                              ],
                            ),
                            trailing: isOwner
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == "delete") {
                                        deleteReview(review['id']);
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
                                : null, // 🔹 ถ้าไม่ใช่เจ้าของรีวิว จะไม่แสดงปุ่ม
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ✍🏻 ช่องป้อนรีวิวติดด้านล่างหน้าจอ
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showReviewPopup,
              child: Icon(Icons.reviews),
            ),
          ),
        ],
      ),
    );
  }
}
