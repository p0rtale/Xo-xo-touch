import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

class Room extends StatefulWidget {
  final List<dynamic> roomUsernames;

  const Room(this.roomUsernames, {super.key});

  @override
  State<Room> createState() => RoomState();
}

// Public: need addPlayer from outside
class RoomState extends State<Room> {
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
  List<Widget> _players = [];

  void addPlayer(String nickname) {
    setState(() {
      _players = [..._players, Card(
        child: ListTile(
          leading: const Icon(Icons.person),
          title: Text(nickname, style: styleNickname),
        ),
      )];
    });
  }

  @override
  void initState() {
    super.initState();
    _init();

    const storage = FlutterSecureStorage();
    final username = storage.read(key: "username");

    username.then((username) {
      var usernames = [username, ...widget.roomUsernames];
      for (var username in usernames) {
        setState(() {
          _players = [..._players, Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(username!, style: styleNickname),
            ),
          )];
        });
      }
    });
  }

  Future<void> _init() async {
    // Problem with Linux
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
