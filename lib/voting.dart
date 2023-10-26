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
  State<Voting> createState() => VotingState();
}

class VotingState extends State<Voting> {
  final storage = const FlutterSecureStorage();

  String question = "";
  List<Widget> answerFirstButtonText = [];
  List<Widget> answerSecondButtonText = [];
  List<Widget> _votesFor0 = [];
  List<Widget> _votesFor1 = [];

  bool isAnswered = false;

  final AudioPlayer ttsPlayer = AudioPlayer();

  Timer? voteTimer;
  Duration voteDuration = const Duration(seconds: 0);

  Future<void> _playText(Uint8List bytes) async {
    Uint8List audioBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    await ttsPlayer.setAudioSource(AudioSource.uri(Uri.dataFromBytes(audioBytes, mimeType: "audio/wav")));
    await ttsPlayer.play();
  }

  void getDuelResults() {
    const styleNicknameText = TextStyle(
      fontSize: 15.0,
      color: Color.fromRGBO(189, 215, 255, 1.0),
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
    );
    Color nicknameContainerColor = const Color.fromRGBO(161, 30, 159, 1.0);

    final token = storage.read(key: "jwtToken");
    token.then((token) {
      debugPrint("[INFO] Get duel token: $token");

      if (token == null) {
        debugPrint("[INFO] Get duel No jwtToken");
        return;
      }

      var request = {
        "method": "getduelresult",
        "token": token,
      };
      var jsonRequest = jsonEncode(request);
      widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

      StreamSubscription? subscription;
      subscription = widget.socketStream.listen((event) {
        var data = utf8.decode(event).replaceAll("\n", "");
        var jsonData = jsonDecode(data);
        debugPrint("[DEBUG] Get duel result jsonData: $jsonData");
        var status = jsonData["status"];

        if (status != 200) {
          debugPrint("[WARN] Get duel result bad status: $status");
          return;
        }

        var usernames = jsonData["usernames"];
        var votesFor0Tmp = jsonData["votesfor0"];
        var votesFor1Tmp = jsonData["votesfor1"];
        String usernameFirstTmp = usernames[0];
        String usernameSecondTmp = usernames[1];

        setState(() {
          answerFirstButtonText = [
            answerFirstButtonText[0],
            Text(usernameFirstTmp, style: styleNicknameText),
          ];
          answerSecondButtonText = [
            answerSecondButtonText[0],
            Text(usernameSecondTmp, style: styleNicknameText),
          ];

          for (String nickname in votesFor0Tmp) {
            _votesFor0 = [..._votesFor0, Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 5
              ),
              decoration: BoxDecoration(
                color: nicknameContainerColor,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(nickname, style: styleNicknameText),
            )];
          }
          for (String nickname in votesFor1Tmp) {
            _votesFor1 = [..._votesFor1, Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 5
              ),
              decoration: BoxDecoration(
                color: nicknameContainerColor,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(nickname, style: styleNicknameText),
            )];
          }
        });

        voteDuration = const Duration(seconds: 5);
        voteTimer!.cancel();
        voteTimer = Timer.periodic(const Duration(seconds: 1), (_) => setCountDown());

        subscription!.cancel();
      });
    });
  }

  void setCountDown() {
    const reduceSecondsBy = 1;
    setState(() {
      final seconds = voteDuration.inSeconds - reduceSecondsBy;
      if (seconds < 0) {
        voteTimer!.cancel();
      } else {
        voteDuration = Duration(seconds: seconds);
      }
    });
  }

  void initVoiting() {
    question = "";
    answerFirstButtonText = [];
    answerSecondButtonText = [];
    _votesFor0 = [];
    _votesFor1 = [];

    isAnswered = false;

    const styleAnswerText = TextStyle(
      fontSize: 25.0,
      color: Color.fromRGBO(10, 7, 94, 1.0),
      fontWeight: FontWeight.bold,
      fontFamily: 'Mferriweather',
    );

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
          answerFirstButtonText = [Text(answerFirstTmp, style: styleAnswerText)];
          answerSecondButtonText = [Text(answerSecondTmp, style: styleAnswerText)];
        });

        debugPrint("[INFO] Sending TTS request...");
        var body = json.encode({
          "text": "Вопрос: $question. Ответ первого игрока: $answerFirstTmp. Ответ второго игрока: $answerSecondTmp.",
          "voice": "baya",
        });
        http.post(
          Uri.parse("https://93a0-95-165-142-68.ngrok-free.app/predict"),
          headers: {"Content-Type": "application/json"},
          body: body,
        ).then((response) {
          _playText(response.bodyBytes);
        });

        voteDuration = const Duration(seconds: 20);
        //voteTimer!.cancel();
        voteTimer = Timer.periodic(const Duration(seconds: 1), (_) => setCountDown());

        subscription!.cancel();
      });
    });
  }

  @override
  void initState() {
    super.initState();

    debugPrint("[DEBUG] init voting");

    initVoiting();
  }

  @override
  void dispose() {
    voteTimer!.cancel();
    ttsPlayer.dispose();
    super.dispose();
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

    Color answerContainerColor = const Color.fromRGBO(102, 151, 227, 1.0);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(69, 8, 160, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(53, 20, 108, 1.0),
        centerTitle: true,
        title: Text(voteDuration.inSeconds.toString(), style: styleXoxotouch),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          FractionallySizedBox(
            widthFactor: 0.9,
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(110, 51, 203, 1.0),
              ),
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
              child: Text(
                question,
                style: styleQuestionText,
                textAlign: TextAlign.center,
              ),
            )
          ),
          Flexible(flex: 5, child: Container()),
          Flexible(flex: 0, child: Container(
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

                      if (status == 200 || status == 406) {
                        isAnswered = true;
                      } else {
                        debugPrint("[WARN] Save vote bad status: $status");
                        return;
                      }

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
                child: Column(
                  children: answerFirstButtonText
                ),
              ),
            ),
          )),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          Flexible(flex: 10, fit: FlexFit.loose, child: Container(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: _votesFor0,
              ),
            ),
          )),
          Flexible(flex: 0, child: Container(
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

                      if (status == 200 || status == 406) {
                        isAnswered = true;
                      } else {
                        debugPrint("[WARN] Save vote bad status: $status");
                        return;
                      }

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
                child: Column(
                    children: answerSecondButtonText
                ),
              ),
            ),
          )),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          Flexible(flex: 10, child: Container(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: _votesFor1,
              ),
            ),
          )),
        ],
      ),
    );
  }
}
