import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';


void main(){
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XO-XO-TOUCH',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey,
        useMaterial3: true,
      ),
      initialRoute: '/mainmenu',
      routes: {
        '/mainmenu': (context) => const MainMenu(),
        '/rooms': (context) => const Rooms(),
        '/profile': (context) => const Placeholder(),
      }
    );
  }
}


class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

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
              width: 90, // <-- Your width
              height: 90,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/rooms');
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


class Rooms extends StatefulWidget {
  const Rooms({super.key});

  @override
  RoomsState createState() => RoomsState();
}


// ЭТО ДОЛЖНО БЫТЬ RoomState для Room, но пока есть только Rooms
class RoomsState extends State<Rooms> {
  final AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await player.setAsset("assets/audios/Paradox_Interactive_-_Dunka_Dunka.mp3");
    await player.play();
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