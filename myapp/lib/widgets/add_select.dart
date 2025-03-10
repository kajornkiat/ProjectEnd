import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddSelectPage extends StatefulWidget {
  final String category;
  final int? placeId; // เพิ่ม placeId เพื่อระบุว่ากำลังแก้ไขข้อมูล
  final String? initialProvince;
  final String? initialName;
  final String? initialDescription;
  final String? initialLatitude;
  final String? initialLongitude;
  final String? initialPhone;
  final String? initialPrice;
  final String? initialPlacetyp;
  final List<String>? initialImages;

  AddSelectPage({
    required this.category,
    this.placeId,
    this.initialProvince,
    this.initialName,
    this.initialDescription,
    this.initialLatitude,
    this.initialLongitude,
    this.initialPhone,
    this.initialPrice,
    this.initialPlacetyp,
    this.initialImages,
  });

  @override
  _AddSelectPageState createState() => _AddSelectPageState();
}

class _AddSelectPageState extends State<AddSelectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController provinceController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String? selectedPrice;
  String? selectedProvince;
  String? selectedtype;
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.placeId != null) {
      provinceController.text = widget.initialProvince ?? '';
      nameController.text = widget.initialName ?? '';
      descriptionController.text = widget.initialDescription ?? '';
      latitudeController.text = widget.initialLatitude ?? '';
      longitudeController.text = widget.initialLongitude ?? '';
      phoneController.text = widget.initialPhone ?? '';
      selectedPrice = widget.initialPrice ?? priceOptions[0]; // ตั้งค่าเริ่มต้น
      selectedtype = widget.initialPlacetyp ??
          categoryTypes[widget.category]![0]; // ตั้งค่าเริ่มต้น
      selectedProvince =
          widget.initialProvince ?? provinceOptions[0]; // ตั้งค่าเริ่มต้น
    } else {
      selectedProvince =
          provinceOptions[0]; // ตั้งค่าเริ่มต้นสำหรับการเพิ่มข้อมูลใหม่
      selectedPrice =
          priceOptions[0]; // ตั้งค่าเริ่มต้นสำหรับการเพิ่มข้อมูลใหม่
      selectedtype = categoryTypes[widget.category]![
          0]; // ตั้งค่าเริ่มต้นสำหรับการเพิ่มข้อมูลใหม่
    }
  }

  final List<String> provinceOptions = [
    "Bangkok(กรุงเทพมหานคร)",
    "Chiang Mai(เชียงใหม่)",
    "Phuket(ภูเก็ต)",
    "Chonburi(ชลบุรี)",
    "Khon Kaen(ขอนแก่น)",
    "Nakhon Ratchasima(นครราชสีมา)",
    "Samut Prakan(สมุทรปราการ)",
    "Udon Thani(อุดรธานี)",
    "Surat Thani(สุราษฎร์ธานี)",
    "Rayong(ระยอง)",
    "Nonthaburi(นนทบุรี)",
    "Pathum Thani(ปทุมธานี)",
    "Ayutthaya(อยุธยา)",
    "Songkhla(สงขลา)",
    "Pattani(ปัตตานี)",
    "Trang(ตรัง)",
    "Ubon Ratchathani(อุบลราชธานี)",
    "Roi Et(ร้อยเอ็ด)",
    "Loei(เลย)",
    "Nakhon Si Thammarat(นครศรีธรรมราช)",
    "Sukhothai(สุโขทัย)",
    "Lampang(ลําปาง)",
    "Saraburi(สระบุรี)",
    "Mae Hong Son(แม่ฮ่องสอน)",
    "Tak(ตาก)"
  ];

  final Map<String, List<String>> categoryTypes = {
    "food": ["ร้านอาหาร", "คาเฟ่", "สตรีทฟู้ด", "ร้านบุฟเฟ่ต์"],
    "hotel": ["โรงแรม", "รีสอร์ท", "โฮสเทล", "เกสต์เฮาส์"],
    "tourist": [
      "สถานที่ทางประวัติศาสตร์",
      "อุทยานแห่งชาติ",
      "พิพิธภัณฑ์",
      "ชายหาด"
    ]
  };

  final List<String> priceOptions = [
    "ต่ำกว่า 100 บาท",
    "100-500 บาท",
    "500-1000 บาท",
    "มากกว่า 1000 บาท"
  ];

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)).toList());
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // ตรวจสอบว่าฟิลด์ที่จำเป็นไม่เป็นค่าว่าง
      if (nameController.text.isEmpty ||
          latitudeController.text.isEmpty ||
          longitudeController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("กรุณากรอกชื่อสถานที่, ละติจูด, และลองจิจูด")));
        return;
      }

      // ส่งคำขอ
      var uri = Uri.parse('http://192.168.242.162:3000/api/${widget.category}');
      var request = http.MultipartRequest(
        widget.placeId == null ? 'POST' : 'PUT',
        uri,
      );

      // เพิ่มฟิลด์ที่จำเป็น
      request.fields['province'] = selectedProvince ?? '';
      request.fields['name'] = nameController.text;
      request.fields['latitude'] = latitudeController.text;
      request.fields['longitude'] = longitudeController.text;
      request.fields['description'] = descriptionController.text;
      request.fields['phone'] = phoneController.text;
      request.fields['price'] = selectedPrice ?? "";
      request.fields['placetyp'] = selectedtype ?? "";

      // เพิ่ม place_id เมื่ออยู่ในโหมดแก้ไขข้อมูล
      if (widget.placeId != null) {
        request.fields['place_id'] = widget.placeId.toString();
      }

      // เพิ่มรูปภาพ
      for (var image in _images) {
        request.files
            .add(await http.MultipartFile.fromPath('images', image.path));
      }

      // ส่งคำขอและตรวจสอบผลลัพธ์
      var response = await request.send();
      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("เพิ่มข้อมูลเรียบร้อย!")));
        Navigator.pop(context);
      } else {
        var responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("เกิดข้อผิดพลาด: $responseBody")));
      }
    }
  }

  Future<List<String>> _fetchImages(int placeId) async {
    final response = await http.get(Uri.parse(
        'http://192.168.242.162:3000/api/${widget.category}/$placeId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['images']);
    } else {
      throw Exception('Failed to load images');
    }
  }

  Future<void> _deleteImage(int placeId, String imageUrl) async {
    final response = await http.delete(
      Uri.parse(
          'http://192.168.242.162:3000/api/${widget.category}/$placeId/images'),
      body: jsonEncode({'imageUrl': imageUrl}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ลบรูปเรียบร้อย')));
      setState(() {}); // รีเฟรช UI
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบรูป')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index); // ลบรูปที่ index ที่ระบุ
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.category}')),
      body: Container(
        padding: EdgeInsets.all(16.0),
        color: Colors.lightGreen[100],
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(nameController, "ชื่อสถานที่"),
                _buildTextField(descriptionController, "คำอธิบาย", maxLines: 3),
                _buildDropdown("จังหวัด", provinceOptions, (value) {
                  setState(() => selectedProvince = value);
                }),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(latitudeController, "ละติจูด")),
                    SizedBox(width: 8),
                    Expanded(
                        child:
                            _buildTextField(longitudeController, "ลองจิจูด")),
                  ],
                ),
                _buildTextField(phoneController, "เบอร์โทรศัพท์"),
                if (categoryTypes.containsKey(widget.category))
                  _buildDropdown(
                      "ประเภทของสถานที่", categoryTypes[widget.category]!,
                      (value) {
                    setState(() => selectedtype = value);
                  }),
                _buildDropdown("เรทราคา", priceOptions, (value) {
                  setState(() => selectedPrice = value);
                }),
                SizedBox(height: 10),
                Text("อัปโหลดรูป", style: TextStyle(fontSize: 16)),
                ElevatedButton(onPressed: _pickImages, child: Text("เลือกภาพ")),
                Wrap(
                  children: [
                    // แสดงรูปจาก API (ถ้ามี)
                    if (widget.placeId != null)
                      FutureBuilder<List<String>>(
                        future: _fetchImages(widget.placeId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return Text('เกิดข้อผิดพลาด: ${snapshot.error}');
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return SizedBox.shrink(); // ไม่แสดงอะไรถ้าไม่มีรูป
                          } else {
                            return Wrap(
                              children: snapshot.data!.map((imageUrl) {
                                return Stack(
                                  children: [
                                    Image.network(
                                      'http://192.168.242.162:3000$imageUrl',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            color:
                                                Colors.white, // สีไอคอนเป็นขาว
                                            size: 20, // ปรับขนาดไอคอนให้เล็กลง
                                            shadows: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.5), // สีเงา
                                                offset: Offset(
                                                    2, 2), // ตำแหน่งเงา (x, y)
                                                blurRadius: 1, // ความเบลอของเงา
                                              ),
                                            ],
                                          ),
                                          padding: EdgeInsets
                                              .zero, // ลบ padding ของ IconButton
                                          constraints:
                                              BoxConstraints(), // ลบ constraints เพื่อให้ขนาดเล็กลง
                                          onPressed: () => _deleteImage(
                                              widget.placeId!, imageUrl),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          }
                        },
                      ),
                    // แสดงรูปที่ยังไม่ได้บันทึก
                    ..._images.asMap().entries.map((entry) {
                      int index = entry.key; // ดึง index ของรูป
                      File image = entry.value; // ดึงไฟล์รูป
                      return Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Stack(
                          children: [
                            Image.file(
                              image,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.white, // สีไอคอนเป็นขาว
                                    size: 20, // ปรับขนาดไอคอนให้เล็กลง
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.5), // สีเงา
                                        offset:
                                            Offset(2, 2), // ตำแหน่งเงา (x, y)
                                        blurRadius: 1, // ความเบลอของเงา
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets
                                      .zero, // ลบ padding ของ IconButton
                                  constraints:
                                      BoxConstraints(), // ลบ constraints เพื่อให้ขนาดเล็กลง
                                  onPressed: () => _removeImage(
                                      index), // ลบรูปที่ index ที่ระบุ
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('บันทึกข้อมูล'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'กรุณากรอกข้อมูล';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(
      String label, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          filled: true,
          fillColor: Colors.white,
        ),
        items: options.map((option) {
          return DropdownMenuItem(value: option, child: Text(option));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
