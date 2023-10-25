import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

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

  final AudioPlayer musicPlayer = AudioPlayer();
  final AudioPlayer ttsPlayer = AudioPlayer();

  List<Widget> _players = [];

  Future<void> _playNewPlayer(Uint8List bytes) async {
    Uint8List audioBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    await ttsPlayer.stop();
    await ttsPlayer.setAudioSource(AudioSource.uri(Uri.dataFromBytes(audioBytes, mimeType: "audio/wav")));
    await ttsPlayer.setVolume(1.0);
    await ttsPlayer.play();
  }

  Future<void> addPlayer(String nickname) async {
    setState(() {
      _players = [..._players, Card(
        child: ListTile(
          leading: const Icon(Icons.person),
          title: Text(nickname, style: styleNickname),
        ),
      )];
    });

    debugPrint("[INFO] Sending TTS request...");
    var body = json.encode({"text": "$nickname зашёл в комнату ожидания", "voice": "ruslan"});
    http.post(
      Uri.parse("https://93a0-95-165-142-68.ngrok-free.app/predict"),
      headers: {"Content-Type": "application/json"},
      body: body,
    ).then((response) {
      _playNewPlayer(response.bodyBytes);
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
    await musicPlayer.setAsset("assets/audios/Paradox_Interactive_-_Dunka_Dunka.mp3");
    await musicPlayer.play();
  }

  @override
  void dispose() {
    musicPlayer.dispose();
    ttsPlayer.dispose();
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
