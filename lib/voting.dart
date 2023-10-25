import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';

import 'error_notifier.dart';

import 'package:http/http.dart' as http;

class Voting extends StatefulWidget {
  final Socket requestSocket;
  final Stream<Uint8List> socketStream;

  const Voting(this.requestSocket, this.socketStream, {super.key});

  @override
  State<Voting> createState() => _VotingState();
}

class _VotingState extends State<Voting> {
  final storage = const FlutterSecureStorage();

  String question = "Когда пациент раздевается, реально плохой врач говорит:";
  String answerFirst = "A ГДЕ ТВОИ СИСЬКИ?";
  String answerSecond = "ВЫ УЖЕ ВСЁ?";

  bool isAnswered = false;

  final AudioPlayer ttsPlayer = AudioPlayer();

  Future<void> _playText(Uint8List bytes) async {
    Uint8List audioBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    await ttsPlayer.setAudioSource(AudioSource.uri(Uri.dataFromBytes(audioBytes, mimeType: "audio/wav")));
    await ttsPlayer.play();
  }

  @override
  void initState() {
    super.initState();

    final token = storage.read(key: "jwtToken");
    token.then((token) {
      debugPrint("[INFO] Get duel token: $token");

      if (token == null) {
        debugPrint("[INFO] Get duel No jwtToken");
        return;
      }

      var request = {
        "method": "getduel",
        "token": token,
      };
      var jsonRequest = jsonEncode(request);
      widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

      StreamSubscription? subscription;
      subscription = widget.socketStream.listen((event) {
        var data = utf8.decode(event).replaceAll("\n", "");
        var jsonData = jsonDecode(data);
        debugPrint("[DEBUG] Get duel jsonData: $jsonData");
        var status = jsonData["status"];

        if (status != 200) {
          debugPrint("[WARN] Get duel bad status: $status");
          return;
        }

        String questionTmp = jsonData["question"];
        debugPrint("[INFO] Get duel question: $questionTmp");

        var answers = jsonData["answers"];
        String answerFirstTmp = answers[0];
        String answerSecondTmp = answers[1];

        setState(() {
          question = questionTmp;
          answerFirst = answerFirstTmp;
          answerSecond = answerSecondTmp;
        });

        debugPrint("[INFO] Sending TTS request...");
        var body = json.encode({
          "text": "Вопрос: $question. Ответ первого игрока: $answerFirst. Ответ второго игрока: $answerSecond",
          "voice": "baya",
        });
        http.post(
          Uri.parse("https://93a0-95-165-142-68.ngrok-free.app/predict"),
          headers: {"Content-Type": "application/json"},
          body: body,
        ).then((response) {
          _playText(response.bodyBytes);
        });

        subscription!.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const styleXoxotouch = TextStyle(
      fontSize: 40.0,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
    );

    const styleQuestionText = TextStyle(
      fontSize: 25.0,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
    );

    const styleAnswerText = TextStyle(
      fontSize: 25.0,
      color: Color.fromRGBO(10, 7, 94, 1.0),
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
    );

    Color answerContainerColor = const Color.fromRGBO(102, 151, 227, 1.0);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(69, 8, 160, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(53, 20, 108, 1.0),
        centerTitle: true,
        title: const Text("XO-XO-TOUCH", style: styleXoxotouch),
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Container(
            decoration: const BoxDecoration(
                color: Color.fromRGBO(110, 51, 203, 1.0),
            ),
            // margin: const EdgeInsets.only(left: 10.0, right: 10.0),
            padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Text(
                question,
                style: styleQuestionText,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.17),
          Container(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: ElevatedButton(
                onPressed: () {
                  debugPrint("[INFO] Save vote 0");

                  if (isAnswered) {
                    debugPrint("[INFO] Save vote: already answered");
                    createErrorNotifier(context, "Вы уже проголосовали!");
                    return;
                  }

                  final token = storage.read(key: "jwtToken");
                  token.then((token) {
                    debugPrint("[INFO] Save vote token: $token");

                    if (token == null) {
                      debugPrint("[WARNING] Save vote No jwtToken");
                      return;
                    }

                    var request = {
                      "method": "savevote",
                      "token": token,
                      "vote": 0,
                    };
                    var jsonRequest = jsonEncode(request);
                    widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

                    StreamSubscription? subscription;
                    subscription = widget.socketStream.listen((event) {
                      var data = utf8.decode(event).replaceAll("\n", "");
                      var jsonData = jsonDecode(data);
                      debugPrint("[DEBUG] Save vote jsonData: $jsonData");
                      var status = jsonData["status"];

                      if (status != 200) {
                        debugPrint("[WARN] Save vote bad status: $status");
                        return;
                      }

                      isAnswered = true;

                      subscription!.cancel();
                    });
                  });
                },
                style: ButtonStyle(
                  padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
                  backgroundColor: MaterialStatePropertyAll<Color>(answerContainerColor),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
                child: Text(answerFirst, style: styleAnswerText),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.17),
          Container(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: ElevatedButton(
                onPressed: () {
                  debugPrint("[INFO] Save vote 1");

                  if (isAnswered) {
                    debugPrint("[INFO] Save vote: already answered");
                    createErrorNotifier(context, "Вы уже проголосовали!");
                    return;
                  }

                  final token = storage.read(key: "jwtToken");
                  token.then((token) {
                    debugPrint("[INFO] Save vote token: $token");

                    if (token == null) {
                      debugPrint("[WARNING] Save vote No jwtToken");
                      return;
                    }

                    var request = {
                      "method": "savevote",
                      "token": token,
                      "vote": 1,
                    };
                    var jsonRequest = jsonEncode(request);
                    widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

                    StreamSubscription? subscription;
                    subscription = widget.socketStream.listen((event) {
                      var data = utf8.decode(event).replaceAll("\n", "");
                      var jsonData = jsonDecode(data);
                      debugPrint("[DEBUG] Save vote jsonData: $jsonData");
                      var status = jsonData["status"];

                      if (status != 200) {
                        debugPrint("[WARN] Save vote bad status: $status");
                        return;
                      }

                      isAnswered = true;

                      subscription!.cancel();
                    });
                  });
                },
                style: ButtonStyle(
                  padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
                  backgroundColor: MaterialStatePropertyAll<Color>(answerContainerColor),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
                child: Text(answerSecond, style: styleAnswerText),
              ),
            ),
          ),
          // Container(
          //   decoration: BoxDecoration(
          //     color: answerContainerColor,
          //   ),
          //   margin: const EdgeInsets.only(left: 25, right: 25.0),
          //   padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
          //   child: const Text(
          //     "Очень смешной ответ первого игрока на вопрос",
          //     style: styleAnswerText,
          //     textAlign: TextAlign.center,
          //   ),
          // ),
          // const SizedBox(height: 30),
          // Container(
          //   decoration: BoxDecoration(
          //     color: answerContainerColor,
          //   ),
          //   margin: const EdgeInsets.only(left: 25, right: 25.0),
          //   padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
          //   child: const Text(
          //     "Отстойный ответ второго игрока на вопрос",
          //     style: styleAnswerText,
          //     textAlign: TextAlign.center,
          //   ),
          // ),
          // Container(
          //   alignment: Alignment.topCenter,
          //   child: FractionallySizedBox(
          //     widthFactor: 0.9,
          //     child: TextField(
          //       controller: answerController,
          //       style: styleInput,
          //       decoration: InputDecoration(
          //         filled: true,
          //         fillColor: Colors.white,
          //         border: const OutlineInputBorder(),
          //         hintStyle: styleInput.copyWith(color: Colors.black.withOpacity(0.3)),
          //         hintText: "ТВОЙ ОТВЕТ",
          //       ),
          //       onChanged: (text) {
          //         answerController.text = text;
          //       },
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 30),
          // Container(
          //   alignment: Alignment.topCenter,
          //   child: FractionallySizedBox(
          //     widthFactor: 0.9,
          //     child: ElevatedButton(
          //       onPressed: () {},
          //       style: ButtonStyle(
          //         padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
          //         backgroundColor: const MaterialStatePropertyAll<Color>(Color.fromRGBO(115, 62, 224, 1.0)),
          //         shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          //           RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(10.0),
          //           ),
          //         ),
          //       ),
          //       child: const Text("Ответить", style: styleInput),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
