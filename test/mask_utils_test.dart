import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/mask_utils.dart';

void main() {
  group('MaskUtils.maskUserId', () {
    test('returns empty string for null, empty or dummy inputs', () {
      expect(MaskUtils.maskUserId(null), '');
      expect(MaskUtils.maskUserId(''), '');
      expect(MaskUtils.maskUserId('   '), '');
      expect(MaskUtils.maskUserId('***'), '');
      expect(MaskUtils.maskUserId('unknown_user_id'), '');
    });

    test('preserves very short IDs (<= 4 chars)', () {
      expect(MaskUtils.maskUserId('a'), 'a');
      expect(MaskUtils.maskUserId('ab'), 'ab');
      expect(MaskUtils.maskUserId('abc'), 'abc');
      expect(MaskUtils.maskUserId('abcd'), 'abcd');
    });

    test('masks middle for IDs with 5 to 8 characters using ####', () {
      expect(MaskUtils.maskUserId('abcde'), 'ab####de');
      expect(MaskUtils.maskUserId('user123'), 'us####23');
      expect(MaskUtils.maskUserId('12345678'), '12####78');
    });

    test('masks middle for IDs with 9 to 14 characters using ######', () {
      expect(MaskUtils.maskUserId('user-1234'), 'use######234');
      expect(MaskUtils.maskUserId('user-123456'), 'use######456');
    });

    test('masks middle for long IDs (e.g. UUIDs or Mongo IDs) with 6 prefix and 4 suffix', () {
      expect(
        MaskUtils.maskUserId('9ac8fd12-312a-4ed6-80a8-a68423c5bd86'),
        '9ac8fd######bd86',
      );
      expect(
        MaskUtils.maskUserId('60d5ecb8b5c9c1234567890a'),
        '60d5ec######890a',
      );
    });
  });
}
