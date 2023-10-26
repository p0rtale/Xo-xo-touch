import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

class GameResults extends StatefulWidget {
  final Socket requestSocket;
  final Stream<Uint8List> socketStream;

  const GameResults(this.requestSocket, this.socketStream, {super.key});

  @override
  State<GameResults> createState() => GameResultsState();
}

// Public: need addPlayer from outside
class GameResultsState extends State<GameResults> {
  final storage = const FlutterSecureStorage();

  static const styleText = TextStyle(
    fontSize: 25.0,
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontFamily: 'Merriweather',
  );
  static const styleNickname = TextStyle(
    fontSize: 20.0,
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontFamily: 'Merriweather',
  );

  final _random = Random();
  final AudioPlayer player = AudioPlayer();
  List<TableRow> _players = [];

  Map<String, int> roomUsersPoints = {};

  @override
  void initState() {
    super.initState();
    _init();

    final token = storage.read(key: "jwtToken");
    token.then((token) {
      debugPrint("[INFO] Get duel token: $token");

      if (token == null) {
        debugPrint("[INFO] Get duel No jwtToken");
        return;
      }

      var request = {
        "method": "getroundresult",
        "token": token,
      };
      var jsonRequest = jsonEncode(request);
      widget.requestSocket.add(utf8.encode("$jsonRequest\n"));

      StreamSubscription? subscription;
      subscription = widget.socketStream.listen((event) {
        var data = utf8.decode(event).replaceAll("\n", "");
        var jsonData = jsonDecode(data);
        debugPrint("[DEBUG] Get round result jsonData: $jsonData");
        var status = jsonData["status"];

        if (status != 200) {
          debugPrint("[WARN] Get round result bad status: $status");
          return;
        }

        roomUsersPoints = jsonData["userspoints"];

        var sortedRoomUserPoints = Map.fromEntries(
            roomUsersPoints.entries.toList()..sort(
                    (e1, e2) => e2.value.compareTo(e1.value)
            )
        );

        // DOES NOT WORK ON ANDROID
        //final dir1 = Directory('assets/images/game_results/1');
        //final imgs1 = dir1.listSync();
        //final dir2 = Directory('assets/images/game_results/2');
        //final imgs2 = dir2.listSync();
        //final dir3 = Directory('assets/images/game_results/3');
        //final imgs3 = dir3.listSync();
        //final dir4 = Directory('assets/images/game_results/4');
        //var imgs4 = dir4.listSync();
        //imgs4.shuffle(_random);
        final imgs1 = ['1.jpg', '2.jpg', '3.jpg', '4.jpg', '5.jpg', '6.jpg', '7.jpg', '8.png', '9.jpg'];
        final imgs2 = ['1.jpg', '2.jpg', '3.jpg', 'wojak-big-veiny-brain.png', 'wojak-with-bigger-brain.jpg'];
        final imgs3 = ['1.jpg', 'wojak-big-brain-thinking-on-computer.png', 'wojak-fat-big-brain-glasses.png', 'wojak-glasses-large-brain.png'];
        final imgs4 = ['355.png', 'brainet-sofa-chair-brain.jpg', 'brainlet-abacus-2.jpg', 'brainlet-ape.jpg', 'brainlet-approaching-limit.png', 'brainlet-barbell-injury.jpg', 'brainlet-bib.png', 'brainlet-big-chin.png', 'brainlet-bird-bath-brain.jpg', 'brainlet-birdhouse-brain.jpg', 'brainlet-blender-brain.jpg', 'brainlet-bowl-head.png', 'brainlet-brain-cap.png', 'brainlet-brain-hanging.png', 'brainlet-brain-hat.jpg', 'brainlet-brain-magnification-x3000.jpg', 'brainlet-builds-brick-brain.jpg', 'brainlet-campfire-brain.jpg', 'brainlet-carousel-brain.png', 'brainlet-castle-brainlet.jpg', 'brainlet-coconut-head-brain.jpg', 'brainlet-computer-brain-buffering.png', 'brainlet-cracked-skull.png', 'brainlet-creatura.png', 'brainlet-dead-flower.jpg', 'brainlet-deflating-brain.png', 'brainlet-dried-out-long-nose.jpg', 'brainlet-drilling-brain.png', 'brainlet-drool-drowning-small.png', 'brainlet-drool-filled-up.png', 'brainlet-eating-spaghetti-os-soup.png', 'brainlet-emoji-abacus.jpg', 'brainlet-fat-face.jpg', 'brainlet-fat-neck-flat-earth-model.png', 'brainlet-filling-up-brain-with-air.jpg', 'brainlet-flat-earth-model.jpg', 'brainlet-gold-tooth.jpg', 'brainlet-graduating.png', 'brainlet-hammerhead.jpg', 'brainlet-hamster-wheel.jpg', 'brainlet-head-tricycle-riding-brainlet.jpg', 'brainlet-industrial-waste-plant.png', 'brainlet-lighthouse-brain.png', 'brainlet-log-head.jpg', 'brainlet-log-through-forehead.jpg', 'brainlet-melted-face-spinny-hat.jpg', 'brainlet-melted-salvador-dali-clocks.jpg', 'brainlet-mini-hammerhead.png', 'brainlet-mortar-pestle-brain.jpg', 'brainlet-mouse-trap-brain.png', 'brainlet-natural-fish-pond-brain.png', 'brainlet-neet.png', 'brainlet-newtons-cradle.png', 'brainlet-no-head.png', 'brainlet-oil-drill-brain.jpg', 'brainlet-on-computer.jpg', 'brainlet-pepe-bottomless-pit.jpg', 'brainlet-pepecopters.png', 'brainlet-pink-small-brain.png', 'brainlet-pointy-head.jpg', 'brainlet-power-strip.jpg', 'brainlet-reads-book.png', 'brainlet-real-black-hole-equations.jpg', 'brainlet-sips-brainlet-juice.jpg', 'brainlet-slinky-going-down-stairs.png', 'brainlet-small-brain.png', 'brainlet-smart-wojak-mask.jpg', 'brainlet-snoke.png', 'brainlet-snot-taste.png', 'brainlet-spindley-brain.jpg', 'brainlet-spinny-hat.jpg', 'brainlet-split-head.jpg', 'brainlet-sunken-head.jpg', 'brainlet-sunny-island-brain.png', 'brainlet-swingset.png', 'brainlet-tennis-racket-head.png', 'brainlet-titanic-brain.png', 'brainlet-toilet-paper-roll-head.png', 'brainlet-toilet-seat-head.png', 'brainlet-tries-to-put-shape-in-head.png', 'brainlet-uncle.jpg', 'brainlet-unsure-of-brain.png', 'brainlet-wide-eyes.png', 'brainlet-windup-brain.jpg', 'brainlet-wojak-ahh-real-monsters.jpg', 'brainlet-wojak-brain-mask.jpg', 'brainlet-y-head.jpg', 'branlet-blackhole-spacetime.jpg', 'flat,750x,075,f-pad,750x1000,f8f8f8.jpg', 'IMG_20191008_072910.jpg'];
        imgs4.shuffle(_random);

        int i = 0;
        String currImgName = "";
        sortedRoomUserPoints.forEach((username, userpoints) =>
            setState(() {
              i++;
              if (i == 1) {
                //currImgName = imgs1[_random.nextInt(imgs1.length)].path;
                currImgName = "assets/images/game_results/1/${imgs1[_random.nextInt(imgs1.length)]}";
              } else if (i == 2) {
                //currImgName = imgs2[_random.nextInt(imgs2.length)].path;
                currImgName = "assets/images/game_results/2/${imgs2[_random.nextInt(imgs2.length)]}";
              } else if (i == 3) {
                //currImgName = imgs3[_random.nextInt(imgs3.length)].path;
                currImgName = "assets/images/game_results/3/${imgs3[_random.nextInt(imgs3.length)]}";
              } else {
                //currImgName = imgs4[i-4].path;
                currImgName = "assets/images/game_results/4/${imgs4[i-4]}";
              }

              _players = [..._players, TableRow(
                children: [
                  Image.asset(
                    currImgName.replaceAll(r'\', r'/'),
                    fit: BoxFit.fill,
                  ),
                  TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(username, style: styleNickname),
                      )
                  ),
                  TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(userpoints.toString(), style: styleNickname),
                      )
                  ),
                ],
              )];
            })
        );

        subscription!.cancel();
      });
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
    final tableScrollController = ScrollController();
    const deepPurple = Color.fromRGBO(69, 8, 160, 0.2);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(69, 8, 160, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(53, 20, 108, 1.0),
        centerTitle: true,
        title: Text("Результаты", style: styleText.copyWith(fontSize: 30)),
        automaticallyImplyLeading: false,
      ),
      body:
        Container(
          decoration: BoxDecoration(
            color: Colors.white70,
            border: Border.all(
              color: Colors.black,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0),
          child:
            Scrollbar(
              controller: tableScrollController,
              child:
                SingleChildScrollView(
                  controller: tableScrollController,
                  scrollDirection: Axis.vertical,
                  child:
                    Table(
                      border: TableBorder.symmetric(
                        outside: BorderSide.none,
                        inside: const BorderSide(
                            width: 2,
                            color: Colors.black
                        ),
                      ),
                      columnWidths: const <int, TableColumnWidth>{
                        0: FixedColumnWidth(120),
                        1: FlexColumnWidth(),
                        2: IntrinsicColumnWidth(),
                      },
                      children: [
                        TableRow(
                          children: [
                            TableCell(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: deepPurple,
                                    borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(10)
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                                  child: const Text("Rank", style: styleNickname),
                                )
                            ),
                            TableCell(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: deepPurple,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text("Usernames", style: styleNickname),
                                )
                            ),
                            TableCell(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: deepPurple,
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10)
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                                  child: const Text("Points", style: styleNickname),
                                )
                            ),
                          ],
                        ),
                        ..._players,
                        TableRow(
                            children: [
                              TableCell(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: deepPurple,
                                    ),
                                    child: const Text(""),
                                  )
                              ),
                              TableCell(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: deepPurple,
                                    ),
                                    child: const Text(""),
                                  )
                              ),
                              TableCell(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: deepPurple,
                                    ),
                                    child: const Text(""),
                                  )
                              ),
                            ]
                        )
                      ],
                    ),
                )
            )
        ),
    );
  }
}
