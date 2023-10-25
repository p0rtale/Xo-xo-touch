import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xo_xo_touch/room.dart';

import 'package:xo_xo_touch/answers.dart';
import 'package:xo_xo_touch/authorization.dart';
import 'package:xo_xo_touch/main_menu.dart';
import 'package:xo_xo_touch/voting.dart';

class MyApp extends StatelessWidget {
  final Socket requestSocket;
  final Stream<Uint8List> socketStream;

  final GlobalKey<RoomState> _roomKey = GlobalKey();
  final GlobalKey<AnswersState> _answersKey = GlobalKey();
  final GlobalKey<AnswersEndState> _answersEndKey = GlobalKey();

  MyApp(this.requestSocket, this.socketStream, {super.key}) {
    // Listen broadcasts
    Socket.connect('7.tcp.eu.ngrok.io', 18307).then((socket) {
      debugPrint('[INFO] broadcast client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
      socket.listen((List<int> event) {
        var data = utf8.decode(event).replaceAll("\n", "");
        debugPrint("[INFO] got broadcast: $data");

        var jsonData = jsonDecode(data);
        var eventType = jsonData["message"];
        debugPrint("[DEBUG] event: $eventType");
        switch (eventType) {
          case "newplayer":
            var username = jsonData["username"];
            _roomKey.currentState!.addPlayer(username);
            break;
          case "gamestarted":
            Navigator.of(_roomKey.currentContext!).pushNamedAndRemoveUntil('/answers', (route) => false);
            break;
          case "everyoneanswered":
            if (_answersEndKey.currentContext == null) {
              Navigator.of(_answersKey.currentContext!)
                  .pushNamedAndRemoveUntil('/voting', (route) => false);
            } else {
              Navigator.of(_answersEndKey.currentContext!)
                  .pushNamedAndRemoveUntil('/voting', (route) => false);
            }
            break;
          case "newduelvotingstarted":
            // TODO: create _duelResultKey
            // Navigator.of(_answersEndKey.currentContext!)
            //     .pushNamedAndRemoveUntil('/voting', (route) => false);
            break;
          case "duelvotingended":
            // Add votes and nicknames in voting widget
            break;
        }
      }, onDone: () {
        debugPrint("[WARN] broadcast connection closed");
        socket.destroy();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'XO-XO-TOUCH',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
          useMaterial3: true,
        ),
        initialRoute: '/mainmenu',
        routes: {  // TODO: https://stackoverflow.com/questions/63612663/prevent-unauthenticated-users-from-navigating-to-a-route-using-a-url-in-a-flutte
          '/mainmenu': (context) => MainMenu(requestSocket, socketStream),
          '/room': (context) {
            final roomUsernames = ModalRoute.of(context)?.settings.arguments as List<dynamic>;
            return Room(roomUsernames, key: _roomKey);
          },
          '/profile': (context) => const Placeholder(),
          '/answers': (context) => Answers(requestSocket, socketStream, key: _answersKey),
          '/answersend': (context) => AnswersEnd(key: _answersEndKey),
          '/voting': (context) => Voting(requestSocket, socketStream),
          '/authorization': (context) => AuthorizationScreen(requestSocket: requestSocket,
              socketStream: socketStream)
        }
    );
  }
}
