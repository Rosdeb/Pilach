import 'package:flutter/material.dart';

class AlphabetSidebar extends StatelessWidget {
  final List<String> alphabetList;
  final Function(String letter) onLetterSelected;

  const AlphabetSidebar({
    super.key,
    required this.alphabetList,
    required this.onLetterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Positioned(
      right: 4,
      top: 140,
      bottom: 40,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,

        onVerticalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);

          final itemHeight =
              box.size.height / alphabetList.length;

          int index = (localPosition.dy ~/ itemHeight)
              .clamp(0, alphabetList.length - 1);

          onLetterSelected(alphabetList[index]);
        },

        child: SizedBox(
          width: 24,
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: alphabetList.map((letter) {
              return GestureDetector(
                onTap: () {
                  onLetterSelected(letter);
                },
                child: Text(
                  letter,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF30D158) : const Color(0xFF34C759),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}