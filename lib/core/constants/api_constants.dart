class ApiConstants {
  // ================================
  // 🌐 Base URLs
  // ================================
  static const String baseUrl = "https://api.yourapp.com";
  static const String socketUrl = "https://socket.yourapp.com";

  // ================================
  // 🔐 Auth Endpoints
  // ================================
  static const String login = "/auth/login";
  static const String register = "/auth/register";
  static const String logout = "/auth/logout";
  static const String refreshToken = "/auth/refresh-token";

  // ================================
  // 👤 User/Profile
  // ================================
  static const String getProfile = "/user/profile";
  static const String updateProfile = "/user/update";
  static const String uploadAvatar = "/user/avatar";

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