import 'package:flutter/material.dart';

void main() {
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
            child: Image.asset('images/mainmenu_background.png', fit: BoxFit.fill),
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

class Rooms extends StatelessWidget {
  const Rooms({super.key});

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
