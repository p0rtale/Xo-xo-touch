import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

class GameResults extends StatefulWidget {
  final Map<String, int> roomUsersPoints;

  const GameResults(this.roomUsersPoints, {super.key});

  @override
  State<GameResults> createState() => GameResultsState();
}

// Public: need addPlayer from outside
class GameResultsState extends State<GameResults> {
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

  @override
  void initState() {
    super.initState();
    _init();

    var sortedRoomUserPoints = Map.fromEntries(
        widget.roomUsersPoints.entries.toList()..sort(
                (e1, e2) => e2.value.compareTo(e1.value)
        )
    );

    final dir1 = Directory('assets/images/game_results/1');
    final imgs1 = dir1.listSync();
    final dir2 = Directory('assets/images/game_results/2');
    final imgs2 = dir2.listSync();
    final dir3 = Directory('assets/images/game_results/3');
    final imgs3 = dir3.listSync();
    final dir4 = Directory('assets/images/game_results/4');
    var imgs4 = dir4.listSync();
    imgs4.shuffle(_random);

    int i = 0;
    String currImgName = "";
    sortedRoomUserPoints.forEach((username, userpoints) =>
      setState(() {
        i++;
        if (i == 1) {
          currImgName = imgs1[_random.nextInt(imgs1.length)].path;
        } else if (i == 2) {
          currImgName = imgs2[_random.nextInt(imgs2.length)].path;
        } else if (i == 3) {
          currImgName = imgs3[_random.nextInt(imgs3.length)].path;
        } else {
          currImgName = imgs4[i-4].path;
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
