import 'package:flutter/material.dart';
import 'select_admin.dart'; // นำเข้า SelectPage

class FoodAdmin extends StatelessWidget {
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
                  SelectAdminPage(category: 'food'), // ส่งข้อมูลประเภท food
            ),
          );
        },
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/2.png'),
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              'FoodAdmin',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 9, 239, 209),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
