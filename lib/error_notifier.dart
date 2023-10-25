import 'package:flutter/material.dart';

void createErrorNotifier(BuildContext context, String errText) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      "Error: $errText",
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    backgroundColor: Colors.red.shade300,
  ));
}
