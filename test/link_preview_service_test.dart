import 'package:app/core/services/link_preview_service.dart';
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
}
