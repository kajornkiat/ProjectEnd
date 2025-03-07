import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'views_admin.dart';
import 'dart:async';
import 'add_select.dart';

class SelectAdminPage extends StatefulWidget {
  final String category;

  SelectAdminPage({required this.category});

  @override
  _SelectAdminState createState() => _SelectAdminState();
}

class _SelectAdminState extends State<SelectAdminPage> {
  List<dynamic> places = [];
  List<dynamic> filteredPlaces = [];
  TextEditingController searchController = TextEditingController();
  final StreamController<void> _refreshController =
      StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    fetchPlaces();
    searchController.addListener(() {
      onSearchChanged(searchController.text);
    });
  }

  @override
  void dispose() {
    _refreshController.close(); // ✅ ปิด Stream เมื่อหน้าโดน dispose
    super.dispose();
  }

  Future<void> fetchPlaces() async {
    String baseUrl = 'http://192.168.242.162:3000/api';
    String url = '$baseUrl/${widget.category}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          places = data;
          filteredPlaces = data;
        });
        print('Response: ${response.body}');
      } else {
        print('Failed to load data');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredPlaces = List.from(places);
      });
    } else {
      setState(() {
        filteredPlaces = places.where((place) {
          final province = place['province'].toLowerCase();
          final name = place['name'].toLowerCase();
          final searchLower = query.toLowerCase();
          return province.contains(searchLower) || name.contains(searchLower);
        }).toList();
      });
    }
  }

  Future<void> _deletePlace(BuildContext context, int placeId) async {
    // แสดง Dialog ยืนยันการลบ
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Are you sure you want to delete this place?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        final response = await http.delete(
          Uri.parse(
              'http://192.168.242.162:3000/api/${widget.category}/$placeId'),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Place deleted successfully!")));
          fetchPlaces(); // รีเฟรชข้อมูลหลังจากลบ
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Failed to delete place")));
        }
      } catch (e) {
        print('Error deleting place: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("An error occurred while deleting the place")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: Icon(Icons.search, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: filteredPlaces.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(10.0),
              child: GridView.builder(
                itemCount: filteredPlaces.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  final place = filteredPlaces[index];
                  final List<dynamic> images = place['images'] ?? [];
                  final String imageUrl = images.isNotEmpty
                      ? 'http://192.168.242.162:3000${images[0]}' // เลือกภาพแรกในอาร์เรย์
                      : 'https://via.placeholder.com/150';

                  // ✅ แยกตัวแปรออกมาก่อน
                  final dynamic ratingData = place['averageRating'];
                  final double rating =
                      ratingData is num ? ratingData.toDouble() : 0.0;
                  final int reviewCount = (place['reviewCount'] as int?) ?? 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewsAdminPage(
                            category: widget.category,
                            imageUrl: List<String>.from(place['images']),
                            name: place['name'],
                            rating: rating, // ✅ ใช้ค่าที่ประกาศไว้
                            reviewCount: reviewCount, // ✅ ใช้ค่าที่ประกาศไว้
                            province: place['province'] ?? 'Unknown Province',
                            description: place['description'] ??
                                'No description available',
                            latitude: place['latitude'] ??
                                0.0, // เพิ่มข้อมูล latitude
                            longitude: place['longitude'] ??
                                0.0, // เพิ่มข้อมูล longitude
                            place_id: place['id'],
                            price: place['price'] ?? "ไม่ระบุ",
                            phone: place['phone'] ??
                                "", // เพิ่ม phone (ใช้ค่าเริ่มต้นหากไม่มี)
                            placetyp: place['placetyp'] ??
                                "", // เพิ่ม placetyp (ใช้ค่าเริ่มต้นหากไม่มี)
                            refreshCallback: () {
                              _refreshController
                                  .add(null); // ✅ อัปเดตค่าแบบเรียลไทม์
                            },
                          ),
                        ),
                      ).then((_) {
                        // ✅ ดึงข้อมูลจาก API ใหม่เมื่อย้อนกลับมา
                        fetchPlaces();
                      });
                    },
                    child: PlaceCard(
                      name: place['name'],
                      imageUrl: imageUrl,
                      rating: (place['averageRating'] as num?)?.toDouble() ??
                          0.0, // ⭐ เพิ่มตรงนี้
                      reviewCount: place['reviewCount'] ?? 0, // ⭐ เพิ่มตรงนี้
                      placeId: place['id'], // ส่ง placeId ไปยัง PlaceCard
                      onDelete: (placeId) =>
                          _deletePlace(context, placeId), // ส่งฟังก์ชันลบ
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // ✅ นำทางไปยังหน้า add_select.dart พร้อมส่งค่า category
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSelectPage(category: widget.category),
            ),
          );
        },
        child: Icon(Icons.add), // ไอคอนปุ่ม Add
        backgroundColor:
            const Color.fromARGB(255, 254, 194, 251), // สีพื้นหลังปุ่ม
      ),
    );
  }
}

class PlaceCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int placeId; // เพิ่ม placeId
  final Function(int) onDelete; // เพิ่มฟังก์ชันลบ

  PlaceCard({
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.placeId, // รับ placeId
    required this.onDelete, // รับฟังก์ชันลบ
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.network(
              imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(child: Icon(Icons.broken_image));
              },
            ),
            Positioned(
              left: 10,
              bottom: 40,
              right: 10, // ป้องกันไม่ให้ข้อความโดนตัดขอบ
              child: IntrinsicWidth(
                // ปรับขนาดตามเนื้อหาข้อความ
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 120, // จำกัดความกว้างสูงสุดของกล่องชื่อ
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2, // กำหนดให้แสดงได้สูงสุด 2 บรรทัด
                      overflow:
                          TextOverflow.ellipsis, // ถ้าข้อความยาวเกินให้แสดง ...
                      softWrap: true, // อนุญาตให้ขึ้นบรรทัดใหม่
                      textAlign: TextAlign.center, // จัดให้อยู่ตรงกลาง
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.yellow, size: 18),
                  SizedBox(width: 5),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                  SizedBox(width: 5),
                  Text(
                    "($reviewCount Reviews)",
                    style: TextStyle(
                        color: const Color.fromARGB(179, 255, 255, 255),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == "delete") {
                    onDelete(placeId); // เรียกฟังก์ชันลบ
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: "delete",
                    child: Text("Delete Place"),
                  ),
                  PopupMenuItem(
                    value: "cancel",
                    child: Text("Cancel"),
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
