class ApiConstants {
  // ================================
  // 🌐 Base URLs
  // ================================
  static const String baseUrl = "https://messenger.xdtunnel.icu";
  static const String socketUrl = "https://socket.yourapp.com";

  // ================================
  // 🔐 Auth Endpoints
  // ================================
  static const String login = "/api/v1/auth/login";
  static const String register = "/api/v1/auth/register";
  static const String logout = "/api/v1/auth/logout";
  static const String refreshToken = "/api/v1/auth/refresh";
  static const String verifyOtp = "/api/v1/auth/email/verify/otp";

  // 2FA Endpoints
  static const String twoFactorMethods = "/api/v1/auth/2fa/methods";
  static const String twoFactorEnrollEmailRequest = "/api/v1/auth/2fa/enroll/email/request";
  static const String twoFactorEnrollEmailConfirm = "/api/v1/auth/2fa/enroll/email/confirm";
  static const String twoFactorEnrollSmsRequest = "/api/v1/auth/2fa/enroll/sms/request";
  static const String twoFactorEnrollSmsConfirm = "/api/v1/auth/2fa/enroll/sms/confirm";
  static const String twoFactorChallengeSend = "/api/v1/auth/2fa/challenge/send";
  static const String twoFactorChallengeVerify = "/api/v1/auth/2fa/challenge/verify";
  static const String twoFactorBackupCodes = "/api/v1/auth/2fa/backup-codes";
  static const String twoFactorBackupCodesRegenerate = "/api/v1/auth/2fa/backup-codes/regenerate";

  // ================================
  // 👤 User/Profile
  // ================================
  static const String getProfile = "/api/v1/profile/me";
  static const String updateProfile = "/api/v1/profile";
  static const String uploadAvatar = "/api/v1/profile/avatar";

  // ================================
  // 🏘️ Community
  // ================================
  static const String getCommunities = "/communities";
  static const String createCommunity = "/communities/create";
  static const String joinCommunity = "/communities/join";
  static const String leaveCommunity = "/communities/leave";
  static const String communityDetails = "/communities/details";

  // ================================
  // 💬 Chat / Messages
  // ================================
  static const String getChats = "/chats";
  static const String createChat = "/chats/create";
  static const String getMessages = "/messages";
  static const String sendMessage = "/messages/send";
  static const String deleteMessage = "/messages/delete";

  // ================================
  // 📎 Attachments
  // ================================
  static const String uploadFile = "/upload/file";
  static const String uploadImage = "/upload/image";

  // ================================
  // 🔔 Notifications
  // ================================
  static const String getNotifications = "/notifications";
  static const String markAsRead = "/notifications/read";
  static const String fcmTokens = "/api/v1/fcm-tokens";

  // ================================
  // ⚙️ Settings
  // ================================
  static const String updateSettings = "/settings/update";

  // ================================
  // 📡 Headers
  // ================================
  static const String contentType = "application/json";
  static const String authorization = "Authorization";

  // ================================
  // ⏱️ Timeouts
  // ================================
  static const int receiveTimeout = 15000;
  static const int connectTimeout = 15000;

  // ================================
  // 📄 Pagination
  // ================================
  static const int defaultPage = 1;
  static const int pageSize = 20;
}