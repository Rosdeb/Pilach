class Assets {
  // ================================
  // 📁 Base Paths
  // ================================
  static const String _imagePath = 'assets/images';
  static const String _iconPath = 'assets/icons';
  static const String _lottiePath = 'assets/lottie';

  // ================================
  // 🖼️ Images
  // ================================
  static const String logo = '$_imagePath/logo.svg';
  static const String splashBg = '$_imagePath/splash_bg.png';
  static const String authBg = '$_imagePath/auth_bg.png';
  static const String emptyState = '$_imagePath/empty.png';

  // Profile
  static const String defaultAvatar =
      '$_imagePath/default_avatar.png';

  // ================================
  // 🎨 Icons (SVG or PNG)
  // ================================
  static const String homeIcon = '$_iconPath/Chat.svg';
  static const String chatIcon = '$_iconPath/chat.svg';
  static const String sendIcon = '$_iconPath/send.svg';
  static const String profileIcon = '$_iconPath/profile.svg';
  static const String notificationIcon = '$_iconPath/notification.svg';

  // ================================
  // 🎬 Lottie (optional)
  // ================================
  static const String loading = '$_lottiePath/loading.json';
  static const String success = '$_lottiePath/success.json';
  static const String trash = '$_iconPath/trash.png';
}