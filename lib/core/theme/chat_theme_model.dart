import 'package:flutter/material.dart';

class ChatTheme {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color sentMessageColor;
  final Color receivedMessageColor;
  final Color accentColor;
  final Color? backgroundOverlay;

  const ChatTheme({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.sentMessageColor,
    required this.receivedMessageColor,
    required this.accentColor,
    this.backgroundOverlay,
  });
}
