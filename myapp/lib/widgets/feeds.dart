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
            image: DecorationImage(
              image: AssetImage('assets/images/9669.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              'Feeds',
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
