import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_toast.dart';

class UrlLauncherUtils {
  UrlLauncherUtils._();

  static final RegExp urlRegex = RegExp(
    r'(?:(?:https?:\/\/|www\.)[^\s<>"{}|\\^`\[\]]+|\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}(?::\d{2,5})?(?:\/[^\s<>"{}|\\^`\[\]]*)?)',
    caseSensitive: false,
  );

  static final RegExp phoneRegex = RegExp(r'\+?\d[\d\s().-]{5,}\d');

  /// Cleans and formats the raw URL string ensuring proper scheme.
  static String formatUrl(String rawUrl) {
    String trimmed = rawUrl.trim();
    // Remove trailing punctuation marks that often get attached to URLs in chat
    trimmed = trimmed.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    if (trimmed.toLowerCase().startsWith('www.')) {
      return 'https://$trimmed';
    }
    if (!trimmed.toLowerCase().startsWith('http://') &&
        !trimmed.toLowerCase().startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  /// Extracts the first URL from text if present.
  static String? extractFirstUrl(String text) {
    final matches = _urlCandidates(text);
    return matches.isEmpty ? null : formatUrl(matches.first.text);
  }

  static List<String> extractPhoneNumbers(String text) => _phoneCandidates(
    text,
    occupied: _urlCandidates(text),
  ).map((candidate) => candidate.text).toList(growable: false);

  static String normalizePhoneNumber(String rawNumber) {
    final trimmed = rawNumber.trim();
    final hasInternationalPrefix = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasInternationalPrefix ? '+$digits' : digits;
  }

  static Future<bool> openPhoneDialer(
    BuildContext context,
    String rawNumber,
  ) async {
    final number = normalizePhoneNumber(rawNumber);
    if (number.replaceAll('+', '').length < 7) {
      AppToast.show(context, 'Invalid phone number', type: ToastType.error);
      return false;
    }

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.show(
          context,
          'Could not open phone dialer',
          type: ToastType.error,
        );
      }
      return launched;
    } catch (_) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Could not open phone dialer',
          type: ToastType.error,
        );
      }
      return false;
    }
  }

  static List<_DetectedEntity> _urlCandidates(String text) {
    final candidates = <_DetectedEntity>[];
    for (final match in urlRegex.allMatches(text)) {
      if (match.start > 0 && text[match.start - 1] == '@') continue;
      final raw = match.group(0)!;
      final cleaned = raw.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
      if (cleaned.isEmpty) continue;
      candidates.add(
        _DetectedEntity(
          start: match.start,
          end: match.start + cleaned.length,
          text: cleaned,
          type: _DetectedEntityType.url,
        ),
      );
    }
    return candidates;
  }

  static List<_DetectedEntity> _phoneCandidates(
    String text, {
    required List<_DetectedEntity> occupied,
  }) {
    final candidates = <_DetectedEntity>[];
    for (final match in phoneRegex.allMatches(text)) {
      final raw = match.group(0)!.trim();
      final leadingWhitespace = match.group(0)!.lengthLeftTrimmed;
      final start = match.start + leadingWhitespace;
      final end = start + raw.length;
      final digitCount = raw.replaceAll(RegExp(r'\D'), '').length;
      final looksLikeDate = RegExp(
        r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}',
      ).hasMatch(raw);
      final overlapsUrl = occupied.any(
        (item) => start < item.end && end > item.start,
      );
      if (digitCount < 7 || digitCount > 15 || looksLikeDate || overlapsUrl) {
        continue;
      }
      candidates.add(
        _DetectedEntity(
          start: start,
          end: end,
          text: raw,
          type: _DetectedEntityType.phone,
        ),
      );
    }
    return candidates;
  }

  static List<_DetectedEntity> _detectEntities(String text) {
    final urls = _urlCandidates(text);
    return <_DetectedEntity>[...urls, ..._phoneCandidates(text, occupied: urls)]
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Opens the URL using the best available method:
  /// 1. Tries LaunchMode.platformDefault (in-app Chrome Custom Tab or Safari View Controller)
  /// 2. Falls back to LaunchMode.externalApplication (Google Chrome / Safari default app)
  /// If both fail, displays a feedback toast.
  static Future<bool> openUrl(
    BuildContext context,
    String rawUrl, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    final formatted = formatUrl(rawUrl);
    final uri = Uri.tryParse(formatted);

    if (uri == null || uri.host.isEmpty) {
      if (context.mounted) {
        AppToast.show(context, 'Invalid link: $rawUrl', type: ToastType.error);
      }
      return false;
    }

    try {
      final launched = await launchUrl(uri, mode: mode);

      if (!launched) {
        // Fallback to external application (e.g. Safari / Google browser app)
        final fallbackLaunched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!fallbackLaunched && context.mounted) {
          AppToast.show(context, 'Could not open link', type: ToastType.error);
          return false;
        }
      }
      return true;
    } catch (_) {
      // Fallback try with external browser
      try {
        final fallback = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!fallback && context.mounted) {
          AppToast.show(context, 'Could not open link', type: ToastType.error);
        }
        return fallback;
      } catch (_) {
        if (context.mounted) {
          AppToast.show(context, 'Could not open link', type: ToastType.error);
        }
        return false;
      }
    }
  }

  /// Opens the URL in an external browser app directly (Google / Safari).
  static Future<bool> openInExternalBrowser(
    BuildContext context,
    String rawUrl,
  ) {
    return openUrl(context, rawUrl, mode: LaunchMode.externalApplication);
  }

  /// Copies the URL to the clipboard and displays a confirmation toast.
  static Future<void> copyUrl(BuildContext context, String rawUrl) async {
    final formatted = formatUrl(rawUrl);
    await Clipboard.setData(ClipboardData(text: formatted));
    if (context.mounted) {
      AppToast.show(
        context,
        'Link copied to clipboard',
        type: ToastType.success,
      );
    }
  }

  /// Shows an action sheet with options: Open in App, Open in Safari / Chrome, Copy Link.
  static void showLinkOptions(BuildContext context, String rawUrl) {
    final formatted = formatUrl(rawUrl);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formatted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.open_in_browser_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Open in App Browser'),
                  subtitle: const Text('View inside the app'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openUrl(
                      context,
                      formatted,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.public_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Open in Safari / Chrome'),
                  subtitle: const Text('Launch default browser application'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openInExternalBrowser(context, formatted);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: colorScheme.primary),
                  title: const Text('Copy Link'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    copyUrl(context, formatted);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A text widget that detects URLs and formats them as clickable and long-pressable links.
class RichLinkText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextStyle? linkStyle;

  const RichLinkText({
    super.key,
    required this.text,
    required this.style,
    this.linkStyle,
  });

  @override
  State<RichLinkText> createState() => _RichLinkTextState();
}

class _RichLinkTextState extends State<RichLinkText> {
  final List<GestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final entities = UrlLauncherUtils._detectEntities(widget.text);
    if (entities.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    final defaultLinkStyle =
        widget.linkStyle ??
        widget.style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        );

    for (final entity in entities) {
      if (entity.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: widget.text.substring(lastMatchEnd, entity.start),
            style: widget.style,
          ),
        );
      }

      final tapRecognizer = TapGestureRecognizer()
        ..onTap = () {
          if (entity.type == _DetectedEntityType.phone) {
            UrlLauncherUtils.openPhoneDialer(context, entity.text);
          } else {
            UrlLauncherUtils.openUrl(context, entity.text);
          }
        };

      _recognizers.add(tapRecognizer);

      spans.add(
        TextSpan(
          text: entity.text,
          style: defaultLinkStyle,
          recognizer: tapRecognizer,
        ),
      );

      lastMatchEnd = entity.end;
    }

    if (lastMatchEnd < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(lastMatchEnd),
          style: widget.style,
        ),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }
}

enum _DetectedEntityType { url, phone }

class _DetectedEntity {
  const _DetectedEntity({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
  });

  final int start;
  final int end;
  final String text;
  final _DetectedEntityType type;
}

extension on String {
  int get lengthLeftTrimmed => length - trimLeft().length;
}
