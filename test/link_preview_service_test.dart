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

  test('keeps a bare domain clickable without creating a preview', () {
    expect(
      LinkPreviewService.firstUrl('Open drive.google.com/file/d/abc/view'),
      isNull,
    );
    expect(
      UrlLauncherUtils.extractFirstUrl('Open drive.google.com/file/d/abc/view'),
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

  test('rejects invalid or local domain names', () {
    expect(
      UrlLauncherUtils.extractFirstUrl('Do not link example.coom'),
      isNull,
    );
    expect(UrlLauncherUtils.extractFirstUrl('Do not link test.local'), isNull);
    expect(UrlLauncherUtils.extractFirstUrl('Do not link -bad.com'), isNull);
    expect(UrlLauncherUtils.isValidWebUrl('https://localhost:8080'), isFalse);
  });

  test('accepts valid generic and country-code domains', () {
    expect(UrlLauncherUtils.isValidWebUrl('https://example.com'), isTrue);
    expect(UrlLauncherUtils.isValidWebUrl('pilach.com.bd'), isTrue);
    expect(UrlLauncherUtils.isValidWebUrl('messenger.xdtunnel.icu'), isTrue);
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
