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
    if (pickedFiles != null && pickedFiles.length <= 5) {
      setState(() {
        _images = pickedFiles.map((file) => File(file.path)).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("อัปโหลดได้สูงสุด 5 รูปเท่านั้น")));
    }
  }

  Future<void> _submitForm() async {
    provinceController.text = selectedProvince ?? '';
    if (_formKey.currentState!.validate()) {
      // ตรวจสอบว่าฟิลด์ที่จำเป็นไม่เป็นค่าว่าง
      if (provinceController.text.isEmpty ||
          nameController.text.isEmpty ||
          latitudeController.text.isEmpty ||
          longitudeController.text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบถ้วน")));
        return;
      }

      // ตรวจสอบว่าฟิลด์ dropdown ถูกเลือกหรือไม่
      if (selectedProvince == null ||
          selectedPrice == null ||
          selectedtype == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("กรุณาเลือกจังหวัด, ประเภทสถานที่, และเรทราคา")));
        return;
      }

      // ตรวจสอบว่า latitude และ longitude เป็นตัวเลข
      try {
        double.parse(latitudeController.text);
        double.parse(longitudeController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("กรุณากรอกละติจูดและลองจิจูดเป็นตัวเลข")));
        return;
      }

      // ส่งข้อมูลไปยังเซิร์ฟเวอร์
      var uri = Uri.parse('http://192.168.242.162:3000/api/${widget.category}');
      var request = http.MultipartRequest(
        widget.placeId == null
            ? 'POST'
            : 'PUT', // ใช้ POST สำหรับเพิ่ม, PUT สำหรับแก้ไข
        uri,
      );

      request.fields['province'] = provinceController.text;
      request.fields['name'] = nameController.text;
      request.fields['description'] = descriptionController.text;
      request.fields['latitude'] =
          double.parse(latitudeController.text).toString();
      request.fields['longitude'] =
          double.parse(longitudeController.text).toString();
      request.fields['phone'] = phoneController.text;
      request.fields['price'] = selectedPrice ?? "";
      request.fields['placetyp'] = selectedtype ?? "";

      // หากเป็นการแก้ไขข้อมูล ส่ง place_id ไปด้วย
      if (widget.placeId != null) {
        request.fields['place_id'] = widget.placeId.toString();
      }

      // เพิ่มรูปภาพ (หากมี)
      for (var image in _images) {
        print('Image path: ${image.path}');
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
        print('Error response: $responseBody'); // แสดงข้อผิดพลาดจากเซิร์ฟเวอร์
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("เกิดข้อผิดพลาดในการเพิ่มข้อมูล")));
      }
    }
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
                Text("อัปโหลดรูป (สูงสุด 5 รูป)",
                    style: TextStyle(fontSize: 16)),
                ElevatedButton(onPressed: _pickImages, child: Text("เลือกภาพ")),
                Wrap(
                  children: _images
                      .map((image) => Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Image.file(image,
                                width: 80, height: 80, fit: BoxFit.cover),
                          ))
                      .toList(),
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
