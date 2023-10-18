import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:xo_xo_touch/authorization.dart';

Future<void> main() async {
  // Request socket
  Socket requestSocket = await Socket.connect('4.tcp.eu.ngrok.io', 16643);
  Stream<Uint8List> socketStream = requestSocket.asBroadcastStream();
  debugPrint('[INFO] request client connected: ${requestSocket.remoteAddress.address}:${requestSocket.remotePort}');

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays:[]);

  runApp(MyApp(requestSocket, socketStream));
}

class MyApp extends StatelessWidget {
  ValueNotifier<String> question = ValueNotifier('Как по-другому назвать одиночное заключение в тюрьме, чтобы звучало получше?');
  Socket requestSocket;
  Stream<Uint8List> socketStream;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  MyApp(this.requestSocket, this.socketStream, {super.key}) {
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
    Socket.connect('0.tcp.eu.ngrok.io', 14040).then((socket) {
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
        '/room': (context) => const Room(),
        '/profile': (context) => const Placeholder(),
        '/answers': (context) => Answers(requestSocket, question),
        '/authorization': (context) => AuthorizationScreen(requestSocket: requestSocket,
                                                            socketStream: socketStream)
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
                  // Navigator.pushNamed(context, '/room');
                  // Navigator.of(context).pushNamedAndRemoveUntil('/answers', (route) => false);
                  Navigator.of(context).pushNamedAndRemoveUntil('/room', (route) => false);

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
              ),
            ),
          ),
          Align(
              alignment: const Alignment(-0.92, 0.97),
              child: SizedBox(
                  width: 130, // <-- Your width
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
                    child: const Text('Login/Register', style: TextStyle(
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
      fontFamily: 'Merriweather',
    );
    const styleInput = TextStyle(
      fontSize: 25.0,
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontFamily: 'Merriweather',
    );

    return Scaffold(
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
    );
  }
}

class Room extends StatefulWidget {
  const Room({super.key});

  @override
  State<Room> createState() => _RoomState();
}

class _RoomState extends State<Room> {
  static const styleText = TextStyle(
    fontSize: 25.0,
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontFamily: 'Merriweather',
  );
  static const styleNickname = TextStyle(
    fontSize: 25.0,
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontFamily: 'Merriweather',
  );

  final AudioPlayer player = AudioPlayer();
  final List<Widget> _players = [
      const Card(
        child: ListTile(
          leading: Icon(Icons.person),
          title: Text('Ankalot', style: styleNickname),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.person),
          title: Text('Zlatoivan', style: styleNickname),
        ),
      ),
  ];

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
      backgroundColor: const Color.fromRGBO(69, 8, 160, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(53, 20, 108, 1.0),
        centerTitle: true,
        title: Text("Комната ожидания", style: styleText.copyWith(fontSize: 30)),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
        children: _players,
      ),
    );
  }
}
