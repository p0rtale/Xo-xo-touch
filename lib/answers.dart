import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';

import 'package:http/http.dart' as http;

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class AnswersEnd extends StatefulWidget {
  const AnswersEnd({super.key});

  @override
  State<AnswersEnd> createState() => AnswersEndState();
}

class AnswersEndState extends State<AnswersEnd> {
  @override
  Widget build(BuildContext context) {
    const styleText = TextStyle(
      fontSize: 32.0,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
    );

    return Scaffold(
      backgroundColor: const Color.fromRGBO(69, 8, 160, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(53, 20, 108, 1.0),
        centerTitle: true,
        title: Text("XO-XO-TOUCH", style: styleText.copyWith(fontSize: 40)),
      ),
      body: const Column(
        children: [
          SizedBox(height: 100),
          Text(
            "Ждём, пока отвечают остальные игроки...",
            style: styleText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class Answers extends StatefulWidget {
  final Socket requestSocket;
  final Stream<Uint8List> socketStream;

  const Answers(this.requestSocket, this.socketStream, {super.key});

  @override
  State<Answers> createState() => AnswersState();
}

class AnswersState extends State<Answers> {
  final storage = const FlutterSecureStorage();

  String question = "";
  final AudioPlayer ttsPlayer = AudioPlayer();

  Future<void> _playQuestion(Uint8List bytes) async {
    Uint8List audioBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    await ttsPlayer.setAudioSource(AudioSource.uri(Uri.dataFromBytes(audioBytes, mimeType: "audio/wav")));
    await ttsPlayer.play();
  }

  @override
  void initState() {
    super.initState();

    final token = storage.read(key: "jwtToken");
    token.then((token) {
      debugPrint("[INFO] Game question token: $token");

      if (token == null) {
        debugPrint("[INFO] Game question No jwtToken");
        return;
      }

      var request = {
        "method": "getquestion",
        "token": token,
      };
      var jsonRequest = jsonEncode(request);
      widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

      StreamSubscription? subscription;
      subscription = widget.socketStream.listen((event) {
        var data = utf8.decode(event).replaceAll("\n", "");
        var jsonData = jsonDecode(data);
        debugPrint("[DEBUG] Game question jsonData: $jsonData");
        var status = jsonData["status"];

        if (status != 200) {
          debugPrint("[WARN] Game question bad status: $status");
          return;
        }

        var gameQuestion = jsonData["question"];
        debugPrint("[INFO] Game question: $gameQuestion");

        setState(() {
          question = gameQuestion;
          answerController.text = "";
        });

        debugPrint("[INFO] Sending TTS request...");
        var body = json.encode({"text": gameQuestion, "voice": "baya"});
        http.post(
          Uri.parse("https://793c-5-142-47-47.ngrok-free.app/predict"),
          headers: {"Content-Type": "application/json"},
          body: body,
        ).then((response) {
          _playQuestion(response.bodyBytes);
        });

        subscription!.cancel();
      });
    });
  }

  @override
  void dispose() {
    ttsPlayer.dispose();
    super.dispose();
  }

  var answerController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const styleText = TextStyle(
      fontSize: 25.0,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
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
      body: Column(
        children: [
          const SizedBox(height: 50),
          Text(
            question,
            style: styleText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: TextField(
                controller: answerController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
                style: styleInput,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                  hintStyle: styleInput.copyWith(color: Colors.black.withOpacity(0.3)),
                  hintText: "ТВОЙ ОТВЕТ",
                ),
                onChanged: (text) {
                  answerController.text = text;
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
                  final token = storage.read(key: "jwtToken");
                  token.then((token) {
                    debugPrint("[INFO] Answer token: $token");

                    if (token == null) {
                      debugPrint("[WARNING] Answer No jwtToken");
                      return;
                    }

                    debugPrint("[INFO] Answer text: ${answerController.text}");
                    var request = {
                      "method": "saveanswer",
                      "token": token,
                      "answer": answerController.text,
                    };
                    var jsonRequest = jsonEncode(request);
                    widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

                    StreamSubscription? subscription;
                    subscription = widget.socketStream.listen((event) {
                      var data = utf8.decode(event).replaceAll("\n", "");
                      var jsonData = jsonDecode(data);
                      debugPrint("[DEBUG] Answer jsonData: $jsonData");
                      var status = jsonData["status"];

                      if (status != 200) {
                        debugPrint("[WARN] Answer bad status: $status");
                        return;
                      }

                      subscription!.cancel();

                      if (jsonData["lastanswer"]) {
                        debugPrint("[INFO] Last answer! Waiting...");
                        debugPrint("[DEBUG] ModalRoute: ${ModalRoute.of(context)?.isActive}");
                        if (ModalRoute.of(context)!.isActive) {
                          setState(() {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                '/answersend', (route) => false);
                          });
                        }
                        return;
                      }

                      debugPrint("[INFO] Get question");
                      var request = {
                        "method": "getquestion",
                        "token": token,
                      };
                      var jsonRequest = jsonEncode(request);
                      widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

                      StreamSubscription? subscriptionQuestion;
                      subscriptionQuestion = widget.socketStream.listen((event) {
                        var data = utf8.decode(event).replaceAll("\n", "");
                        var jsonData = jsonDecode(data);
                        debugPrint("[DEBUG] Game question jsonData: $jsonData");
                        var status = jsonData["status"];

                        if (status != 200) {
                          debugPrint("[WARN] Game question bad status: $status");
                          return;
                        }

                        var gameQuestion = jsonData["question"];
                        debugPrint("[INFO] Game question: $gameQuestion");

                        setState(() {
                          question = gameQuestion;
                          answerController.text = "";
                        });

                        debugPrint("[INFO] Sending TTS request...");
                        var body = json.encode({"text": gameQuestion, "voice": "baya"});
                        http.post(
                          Uri.parse("https://793c-5-142-47-47.ngrok-free.app/predict"),
                          headers: {"Content-Type": "application/json"},
                          body: body,
                        ).then((response) {
                          _playQuestion(response.bodyBytes);
                        });

                        subscriptionQuestion!.cancel();
                      });
                    });
                  });
                  // widget.requestSocket.add(utf8.encode("$answer\n"));
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
      ),
    );
  }
}
