import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class ViewsPage extends StatefulWidget {
  final int place_id;
  final String imageUrl;
  final String name;
  final String province;
  final String description;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;

  ViewsPage({
    required this.place_id,
    required this.imageUrl,
    required this.name,
    required this.province,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
  });

  @override
  _ViewsPageState createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> {
  List reviews = [];
  double averageRating = 0.0;
  int reviewCount = 0;
  TextEditingController reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  Future<void> fetchReviews() async {
    final response = await http.get(
        Uri.parse('http://192.168.242.68:3000/api/reviews/${widget.place_id}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        reviews = data['reviews'] ?? [];
        averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
      });
    } else {
      print("Error fetching reviews: ${response.statusCode}");
    }
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
      body: SingleChildScrollView(
        // ✅ ห่อทั้งหน้าให้เลื่อนขึ้นลงได้
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌆 ส่วนแสดงรูปภาพของสถานที่
            SizedBox(
              height: 500, // ✅ กำหนดความสูงให้รูปภาพ
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
                      icon:
                          Icon(Icons.arrow_back, color: Colors.white, size: 30),
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
                  // 🏷 ชื่อสถานที่
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

                  // 📌 จังหวัด และ Show Map (อยู่ขวาสุด)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.province,
                          style: TextStyle(fontSize: 16, color: Colors.blue)),
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
                  // 📜 คำอธิบายสถานที่
                  Text(widget.description),
                  SizedBox(height: 10),

                  Divider(),

                  // 📝 หัวข้อ Reviews
                  Text("Reviews",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  // 🔄 แสดงรายการรีวิว
                  ListView.builder(
                    shrinkWrap: true, // ✅ ให้มันขยายตามเนื้อหา
                    physics:
                        NeverScrollableScrollPhysics(), // ✅ ปิดสกรอล์ในตัว ListView
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return ListTile(
                        leading:
                            CircleAvatar(child: Icon(Icons.person, size: 20)),
                        title: Text(review['username']),
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
                      );
                    },
                  ),

                  // ✍🏻 ช่องป้อนรีวิว
                  TextField(
                    controller: reviewController,
                    decoration: InputDecoration(
                      hintText: "Write a review...",
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send, color: Colors.blue),
                        onPressed: () {
                          print("Review submitted!");
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
