import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:async';

Future<void> main() async {
  // Request socket
  Socket requestSocket = await Socket.connect('6.tcp.eu.ngrok.io', 11980);
  debugPrint('[INFO] request client connected: ${requestSocket.remoteAddress.address}:${requestSocket.remotePort}');

  runApp(MyApp(requestSocket));
}

class MyApp extends StatelessWidget {
  ValueNotifier<String> question = ValueNotifier('Как по-другому назвать одиночное заключение в тюрьме, чтобы звучало получше?');
  Socket requestSocket;

  MyApp(this.requestSocket, {super.key}) {
    // Requests
    // https://stackoverflow.com/questions/51077233/how-do-i-use-socket-in-flutter-apps

    // socket.listen((List<int> event) {
    // debugPrint("[INFO] got response: ${utf8.decode(event).replaceAll("\n", r"\n")}");
    // // handle event
    // }, onDone: () {
    // debugPrint("[WARN] request client connection closed");
    // socket.destroy();
    // });

    // Listen broadcasts
    Socket.connect('localhost', 5556).then((socket) {
      debugPrint('[INFO] broadcast client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
      socket.listen((List<int> event) {
        var data = utf8.decode(event).replaceAll("\n", r"\n");
        debugPrint("[INFO] got broadcast: $data");
        question.value = data;
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
        // brightness: Brightness.dark,
        // primaryColor: Colors.blueGrey,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
      ),
      initialRoute: '/mainmenu',
      routes: {  // TODO: https://stackoverflow.com/questions/63612663/prevent-unauthenticated-users-from-navigating-to-a-route-using-a-url-in-a-flutte
        '/mainmenu': (context) => MainMenu(requestSocket),
        '/rooms': (context) => const Rooms(),
        '/profile': (context) => const Placeholder(),
        '/answers': (context) => Answers(requestSocket, question),
      }
    );
  }
}

class MainMenu extends StatelessWidget {
  Socket requestSocket;

  MainMenu(this.requestSocket, {super.key});

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
                  Navigator.pushNamed(context, '/rooms');
                  // Navigator.of(context).pushNamedAndRemoveUntil('/answers', (route) => false);

                  // Test request
                  // requestSocket.add(utf8.encode('ABOBA\n'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(255, 0, 0, 1),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(24),
                ),
                child: const Text('Boop', style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                )),
              ))
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class Answers extends StatelessWidget {
  Socket requestSocket;

  Answers(this.requestSocket, this.question, {super.key});

  final ValueListenable<String> question;
  String answer = "";

  @override
  Widget build(BuildContext context) {
    const styleText = TextStyle(
      fontSize: 25.0,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      // letterSpacing: 1.1,question
      fontFamily: 'Merriweather',
    );
    const styleInput = TextStyle(
      fontSize: 25.0,
      color: Colors.black,
      fontWeight: FontWeight.bold,
      // letterSpacing: 1.1,
      fontFamily: 'Merriweather',
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(69, 8, 160, 1.0),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(53, 20, 108, 1.0),
          centerTitle: true,
          title: Text("XO-XO-TOUCH", style: styleText.copyWith(fontSize: 40)),
        ),
        body: ValueListenableBuilder<String>(
          valueListenable: question,
          builder: (context, value, child) {
            return Column(
              children: [
                const SizedBox(height: 50),
                Text(
                  question.value.toString(),
                  style: styleText,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Container(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: 0.9,
                    child: TextField(
                      // inputFormatters: [
                      //   UpperCaseTextFormatter(),
                      // ],
                      style: styleInput,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(),
                        hintStyle: styleInput.copyWith(color: Colors.black.withOpacity(0.3)),
                        hintText: 'ТВОЙ ОТВЕТ',
                      ),
                      onChanged: (text) {
                        answer = text;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: 0.9,
                    child: ElevatedButton(
                      onPressed: () {
                        requestSocket.add(utf8.encode('$answer\n'));
                      },
                      style: ButtonStyle(
                        padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
                        backgroundColor: const MaterialStatePropertyAll<Color>(Color.fromRGBO(115, 62, 224, 1.0)),
                        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      child: const Text("Ответить", style: styleInput),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class Rooms extends StatefulWidget {
  const Rooms({super.key});

  @override
  State<Rooms> createState() => _RoomsState();
}

// ЭТО ДОЛЖНО БЫТЬ RoomState для Room, но пока есть только Rooms
class _RoomsState extends State<Rooms> {
  final AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Problem with Linux
    // await player.setAsset("assets/audios/Paradox_Interactive_-_Dunka_Dunka.mp3");
    // await player.play();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rooms"),
      ),
      body: const Placeholder(),
    );
  }
}


// ============= HTTP request =============
//
// http.get(Uri.parse('https://70c5-83-220-237-145.ngrok.io/?userId=Ivan')).then((response) {
//   print(jsonDecode(response.body));
// }).catchError((error){
//   print("Error: $error");
// });
