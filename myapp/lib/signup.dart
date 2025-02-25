import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login.dart'; // Import login page to redirect after signup

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passController = TextEditingController();

  String? selectedGender;
  String? selectedDay;
  String? selectedMonth;
  String? selectedYear;

  final RegExp emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  final RegExp usernameRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)[A-Za-z\d]{1,20}$');
  final RegExp passwordRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)[A-Za-z\d]{8,10}$');

  Future<void> submitData(BuildContext context) async {
    final String username = usernameController.text.trim();
    final String password = passController.text.trim();

    //final RegExp usernameRegExp = RegExp(r'^[a-zA-Z0-9]{1,20}$');
    //final RegExp passwordRegExp = RegExp(r'^[a-zA-Z0-9]{8,10}$');

    if (!usernameRegExp.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Username must be 1-20 characters long and contain only letters or numbers.')),
      );
      return;
    }

    if (!passwordRegExp.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Password must be 8-10 characters long and contain only letters or numbers.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.39.5.31:3000/api/signup'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': emailController.text.trim(),
          'fullname': fullNameController.text.trim(),
          'gender': selectedGender ?? '',
          'birthdate': '$selectedYear-$selectedMonth-$selectedDay',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration successful.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        final errorResponse = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorResponse['message'] ?? 'Unable to register.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/signup.png"), // Adjust path
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(2.0, 2.0),
                          blurRadius: 8.0,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                  // Full Name Field
                  TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Email Field
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Username Field (limited to 20 characters)
                  TextField(
                    controller: usernameController,
                    maxLength: 20,
                    decoration: InputDecoration(
                      hintText: 'Username',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Password Field (limited to 10 characters)
                  TextField(
                    controller: passController,
                    obscureText: true,
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    hint: Text('Select Gender'),
                    items: ['Male', 'Female', 'Other']
                        .map((gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedGender = value;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Birthdate Dropdowns
                  Row(
                    children: [
                      // Day Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDay,
                          hint: Text('Day'),
                          items: List.generate(31, (index) {
                            return DropdownMenuItem(
                              value: (index + 1).toString().padLeft(2, '0'),
                              child: Text((index + 1).toString()),
                            );
                          }),
                          onChanged: (value) {
                            setState(() {
                              selectedDay = value;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // Month Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMonth,
                          hint: Text('Month'),
                          items: List.generate(12, (index) {
                            return DropdownMenuItem(
                              value: (index + 1).toString().padLeft(2, '0'),
                              child: Text((index + 1).toString()),
                            );
                          }),
                          onChanged: (value) {
                            setState(() {
                              selectedMonth = value;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // Year Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedYear,
                          hint: Text('Year'),
                          items: List.generate(100, (index) {
                            return DropdownMenuItem(
                              value: (2024 - index).toString(),
                              child: Text((2024 - index).toString()),
                            );
                          }),
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Sign Up Button
                  ElevatedButton(
                    onPressed: () {
                      submitData(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Color.fromARGB(255, 237, 205, 0),
                    ),
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
