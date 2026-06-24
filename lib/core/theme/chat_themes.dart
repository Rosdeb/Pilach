import 'package:flutter/material.dart';
import 'chat_theme_model.dart';

class ChatThemes {

  // Theme 0: Default White — UNCHANGED
  static const ChatTheme defaultWhite = ChatTheme(
    id: 'default_white',
    name: 'Default White',
    backgroundColor: Color(0xFFFFFFFF),
    sentMessageColor: Color(0xFF1A8CFF),
    receivedMessageColor: Color(0xFFF0F2F5),
    accentColor: Color(0xFF75DE7B),
  );

  // Theme 1: Rose Gold Luxe (Premium warm feminine)
  static const ChatTheme roseGoldLuxe = ChatTheme(
    id: 'rose_gold_luxe',
    name: 'Rose Gold Luxe',
    backgroundColor: Color(0xFFFDF0F0), // Blush white background
    sentMessageColor: Color(0xFFB76E79), // Deep rose gold bubble
    receivedMessageColor: Color(0xFFF2D9D9), // Pale blush received bubble
    accentColor: Color(0xFF8B4558),       // Rich mauve accent
  );

  // Theme 2: Deep Ocean (Premium dark cool tone)
  static const ChatTheme deepOcean = ChatTheme(
    id: 'deep_ocean',
    name: 'Deep Ocean',
    backgroundColor: Color(0xFF0D1B2A), // Near-black navy base
    sentMessageColor: Color(0xFF0077B6), // Ocean blue sent bubble
    receivedMessageColor: Color(0xFF1B2B3A), // Dark steel received bubble
    accentColor: Color(0xFF00B4D8),       // Cyan highlight accent
  );

  // Theme 3: Forest Mist (Premium earthy green)
  static const ChatTheme forestMist = ChatTheme(
    id: 'forest_mist',
    name: 'Forest Mist',
    backgroundColor: Color(0xFFF0F4F0), // Soft sage white
    backgroundOverlay: Color(0x0A2D6A2D),
    sentMessageColor: Color(0xFF4A7C59), // Deep forest green sent
    receivedMessageColor: Color(0xFFDDE8DD), // Misty sage received
    accentColor: Color(0xFF2D6A2D),       // Rich green accent
  );

  // Theme 4: Earthy Ochre — UNCHANGED
  static const ChatTheme earthyOchre = ChatTheme(
    id: 'earthy_ochre',
    name: 'Earthy Ochre',
    backgroundColor: Color(0xFFF9F6F0),
    sentMessageColor: Color(0xFFD4A373),
    receivedMessageColor: Color(0xFFE0E0E0),
    accentColor: Color(0xFF8C1A1A),
  );

  // Theme 5: Midnight Neon — UNCHANGED
  static const ChatTheme midnightNeon = ChatTheme(
    id: 'midnight_neon',
    name: 'Midnight Neon',
    backgroundColor: Color(0xFF161B22),
    sentMessageColor: Color(0xFF1A8CFF),
    receivedMessageColor: Color(0xFF21262D),
    accentColor: Color(0xFFFF5252),
  );

  // Theme 6: Royal Dusk (Premium purple-gold dark)
  static const ChatTheme royalDusk = ChatTheme(
    id: 'royal_dusk',
    name: 'Royal Dusk',
    backgroundColor: Color(0xFF1A1225), // Deep royal purple-black
    sentMessageColor: Color(0xFF7B2FBE), // Rich violet sent bubble
    receivedMessageColor: Color(0xFF2A1F3D), // Dark lavender received bubble
    accentColor: Color(0xFFFFBA08),       // Warm gold accent
  );

  static const List<ChatTheme> availableThemes = [
    defaultWhite,
    roseGoldLuxe,
    deepOcean,
    forestMist,
    earthyOchre,
    midnightNeon,
    royalDusk,
  ];
}