import 'package:flutter/material.dart';
import 'feedsviews.dart';

class Feeds extends StatelessWidget {
  final Map<String, dynamic> userData; // ✅ เปลี่ยนเป็น userData
  Feeds({required this.userData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FeedsviewsPage(userData: userData),
            ),
          );
        },
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 236, 184, 28), // ✅ พื้นหลังสีเหลืองแทนรูปภาพ
            borderRadius: BorderRadius.circular(30),
            //border: Border.all(color: Colors.blue, width: 3), // ✅ ขอบสีน้ำเงิน
          ),
          child: Center(
            child: Text(
              'Feeds',
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white, // ✅ เปลี่ยนเป็นสีขาว
                shadows: [
                  Shadow(
                    offset: Offset(2, 2), // ✅ ทำให้เหมือนขอบสีดำ
                    blurRadius: 2,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
