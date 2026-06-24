import 'package:flutter/material.dart';
import 'chat_theme_model.dart';

class ChatThemes {

  // Theme 0: Default White (Clean Brand Light Mode)
  static const ChatTheme defaultWhite = ChatTheme(
    id: 'default_white',
    name: 'Default White',
    backgroundColor: Color(0xFFFFFFFF), // Pure White Background
    sentMessageColor: Color(0xFF1A8CFF), // Vibrant Brand Blue (Sent Bubbles)
    receivedMessageColor: Color(0xFFF0F2F5), // Soft Light Gray (Received Bubbles)
    accentColor: Color(0xFF75DE7B), // Deep Textile Red (Icons, Badges, or Highlights)
  );

  // Theme 1: Vibrant Harmony Color Codes
  static const ChatTheme vibrantHarmony = ChatTheme(
    id: 'vibrant_harmony',
    name: 'Vibrant Harmony',
    backgroundColor: Color(0xFF8C1A1A),
    sentMessageColor: Color(0xFFFFD740),
    receivedMessageColor: Color(0xFF1A1D48),
    accentColor: Color(0xFF1A8CFF),
  );

  // Theme 2: Minimalist Indigo Color Codes
  static const ChatTheme minimalistIndigo = ChatTheme(
    id: 'minimalist_indigo',
    name: 'Minimalist Indigo',
    backgroundColor: Color(0xFF1A1D48),
    sentMessageColor: Color(0xFFFF5252),
    receivedMessageColor: Color(0xFF8C1AFF),
    accentColor: Color(0xFF1A8CFF),
  );

  // Theme 3: Patterned Slate Color Codes
  static const ChatTheme patternedSlate = ChatTheme(
    id: 'patterned_slate',
    name: 'Patterned Slate',
    backgroundColor: Color(0xFF2E3A4F),
    backgroundOverlay: Color(0x1A8C1A1A),
    sentMessageColor: Color(0xFFFFD740),
    receivedMessageColor: Color(0xFFFF5252),
    accentColor: Color(0xFF1A8CFF),
  );

  // Theme 4: Earthy Ochre (Textile Inspired Comfort)
  static const ChatTheme earthyOchre = ChatTheme(
    id: 'earthy_ochre',
    name: 'Earthy Ochre',
    backgroundColor: Color(0xFFF9F6F0), // Soft cream white background
    sentMessageColor: Color(0xFFD4A373), // Warm golden ochre bubble
    receivedMessageColor: Color(0xFFE0E0E0), // Neutral soft gray bubble
    accentColor: Color(0xFF8C1A1A), // Deep crimson textile red for buttons/appbar
  );

  // Theme 5: Midnight Neon (Logo Dark Mode)
  static const ChatTheme midnightNeon = ChatTheme(
    id: 'midnight_neon',
    name: 'Midnight Neon',
    backgroundColor: Color(0xFF161B22), // Ultra dark slate base from logo background
    sentMessageColor: Color(0xFF1A8CFF), // Electric blue bubble
    receivedMessageColor: Color(0xFF21262D), // Dark grey-blue bubble
    accentColor: Color(0xFFFF5252), // Fire coral red for active badges/FABs
  );

  // Theme 6: Sunset Gradient (Warm Blend)
  static const ChatTheme sunsetGradient = ChatTheme(
    id: 'sunset_gradient',
    name: 'Sunset Gradient',
    backgroundColor: Color(0xFF3F1B24), // Maroon plum background
    sentMessageColor: Color(0xFFE76F51), // Burnt orange-red bubble
    receivedMessageColor: Color(0xFF5C2C35), // Lighter plum bubble
    accentColor: Color(0xFFFFD740), // Bright gold accent
  );

  static const List<ChatTheme> availableThemes = [
    defaultWhite,
    vibrantHarmony,
    minimalistIndigo,
    patternedSlate,
    earthyOchre,
    midnightNeon,
    sunsetGradient,
  ];
}
