import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthorizationScreen extends StatefulWidget {
  final Socket? requestSocket;
  final Stream<Uint8List>? socketStream;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  const AuthorizationScreen({Key? key, this.requestSocket, this.socketStream}) : super(key: key);

  @override
  State<AuthorizationScreen> createState() => _AuthorizationScreenState();
}

class _AuthorizationScreenState extends State<AuthorizationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _showPassword = false;

  Future<void> registerOrLoginUser(bool registerOrLogin) async {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Processing Data',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.yellow.shade300,
      ));

      var userData = {
        "username": loginController.text,
        "password": passwordController.text,
      };

      const errorMess = {
        409: "User is already registered",
        401: "User is not registered",
        403: "User is already logged in"
      };

      String requestStr;
      if (registerOrLogin) {
        requestStr = "REGISTER";
      } else {
        requestStr = "LOGIN";
      }
      widget.requestSocket!.add(utf8.encode("$requestStr ${jsonEncode(userData)}\n"));

      StreamSubscription? subscription;
      subscription = widget.socketStream!.listen((event) {
        var data = utf8.decode(event).replaceAll("\n", r"\n");
        var jsonData = jsonDecode(data);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (jsonData["status"] != 200) { // ERROR!
          debugPrint("$requestStr failed, status: ${jsonData["status"]}");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Error: ${errorMess[jsonData["status"]]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            ),
            backgroundColor: Colors.red.shade300,
          ));
        } else { // EVERYTHING IS OK!
          String jwtToken = jsonDecode(data)["token"];
          widget.storage.write(key: 'jwtToken', value: jwtToken);
          debugPrint("Recieved jwtToken: $jwtToken");
          Navigator.pushNamed(context, '/mainmenu');
        }
        subscription!.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white30,
      body: Form(
        key: _formKey,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: size.width * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: loginController,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Please enter at least 1 character for your login";
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      cursorColor: Colors.black,
                      decoration: InputDecoration(
                        hintText: "Логин",
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.03),
                    TextFormField(
                      obscureText: !_showPassword,
                      controller: passwordController,
                      validator: (String? value) {
                        if (value!.isEmpty) {
                          return "Please enter at least 1 character for your password";
                        }
                        return null;
                      },
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        hintText: "Пароль",
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                          child: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.06),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          registerOrLoginUser(true);
                        },
                        style: ElevatedButton.styleFrom(
                            primary: Colors.indigo,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15)),
                        child: const Text(
                          "Регистрация",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.03),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          registerOrLoginUser(false);
                        },
                        style: ElevatedButton.styleFrom(
                            primary: Colors.white70,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15)),
                        child: const Text(
                          "Вход",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}