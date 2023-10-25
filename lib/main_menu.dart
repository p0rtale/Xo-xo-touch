import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:xo_xo_touch/error_notifier.dart';

class MainMenu extends StatelessWidget {
  final Socket requestSocket;
  final Stream<Uint8List> socketStream;
  final storage = const FlutterSecureStorage();

  const MainMenu(this.requestSocket, this.socketStream, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/mainmenu_background.png', fit: BoxFit.fill),
          ),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 90,
              height: 90,
              child: ElevatedButton(
                onPressed: () {
                  // Navigator.pushNamed(context, '/room');
                  // Navigator.of(context).pushNamedAndRemoveUntil('/answers', (route) => false);

                  // Enter game
                  final token = storage.read(key: "jwtToken");
                  token.then((token) {
                    debugPrint("[INFO] Enter game token: $token");

                    if (token == null) {
                      debugPrint("[INFO] No jwtToken");
                      createErrorNotifier(context, "User is not logged in");
                      return;
                    }

                    var request = {
                      "method": "entergame",
                      "token": token,
                    };
                    var jsonRequest = jsonEncode(request);
                    requestSocket.add(utf8.encode("$jsonRequest\n"));

                    StreamSubscription? subscription;
                    subscription = socketStream.listen((event) {
                      var data = utf8.decode(event).replaceAll("\n", "");
                      var jsonData = jsonDecode(data);
                      debugPrint("[DEBUG] Enter game jsonData: $jsonData");
                      var status = jsonData["status"];

                      if (status != 200) {
                        debugPrint("[WARN] Enter game bad status: $status");
                        createErrorNotifier(context, "SERVER IS DURAK");
                        return;
                      }

                      var usernames = jsonData["usernames"];
                      debugPrint("[INFO] Enter game usernames: $usernames");

                      Navigator.of(context).pushNamedAndRemoveUntil('/room', (route) => false, arguments: usernames);

                      subscription!.cancel();
                    });
                  });
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onBackground,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.all(0),
                ),
                child: Image.asset(
                  "assets/images/red_nose.png",
                  alignment: Alignment.center,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          Align(
              alignment: const Alignment(-0.92, 0.97),
              child: SizedBox(
                  width: 150, // <-- Your width
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/authorization');
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(255, 44, 183, 100),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        padding: const EdgeInsets.all(12)
                    ),
                    child: const Text('Вход/Регистрация', style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    )),
                  )
              )
          )
        ],
      ),
    );
  }
}
