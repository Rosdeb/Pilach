class Logger {
  static void log(String message, {String type = "info"}) {
    const reset   = '\x1B[0m';
    const green   = '\x1B[32m';
    const yellow  = '\x1B[33m';
    const red     = '\x1B[31m';
    const cyan    = '\x1B[36m';
    const magenta = '\x1B[35m';
    const blue    = '\x1B[34m';

    switch (type) {
      case "success":
        print("$green✅ $message$reset");
        break;
      case "warning":
        print("$yellow⚠️  $message$reset");
        break;
      case "error":
        print("$red❌ $message$reset");
        break;
      // App lifecycle events (resumed / paused / etc.)
      case "lifecycle":
        print("$magenta🔄 [LIFECYCLE] $message$reset");
        break;
      // Socket connection state changes
      case "socket":
        print("$blue🔌 [SOCKET] $message$reset");
        break;
      default:
        print("$cyanℹ️  $message$reset");
    }
  }
}