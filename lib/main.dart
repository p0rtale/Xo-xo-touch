import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:async';

import 'package:xo_xo_touch/app.dart';

Future<void> main() async {
  // Establish a connection for requests to the server
  Socket requestSocket = await Socket.connect('7.tcp.eu.ngrok.io', 10603);
  Stream<Uint8List> socketStream = requestSocket.asBroadcastStream();
  debugPrint('[INFO] request client connected: ${requestSocket.remoteAddress.address}:${requestSocket.remotePort}');

  // Remove Keyboard and Notification Bar by default
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays:[]);

  // Run game!
  runApp(MyApp(requestSocket, socketStream));
}
