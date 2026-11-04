/// Utility functions for masking sensitive identifiers across the app.
class MaskUtils {
  const MaskUtils._();

  /// Masks the middle portion of a user ID with hash characters (`#`).
  ///
  /// Examples:
  /// - `9ac8fd12-312a-4ed6-80a8-a68423c5bd86` -> `9ac8fd######bd86`
  /// - `60d5ecb8b5c9c1234567890a` -> `60d5ec######890a`
  /// - `user-123456` -> `use######456`
  /// - `user123` -> `us####23`
  /// - Short IDs (<= 4 chars) are returned as-is
  static String maskUserId(String? id) {
    if (id == null) return '';
    final clean = id.trim();
    if (clean.isEmpty || clean == '***' || clean == 'unknown_user_id') {
      return '';
    }
    if (clean.length <= 4) {
      return clean;
    }
    if (clean.length <= 8) {
      return '${clean.substring(0, 2)}####${clean.substring(clean.length - 2)}';
    }
    if (clean.length <= 14) {
      return '${clean.substring(0, 3)}######${clean.substring(clean.length - 3)}';
    }
    return '${clean.substring(0, 6)}######${clean.substring(clean.length - 4)}';
  }
}
