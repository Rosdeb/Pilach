import 'package:app/core/services/link_preview_service.dart';
import 'package:app/core/utils/url_launcher_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts the first public URL and removes sentence punctuation', () {
    expect(
      LinkPreviewService.firstUrl(
        'See https://drive.google.com/file/d/abc/view, then tell me.',
      ),
      'https://drive.google.com/file/d/abc/view',
    );
  });

  test('returns null when a message has no URL', () {
    expect(LinkPreviewService.firstUrl('Normal chat message'), isNull);
  });

  test('normalizes a bare domain for link preview and browser opening', () {
    expect(
      LinkPreviewService.firstUrl('Open drive.google.com/file/d/abc/view'),
      'https://drive.google.com/file/d/abc/view',
    );
    expect(
      UrlLauncherUtils.extractFirstUrl('Try example.com.'),
      'https://example.com',
    );
  });

  test('does not treat the domain inside an email address as a link', () {
    expect(
      UrlLauncherUtils.extractFirstUrl('Mail me at user@example.com'),
      isNull,
    );
  });

  test('extracts and normalizes phone numbers but ignores dates', () {
    expect(UrlLauncherUtils.extractPhoneNumbers('Call +880 1712-345678 now'), [
      '+880 1712-345678',
    ]);
    expect(
      UrlLauncherUtils.normalizePhoneNumber('+880 1712-345678'),
      '+8801712345678',
    );
    expect(
      UrlLauncherUtils.extractPhoneNumbers('Meeting date 2026-10-27'),
      isEmpty,
    );
  });
}
