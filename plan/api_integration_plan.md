# Pilach Frontend API Integration Plan

Based on the `frontend-api-docs.md` and a thorough review of the current codebase, here is a structured, high-performance integration plan.

The app currently uses **Flutter Riverpod** for state management and **Dio** for REST API calls. The plan outlines how to integrate the robust REST and WebSocket requirements defined in the API docs while maintaining high performance and clean architecture.

## 1. Dependencies to Add
To support the Real-time WebSockets and complex data mapping, you'll need the following packages added to your `pubspec.yaml`:
- **`socket_io_client`**: Required to connect to the `/` namespace as specified in the docs.
- *(Optional but Highly Recommended)* **`freezed` & `json_serializable`**: For robust, type-safe data modeling, minimizing JSON parsing errors.

```yaml
dependencies:
  socket_io_client: ^2.0.3
  # Add these if you want to use code generation for models
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  build_runner: ^2.4.8
  freezed: ^2.4.7
  json_serializable: ^6.7.1
```

---

## 2. Data Models (Domain Layer) & UI Adapter
To ensure **zero breaking changes to your UI** or performance regressions, we will use a DTO (Data Transfer Object) adapter pattern. This isolates the backend JSON structure from your existing presentation code.

### API Models
First, we extend your existing `ApiResponse` to support the pagination object provided by the `GET /api/v1/conversations` endpoint:

```dart
class ApiPaginatedResponse<T> extends ApiResponse<List<T>> {
  final Pagination pagination;
  // ...
}

class Pagination {
  final String mode;
  final int total, page, limit, totalPages;
  final bool hasNext, hasPrev;
  // ... factory fromJson
}
```

Create a DTO for the backend Chat entity matching the explicit JSON:
```dart
class ChatDto {
  final String id;
  final String type; // PRIVATE or GROUP
  final String? title;
  final String? avatarUrl;
  final int unreadCount;
  final String createdAt;
  final dynamic lastMessageSeq; // API returns string "0" in GET and number 0 in POST
  // ... other fields from JSON
}
```

### UI Adapter (Zero UI Changes)
Your UI currently relies on `ChatModel` (`lib/Features/Chat/data/models/chat_model.dart`). We will map the backend `ChatDto` to the UI `ChatModel` at the repository layer, completely shielding the UI from the changes:

```dart
extension ChatDtoMapper on ChatDto {
  ChatModel toDomain() {
    return ChatModel(
      id: id,
      name: title ?? 'Unknown', // Fallback for PRIVATE chats with null title
      message: '...', // Extract from lastMessage when available
      image: avatarUrl ?? '', // Provide default avatar if null
      time: '12:00 PM', // Format from createdAt or lastMessageAt
      unreadCount: unreadCount,
      isOnline: false, // Update via separate presence socket events
      isMuted: false,
      isRead: unreadCount == 0,
      isPinned: false,
    );
  }
}
```
With this, the presentation layer (Screens, Widgets, UI Providers) remains untouched and fully performant.

---

## 3. Real-Time WebSockets (`SocketService`)
The existing `lib/core/services/socket_service.dart` is empty. We will implement it as a singleton or a Riverpod provider that manages the `socket.io` connection.

**Responsibilities:**
- Initialize connection to the base URL (`/` namespace) with authentication headers (tokens from `TokenService`).
- Provide methods to **emit** events (e.g., `sendMessage`, `editMessage`, `readMessage`, `typing`).
- Expose Dart `Stream`s for incoming events (e.g., `onNewMessage`, `onMessageEdited`, `onTyping`, `onReadReceipt`).

**Performance Tip:** Use `StreamController.broadcast()` so multiple Riverpod providers (or UI components) can listen to socket events without creating multiple connections.

---

## 4. REST Repositories (`lib/core/network/`)
Extend the existing `ApiService` by creating specific repositories that handle the business logic and serialization.

- **`ProfileRepository`**: Handles `GET /profile/username/check/:username`.
- **`ChatRepository`**: 
  - `GET /conversations` (with limit/offset pagination)
  - `POST /conversations`
  - `PATCH` and `DELETE` endpoints for group management.
- **`MessageRepository`**:
  - `GET /chats/:chatId/messages` (with cursor pagination using `seq`).
  - Implements the Media Upload Flow.

---

## 5. Media Upload Workflow (High Performance)
The API dictates that media must be uploaded *before* the message is sent.

**Implementation Steps in `MessageRepository.sendMediaMessage()`**:
1. **Get Presigned URL**: `POST /api/v1/uploads/presign` with the file's content type.
2. **Direct Upload (PUT)**: Use `Dio` to upload the raw binary file directly to the returned `presignedUrl`. Avoid loading large files entirely into RAM; use `MultipartFile.fromFile` streams.
3. **Send Message**: Once the upload completes, take the `publicUrl` and emit `message:send` via `SocketService` with the Attachment JSON payload.

**UX Best Practice**: Optimistically add a "pending" message to the UI with a local file thumbnail and a circular progress indicator while the HTTP upload happens.

---

## 6. State Management (Riverpod Providers)
Since Riverpod is already in the project, we should use it to bridge the REST repositories and the WebSocket streams seamlessly.

- **`chatsProvider` (`AsyncNotifier<List<Chat>>`)**: 
  - Fetches the initial chat list via REST.
  - Listens to `SocketService` streams (`chat:updated`, `message:new`) to re-order the chat list (bringing chats to the top when a new message arrives) and update unread counts instantly.

- **`messagesProvider(String chatId)` (`FamilyAsyncNotifier<List<Message>, String>`)**:
  - Fetches paginated message history via REST.
  - Uses the `seq` of the oldest message for the `cursor` to load more history (infinite scroll).
  - Listens to `SocketService.onNewMessage`. If `message.conversationId == chatId`, it appends the message to the list *instantly* without refetching from REST.
  - Handles `message:read_receipt` to update double-ticks (✓✓) on all messages with `seq <= receipt.seq`.

- **`typingProvider(String chatId)` (`StateNotifier<List<String>>`)**:
  - Briefly shows who is typing. Listens to `user:action` (typing) from the socket and uses a `Timer` to clear the typing status after 3-5 seconds if no new typing event arrives.

---

## 7. Performance & Optimization Checklist
1. **Local Caching / Persistence**: Use `shared_preferences` (already in `pubspec`) to cache the latest `Chat` list so the app opens instantly offline, then syncs gracefully.
2. **Pagination Management**: For messages, only load 30 at a time as requested (`limit=30`). Render lists using `ListView.builder` or `SliverList` to keep memory consumption low.
3. **Image Caching**: You have `cached_network_image` installed. Use it for all `Attachment` URLs to prevent re-downloading images.
4. **Optimistic UI Updates**: When a user sends a text message or a reaction, immediately update the local Riverpod state so the UI feels instantaneous, and let the WebSocket emit happen in the background. If it fails, revert the state and show a retry icon.
