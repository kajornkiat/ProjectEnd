import 'package:flutter/material.dart';
import 'select.dart'; // นำเข้า SelectPage

class Tourist extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        // ทำให้กดได้
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SelectPage(category: 'tourist'), // ส่งข้อมูลประเภท food
            ),
          );
        },
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/tourist.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Container(
            alignment: Alignment.center, // ✅ จัดข้อความให้อยู่ตรงกลาง
            padding:
                EdgeInsets.symmetric(horizontal: 10), // ✅ ป้องกันขอบชิดเกินไป
            child: Text(
              'Tourist\nAttraction', // ✅ ทำให้ขึ้นบรรทัดใหม่
              textAlign: TextAlign.center, // ✅ จัดข้อความให้อยู่กึ่งกลางแนวนอน
              style: TextStyle(
                fontSize: 45, // ✅ ลดขนาดให้อ่านง่ายขึ้น
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3, // ✅ ปรับระยะห่างระหว่างบรรทัด
              ),
            ),
          ),
        ),
      ),
    );
  }
}
