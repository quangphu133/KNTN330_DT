import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppSnackBar(String message) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
