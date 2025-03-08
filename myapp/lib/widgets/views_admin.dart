import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'add_select.dart';

class ViewsAdminPage extends StatefulWidget {
  final String category;
  final int place_id;
  final List<String> imageUrl;
  final String name;
  final String province;
  final String description;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String price; // เพิ่ม price
  final String phone; // เพิ่ม phone
  final String placetyp; // เพิ่ม placetyp
  final VoidCallback refreshCallback;

  ViewsAdminPage({
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
    required this.price, // เพิ่ม price
    required this.phone, // เพิ่ม phone
    required this.placetyp, // เพิ่ม placetyp
    required this.refreshCallback,
  });

  @override
  _ViewsAdminPageState createState() => _ViewsAdminPageState();
}

class _ViewsAdminPageState extends State<ViewsAdminPage> {
  List reviews = [];
  double averageRating = 0.0;
  int reviewCount = 0;
  TextEditingController reviewController = TextEditingController();
  late IO.Socket socket;
  int? currentUserId;
  bool isAdmin = false;
  int _currentPage = 0;
  List<String> _imageUrls = [];
  final PageController _pageController = PageController(initialPage: 0);
  bool _isExpanded = false;

  bool _needsExpansion(String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 16,
          color: const Color.fromARGB(255, 135, 135, 135),
        ),
      ),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(
        maxWidth: MediaQuery.of(context).size.width -
            32); // 32 คือ padding ทั้งสองด้าน
    return textPainter.didExceedMaxLines;
  }

  @override
  void initState() {
    super.initState();
    getCurrentUserId();
    fetchReviews();
    fetchPlaceDetails();
    setupSocket();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    final storedStatus = prefs.getString('status');

    if (storedUserId != null) {
      setState(() {
        currentUserId = storedUserId;
        isAdmin = (storedStatus == 'admin');
      });
    } else {
      print("❌ No user ID found in SharedPreferences");
    }
  }

  Future<void> fetchPlaceDetails() async {
    final response = await http.get(Uri.parse(
        'http://192.168.242.162:3000/api/place/${widget.category}/${widget.place_id}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _imageUrls = List<String>.from(data['images']); // อัปเดตรายการรูปภาพ
        });
      }
      print("Fetched place details: $data");
    } else {
      print("Error fetching place details: ${response.statusCode}");
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

  Future<void> deleteReview(int reviewId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // ดึง Token

    if (token == null) {
      print("❌ No token found. Please log in.");
      return;
    }

    final url =
        Uri.parse("http://192.168.242.162:3000/api/admin/reviews/$reviewId");
    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      print("✅ Review deleted successfully!");
      fetchReviews();
      socket.emit("deleteReview", reviewId);
      widget.refreshCallback();
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
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _imageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        physics:
                            const PageScrollPhysics(), // ตั้งค่าให้สามารถสไลด์ได้
                        allowImplicitScrolling: true, // อนุญาตให้สไลด์วนลูป
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                            child: Image.network(
                              'http://192.168.242.162:3000${_imageUrls[index]}', // ใช้ URL เต็ม
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(child: Icon(Icons.broken_image));
                              },
                            ),
                          );
                        },
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
                      // แสดงตัวนับรูปภาพ (เช่น 1/5)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_currentPage + 1}/${_imageUrls.length}", // ใช้ _imageUrls.length แทน widget.imageUrl.length
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
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
                          // Province (ป้องกันล้นจอ)
                          Expanded(
                            child: Text(
                              widget.province,
                              style:
                                  TextStyle(fontSize: 16, color: Colors.orange),
                              overflow: TextOverflow
                                  .ellipsis, // ตัดข้อความที่ยาวเกินด้วย ...
                              maxLines: 2, // จำกัดให้แสดงเพียง 1 บรรทัด
                            ),
                          ),

                          // ระยะห่างระหว่าง province กับ Reviews
                          SizedBox(width: 16), // เพิ่มระยะห่าง

                          // Reviews และ Show Map
                          Row(
                            children: [
                              // Rating
                              Icon(Icons.star, color: Colors.yellow, size: 18),
                              SizedBox(width: 5),
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 5),
                              Text("($reviewCount Reviews)",
                                  style: TextStyle(color: Colors.grey)),
                              SizedBox(
                                  width:
                                      10), // ระยะห่างระหว่าง Reviews และ Show Map

                              // Show Map
                              IconButton(
                                onPressed: _openMap,
                                icon: Icon(Icons.map, color: Colors.orange),
                                tooltip: "Show Map",
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.name,
                              style: TextStyle(
                                  fontSize: 22,
                                  color: const Color.fromARGB(255, 0, 0, 0)),
                              overflow: TextOverflow
                                  .ellipsis, // ตัดข้อความที่ยาวเกินด้วย ...
                              maxLines: 4, // จำกัดให้แสดงเพียง 1 บรรทัด
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded; // สลับสถานะการขยาย
                          });
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color.fromARGB(255, 135, 135, 135),
                              ),
                              maxLines: _isExpanded ? null : 5, // จำกัดบรรทัด
                              overflow: _isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow
                                      .ellipsis, // แสดง ... เมื่อถูกตัด
                            ),
                            if (!_isExpanded &&
                                _needsExpansion(widget
                                    .description)) // แสดงปุ่ม "เพิ่มเติม" เมื่อข้อความถูกตัด
                              Text(
                                'เพิ่มเติม...',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (_isExpanded) // แสดงปุ่ม "แสดงน้อยลง" เมื่อข้อความถูกขยาย
                              Text(
                                'แสดงน้อยลง',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // แสดงข้อมูล price, phone, และ placetyp
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.attach_money,
                              color: Colors.orange, size: 16),
                          SizedBox(width: 5),
                          Text(
                            widget.price ?? "ไม่ระบุ",
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.orange, size: 16),
                          SizedBox(width: 5),
                          Text(
                            widget.phone ?? "ไม่ระบุ",
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.store, color: Colors.orange, size: 16),
                          SizedBox(width: 5),
                          Text(
                            widget.placetyp ?? "ไม่ระบุ",
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
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
                                  : AssetImage(
                                          'assets/images/default_profile.png')
                                      as ImageProvider,
                              backgroundColor: Colors.grey[300],
                            ),
                            title: Text(
                              review['fullname'],
                              maxLines: 1, // จำกัดให้แสดงเพียง 1 บรรทัด
                              overflow: TextOverflow
                                  .ellipsis, // แสดง ... หากข้อความยาวเกิน
                              style: TextStyle(
                                fontSize: 16, // ปรับขนาดฟอนต์ตามต้องการ
                                fontWeight: FontWeight
                                    .bold, // ปรับน้ำหนักฟอนต์ตามต้องการ
                              ),
                            ),
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
                            trailing: isAdmin
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
          // ในส่วนของ FloatingActionButton ที่ใช้สำหรับแก้ไข
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                // ส่งข้อมูลปัจจุบันไปยังหน้า AddSelectPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddSelectPage(
                      category: widget.category,
                      placeId: widget
                          .place_id, // ส่ง place_id เพื่อระบุว่ากำลังแก้ไขข้อมูล
                      initialProvince: widget.province,
                      initialName: widget.name,
                      initialDescription: widget.description,
                      initialLatitude: widget.latitude.toString(),
                      initialLongitude: widget.longitude.toString(),
                      initialPhone: widget.phone,
                      initialPrice: widget.price,
                      initialPlacetyp: widget.placetyp,
                      initialImages: widget.imageUrl,
                    ),
                  ),
                ).then((_) {
                  // เมื่อกลับมาจากหน้าแก้ไข ให้รีเฟรชข้อมูล
                  widget.refreshCallback();
                });
              },
              child: Icon(Icons.edit),
            ),
          ),
        ],
      ),
    );
  }
}
