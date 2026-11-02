# PILACH MESSENGER - WEB VERSION COMPLETE MASTER SPECIFICATION & PROMPT

> **Instruction for AI / Engineering Team:**  
> This is the single, all-inclusive master blueprint to build the complete **Pilach Messenger Web Application** with 100% feature and API parity with the mobile app, plus native web-first optimizations (QR login, keyboard shortcuts, multi-column desktop layout, drag-and-drop media, and web audio recorder).

---

## 1. PROJECT OVERVIEW & ARCHITECTURE

### Recommended Tech Stack
- **Framework**: Next.js 14/15 (App Router) or React 18+ (Vite) with TypeScript
- **Styling**: Tailwind CSS + Lucide Icons / Heroicons + Framer Motion
- **State Management**: Zustand
- **Server State & Caching**: TanStack Query (React Query)
- **Realtime**: `socket.io-client`
- **HTTP Client**: Axios with Bearer auth and auto-refresh interceptors
- **Audio & Voice**: Web Audio API + MediaRecorder API + wavesurfer.js (or custom canvas waveform)
- **QR / AR Code**: `qrcode.react` (generation) + `html5-qrcode` (webcam / file scanning)

### Server Configuration
- **REST API Base URL**: `https://messenger.xdtunnel.icu`
- **Socket.IO Server URL**: `https://messenger.xdtunnel.icu`
- **WebSocket Transports**: `['websocket']` strictly
- **API Request Timeout**: 15,000ms
- **Socket ACK Timeout**: 12,000ms
- **Theme Color Palette**:
  - Primary Accent (Active/Selected): `#0EB587` (Emerald Green)
  - Unread Badge / Error Color: `#E53935` (Vibrant Red)
  - Tab Bar Tint: `#0EB587`
  - Dark Theme Backgrounds: `#121212`, `#1E1E1E`, `#252525`, Border: `#2E2E2E`
  - Light Theme Backgrounds: `#F7F8FA`, `#FFFFFF`, `#EDEDED`, Border: `#E5E7EB`

---

## 2. AUTHENTICATION, SESSIONS & QR LOGIN SYSTEM

### Standard Token Architecture
- **Access Token**: Placed in `Authorization: Bearer <access_token>` HTTP header and Socket handshake `{ auth: { token } }`.
- **Refresh Token**: Stored in `localStorage` or secure cookie.
- **Auto-Refresh**: On HTTP 401 or Socket auth error, automatically execute `POST /api/v1/auth/refresh` and replay requests.
- **Remote Revoke**: When receiving `session:revoked` via WebSocket, flush local storage and redirect to `/login`.

### QR Code Web Companion Login (WhatsApp Web Style)
1. Web client connects to WebSocket or calls `POST /api/v1/auth/qr/generate` to obtain a temporary pairing session `qrSessionId`.
2. Web displays a live QR code containing `pilach://login?qrSessionId=...` with a 60-second expiration timer.
3. Mobile app opens QR scanner (`QrScanScreen`), scans the QR code, and prompts "Authorize Web Login for Chrome on MacOS?".
4. Mobile approves by posting to `/api/v1/auth/qr/authorize` with its access token.
5. Web client receives `auth:success` event over WebSocket with `{ tokens, user }`, saves tokens, and auto-navigates to `/`.

---

## 3. COMPLETE REST API REFERENCE

### Standard Response Envelopes
**Success:**
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}
```

**Error:**
```json
{
  "success": false,
  "message": "Error description or array of validation errors",
  "error": "ERROR_CODE"
}
```

---

### A. Authentication & Sudo Elevation

#### 1. Login & Registration
- `POST /api/v1/auth/login` -> Body: `{ "email": "user@example.com", "password": "Password123!" }`
  - Returns `{ success: true, tokens: { access, refresh }, user }` OR `{ is2faRequired: true, challengeId: "...", methods: ["email", "sms"] }`
- `POST /api/v1/auth/register` -> Body: `{ "name": "John Doe", "email": "user@example.com", "password": "Password123!" }`
- `POST /api/v1/auth/email/verify/otp` -> Body: `{ "email": "user@example.com", "code": "123456" }`
- `POST /api/v1/auth/email/verify/resend` -> Body: `{ "email": "user@example.com" }`
- `POST /api/v1/auth/password/forgot` -> Body: `{ "email": "user@example.com" }`
- `POST /api/v1/auth/password/reset` -> Body: `{ "token": "...", "password": "..." }`
- `POST /api/v1/auth/password/reset/otp` -> Body: `{ "email": "...", "code": "...", "password": "..." }`
- `POST /api/v1/auth/refresh` -> Body: `{ "refreshToken": "..." }`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/logout-all`
- `GET /api/v1/auth/me` -> Returns current authenticated user

#### 2. OAuth
- `POST /api/v1/auth/oauth/google` -> Body: `{ "idToken": "google_id_token" }`
- `POST /api/v1/auth/oauth/google/link` / `DELETE /api/v1/auth/oauth/google`
- `POST /api/v1/auth/oauth/apple` -> Body: `{ "idToken": "apple_id_token" }`
- `POST /api/v1/auth/oauth/apple/link` / `DELETE /api/v1/auth/oauth/apple`

#### 3. Two-Factor Authentication (2FA)
- `GET /api/v1/auth/2fa/methods` -> List registered 2FA methods
- `POST /api/v1/auth/2fa/enroll/email/request` -> Body: `{ "email": "..." }`
- `POST /api/v1/auth/2fa/enroll/email/confirm` -> Body: `{ "code": "123456" }`
- `POST /api/v1/auth/2fa/enroll/sms/request` -> Body: `{ "phone": "+1234567890" }`
- `POST /api/v1/auth/2fa/enroll/sms/confirm` -> Body: `{ "code": "123456" }`
- `POST /api/v1/auth/2fa/challenge/send` -> Body: `{ "challengeId": "...", "type": "email" | "sms" }`
- `POST /api/v1/auth/2fa/challenge/verify` -> Body: `{ "challengeId": "...", "type": "email", "code": "..." }`
- `DELETE /api/v1/auth/2fa/methods/{methodId}`

#### 4. Sudo Mode (Sensitive Action Elevation)
- `GET /api/v1/auth/sudo/options` -> Check if sudo mode is currently active
- `POST /api/v1/auth/sudo/password` -> Body: `{ "password": "..." }` (Elevates session for 15 minutes)
- `POST /api/v1/auth/sudo/otp/request` & `POST /api/v1/auth/sudo/otp/confirm`

#### 5. Device Sessions Manager
- `GET /api/v1/auth/sessions?includeRevoked=false&limit=150` -> List all active sessions with IP, User-Agent, Device type, and Last Active
- `DELETE /api/v1/auth/sessions/{sessionId}` -> Terminate remote session
- `POST /api/v1/auth/sessions/revoke-others` -> Terminate all except current session
- `PATCH /api/v1/auth/sessions/{sessionId}/primary` -> Mark session as primary

---

### B. User Profile & Account Settings

- `GET /api/v1/profile/me` -> Full user profile
- `PATCH /api/v1/profile` -> Body: `{ "name": "...", "bio": "...", "avatarUrl": "..." }`
- `POST /api/v1/profile/avatar` -> Multipart upload with field `file`
- `GET /api/v1/profile/username/check?username=...` -> Check availability
- `PATCH /api/v1/profile/username` -> Body: `{ "username": "..." }`
- `GET /api/v1/auth/identifiers` -> Returns registered phone numbers & email addresses

---

### C. Chat & Conversation Management

#### 1. Conversation Endpoints
- `GET /api/v1/conversations?limit=150` -> Fetch user's conversation list
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "conv_123",
        "type": "PRIVATE", // or "GROUP"
        "name": "Jane Doe",
        "userId": "usr_jane",
        "avatarUrl": "https://...",
        "lastMessage": { "id": "msg_1", "text": "Hello!", "createdAt": "...", "seq": 10 },
        "unreadCount": 2,
        "isPinned": false,
        "isMuted": false,
        "mutedUntil": null,
        "isOnline": true,
        "lastActive": "2026-10-31T01:00:00Z",
        "memberAvatars": []
      }
    ]
  }
  ```
- `GET /api/v1/conversations/{conversationId}` -> Conversation metadata
- `POST /api/v1/conversations` -> Create chat
  - Body: `{ "type": "PRIVATE" | "GROUP", "title": "Group Name", "userIds": ["usr_1", "usr_2"] }`
- `PATCH /api/v1/conversations/{conversationId}` -> Rename group
  - Body: `{ "title": "New Title" }`
- `POST /api/v1/conversations/{conversationId}/avatar` -> Multipart upload group avatar (`file`)
- `PATCH /api/v1/conversations/{conversationId}/settings` -> Per-user chat settings
  - Body: `{ "isPinned": true, "isArchived": false, "mutedUntil": "2126-10-31T00:00:00Z" }`

#### 2. Group Membership & Permissions
- `GET /api/v1/conversations/{conversationId}/members?page=1&limit=50`
- `POST /api/v1/conversations/{conversationId}/members` -> Body: `{ "userIds": ["usr_3"] }`
- `DELETE /api/v1/conversations/{conversationId}/members/{userId}` -> Kick member
- `PATCH /api/v1/conversations/{conversationId}/members/{userId}/role` -> Body: `{ "role": "ADMIN" | "MEMBER", "adminRights": {...} }`
- `POST /api/v1/conversations/{conversationId}/leave` -> Leave group
- `POST /api/v1/conversations/{conversationId}/owner/transfer` -> Body: `{ "userId": "usr_new_owner" }`
- `PATCH /api/v1/conversations/{conversationId}/permissions` -> Body: `{ "canSendMessages": true, "canSendMedia": true, "canAddMembers": false }`

---

### D. Message Endpoints

#### 1. Fetch & Send
- `GET /api/v1/chats/{chatId}/messages?page=1&limit=30` -> Paginated message history
- `POST /api/v1/chats/{chatId}/messages` -> Send message
  - Headers: `Idempotency-Key: <unique-uuid>`
  - Body:
    ```json
    {
      "type": "TEXT", // 'TEXT', 'IMAGE', 'VIDEO', 'AUDIO', 'VOICE', 'FILE'
      "text": "Message content",
      "replyToId": "msg_parent_id", // Optional
      "attachments": [              // Optional
        {
          "type": "IMAGE",
          "url": "uploads/attachments/xyz.jpg",
          "mimeType": "image/jpeg",
          "fileName": "photo.jpg"
        }
      ]
    }
    ```

#### 2. Search & Media Gallery
- `GET /api/v1/chats/{chatId}/messages/search?q=keyword&page=1&limit=20` -> In-chat search
- `GET /api/v1/messages/search?q=keyword&page=1&limit=20` -> Global search across all chats
- `GET /api/v1/chats/{chatId}/media?kind=media|files|links|audio&page=1&limit=30` -> Media gallery tabs

---

### E. Media & S3 Direct Presigned Upload Pipeline

1. **Request Presigned Upload URL**:
   - `POST /api/v1/uploads/presign`
   - Body: `{ "purpose": "message", "contentType": "image/jpeg", "size": 154200 }`
   - Returns: `{ "data": { "url": "https://s3-presigned-url", "key": "uploads/xyz.jpg", "publicUrl": "https://cdn.xdtunnel.icu/xyz.jpg", "headers": { "Content-Type": "image/jpeg" } } }`
2. **Execute Binary Upload**:
   - Execute HTTP `PUT` directly to `data.url`.
   - Headers: `Content-Type: image/jpeg` and `Content-Length`. (Never send Authorization header).
   - Body: Raw File / Blob / ArrayBuffer.
3. **Use File Key in Message**:
   - Use `key` or `publicUrl` in `attachments: [{ url: key, ... }]`.
4. **Presigned Download Link** (for private files):
   - `GET /api/v1/uploads/presign-download?key={key}`

---

### F. Stories, Privacy, Blocks & Discover Catalog

- **Stories**:
  - `GET /api/v1/stories/feed` -> Feed stories
  - `GET /api/v1/stories/users/{userId}` -> User stories
  - `POST /api/v1/stories` -> `{ "mediaUrl": "...", "caption": "...", "duration": 24 }`
  - `POST /api/v1/stories/{storyId}/views` -> Mark viewed
  - `GET /api/v1/stories/{storyId}/views` -> Viewers list
  - `DELETE /api/v1/stories/{storyId}` -> Delete
- **Privacy Settings**:
  - `GET /api/v1/privacy`
  - `PUT /api/v1/privacy/{scope}` (`LAST_SEEN`, `AVATAR`, `STATUS`, `READ_RECEIPTS`) -> `{ "level": "EVERYONE" | "CONTACTS" | "NOBODY", "allowUserIds": [], "denyUserIds": [] }`
- **Blocks**:
  - `GET /api/v1/blocks?limit=150`
  - `POST /api/v1/blocks` -> `{ "userId": "..." }`
  - `DELETE /api/v1/blocks/{userId}`
  - `GET /api/v1/blocks/{userId}/status` -> `{ "blockedByMe": true/false }`
- **Discover Catalog**:
  - Events, Marketplace, Jobs, News, and Donations (Render interactive catalogs with filter categories, search, and donation progress meters).

---

## 4. REALTIME SOCKET.IO PROTOCOL

### Connection Lifecycle
```typescript
import { io } from 'socket.io-client';

const socket = io('https://messenger.xdtunnel.icu', {
  transports: ['websocket'],
  auth: { token: accessToken },
  extraHeaders: {
    Authorization: `Bearer ${accessToken}`,
    Cookie: `access_token=${accessToken}`
  },
  autoConnect: true,
  reconnection: true,
  reconnectionAttempts: Infinity,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 30000
});
```

### Client-to-Server Emitted Events
| Event | Arguments | Description / Callback |
|---|---|---|
| `presence:heartbeat` | `{}` | Emitted every 25 seconds to maintain active presence |
| `presence:visibility` | `{ visible: boolean }` | Toggle active status visibility |
| `presence:get` | `{ userIds: string[] }` | Bulk query online & last seen statuses |
| `conversation:join` | `{ conversationId }` | Joins chat room for real-time delivery |
| `conversation:leave` | `{ conversationId }` | Leaves chat room |
| `message:typing` | `{ conversationId }` | Emitted on keystroke (only if input is non-empty; debounced 3s) |
| `message:read` | `{ conversationId, seq }` | Marks messages read up to sequence `seq` |
| `message:edit` | `{ conversationId, messageId, text }` | With ACK: updates message text with LWW timestamp |
| `message:delete` | `{ conversationId, messageId }` | With ACK: soft-deletes message (tombstone) |
| `message:pin` | `{ conversationId, messageId, isPinned }` | With ACK: pins or unpins message |
| `message:react` | `{ conversationId, messageId, emoji, isAdded }` | With ACK: adds or removes emoji reaction |
| `chat:update` | `{ conversationId, title, avatarUrl, about }` | With ACK: updates group profile |

### Server-to-Client Inbound Listeners
| Event | Payload | Action |
|---|---|---|
| `message:new` | `MessageModel` | Appends message to chat, bumps conversation to top, increments unread badge |
| `message:edited` / `message:updated` | `{ conversationId, messageId, text, editedAt, isEdited: true }` | Updates text & shows `(edited)` |
| `message:deleted` | `{ conversationId, messageId, isDeleted: true }` | Shows "This message was deleted" |
| `message:pinned` / `message:unpinned` | `{ conversationId, messageId, isPinned, pinnedAt }` | Updates top pinned message bar |
| `message:reacted` / `message:reaction_updated` | `{ conversationId, messageId, reactions: [...] }` | Updates reactions pill row |
| `user:typing` / `message:typing` | `{ conversationId, userId }` | Shows typing indicator for 3.5 seconds |
| `message:read_receipt` | `{ conversationId, userId, seq, readAt }` | Updates checks to double blue/seen |
| `message:delivered` | `{ conversationId, messageId, deliveredAt }` | Updates checkmarks to double grey |
| `presence:online` / `presence:offline` | `{ userId, isOnline, lastSeen }` | Updates online indicator & last active text |
| `chat:updated` / `chat:added` | `ChatModel` | Updates or prepends conversation in sidebar |
| `member:updated` / `member:removed` | `{ conversationId, userId }` | Refreshes member lists & permissions |
| `session:revoked` | `{ sessionId, reason }` | Tearing down socket and auto-logout |

---

## 5. UI, UX & WEB-SPECIFIC ADVANCED FEATURES

### Layout Architecture (Desktop 3-Column WhatsApp Web / Telegram Web Style)
1. **Left Navigation Rail (68px)**:
   - App Logo & Branding
   - Chat icon with unread count badge in Red (`#E53935`)
   - Contacts icon
   - Discover icon (Radar, Stories, Market, Events)
   - Profile & Settings icon
   - Theme switch toggle (Dark / Light)
2. **Left Conversation Sidebar (360px - 400px)**:
   - Search bar (Realtime filter for chats, contacts, and global message query)
   - Stories circle carousel with add story button
   - Filter Tabs: `All`, `Unread`, `Groups`
   - Conversation List:
     - Avatar with green online dot (`#0EB587`) or multi-avatar cluster for groups
     - Title in bold
     - Last message snippet with delivery checkmark icon
     - Timestamp
     - Pinned pin icon
     - Muted speaker icon
     - Red badge with unread count (`#E53935` text, green selected tab `#0EB587`)
3. **Main Chat Workspace (Flex 1)**:
   - **Header**:
     - Contact / Group Avatar + Name
     - Online status / "typing..." animation / "Last seen"
     - Search in conversation button
     - 3-Dot Overflow Menu:
       1. View Contact / Group Info
       2. Search in Conversation
       3. Mute / Unmute Notifications
       4. Change Chat Wallpaper
       5. Delete / Clear Conversation
   - **Pinned Message Bar**:
     - Visible when pinned messages exist in current chat.
     - Click smoothly scrolls to message and flashes a 2-second highlight animation.
   - **Chat Canvas**:
     - Date separator chips (`Today`, `Yesterday`, `October 28, 2026`).
     - Wallpaper support (Preset patterns, solid colors, or custom image uploads).
     - Message Bubbles:
       - Outgoing: Right-aligned, `#0EB587` background with white text, status checkmarks (`sending`, `sent`, `delivered`, `seen`).
       - Incoming: Left-aligned, light grey/surface background with sender name for groups.
       - Context Menu / Hover Menu:
         - **Reply**: Shows quote preview bar above input box.
         - **Edit**: (Sender only) Puts message in edit mode.
         - **Copy**: Copies text to clipboard and triggers a toast notification.
         - **Pin / Unpin**: Toggles pinned status via socket.
         - **React**: Popover with quick emojis (👍, ❤️, 😂, 😮, 😢, 🙏).
         - **Delete**: Soft-delete confirmation modal.
     - Scroll down FAB with unread badge when scrolled up.
   - **Composer Bar**:
     - Attachment drawer (Images, Videos, Audio, Files, Voice Notes).
     - Link Preview generator: Automatically detects URLs, scrapes OG tags (Title, Description, Image), and shows a preview card.
     - Voice Note Recorder: Interactive Web Audio API recorder with live waveform and cancel/send controls.
     - Textarea: Auto-expand, Enter to send, Shift+Enter for new line.
     - Send button debounce: 500ms debounce preventing double dispatches; suppressed if text is empty.
     - Typing debounce: Emits `message:typing` on keystroke, resets after 3 seconds.
4. **Right Details Drawer (Collapsible 340px)**:
   - Profile & About details, Group member list with Admin badges, Shared Media tabs (`Media`, `Files`, `Audio`, `Links`), and Mute / Block / Delete actions.

### QR & Scanner Suite
- **My QR Code**: Displays high-resolution QR code of user ID with Download PNG, Copy Image, and Share buttons.
- **Web QR Scanner**: Built using `html5-qrcode` to scan QR codes via laptop webcam or file drag-and-drop. Automatically extracts user ID and opens or creates direct chat.
- **QR Companion Login**: Web displays login QR code for the mobile app to scan and instantly authenticate.

### Radar Nearby Discovery
- In the Discover tab, render an interactive animated Radar Scanner with concentric pulse ripples.
- Clicking the center radar button simulates scanning for nearby public channels, groups, and friends with smooth hover cards.

### Voice & Audio Messaging
- In-browser microphone recording via `MediaRecorder`.
- Waveform preview canvas during recording.
- Audio player in chat bubbles with Play/Pause, scrubber slider, duration counter, and playback speed toggles (1x, 1.5x, 2x).

### Web Keyboard Shortcuts
- `Cmd+K` / `Ctrl+K`: Global search modal for chats and contacts.
- `Cmd+F` / `Ctrl+F`: In-chat message search.
- `Esc`: Close modal, cancel reply quote, or dismiss search.
- `Enter`: Send message (`Shift+Enter` for line break).
- `Up Arrow`: Edit last sent message in active chat.

---

## 6. TYPESCRIPT DATA MODELS

```typescript
export type ConversationType = 'PRIVATE' | 'GROUP';

export interface ChatModel {
  id: string;
  userId?: string;
  name: string;
  message: string;
  image: string;
  time: string;
  unreadCount: number;
  isOnline: boolean;
  isMuted: boolean;
  isRead: boolean;
  draft?: string;
  isPinned: boolean;
  lastActive?: string;
  type: ConversationType;
  memberAvatars: string[];
}

export type MessageType =
  | 'TEXT'
  | 'IMAGE'
  | 'VIDEO'
  | 'GIF'
  | 'AUDIO'
  | 'VOICE'
  | 'FILE'
  | 'SYSTEM'
  | 'DELETED';

export type MessageStatus = 'sending' | 'sent' | 'delivered' | 'seen' | 'failed';

export interface MessageAttachment {
  type: MessageType;
  url: string;
  mimeType: string;
  fileName: string;
  size?: number;
}

export interface MessageReaction {
  emoji: string;
  userId: string;
}

export interface ReplyMessageModel {
  id: string;
  text: string;
  senderId?: string;
  isDeleted: boolean;
  type?: MessageType;
  mediaUrl?: string;
}

export interface MessageModel {
  id: string;
  clientMsgId?: string;
  conversationId: string;
  senderId?: string;
  senderName?: string;
  senderAvatar?: string;
  type: MessageType;
  text: string;
  time: string;
  timestamp: string;
  isMe: boolean;
  status: MessageStatus;
  mediaUrl?: string;
  isEdited: boolean;
  isDeleted: boolean;
  isPinned: boolean;
  pinnedAt?: string;
  seq?: number;
  replyToId?: string;
  replyToMessage?: ReplyMessageModel;
  attachments?: MessageAttachment[];
  reactions?: MessageReaction[];
}

export interface ContactItem {
  id: string;
  name: string;
  status: string;
  avatarUrl?: string;
  lastMessage?: string;
  conversationId?: string;
  isOnline: boolean;
}

export interface StoryModel {
  id: string;
  userId: string;
  userName: string;
  userAvatar?: string;
  mediaUrl: string;
  caption?: string;
  createdAt: string;
  viewCount: number;
  hasViewed: boolean;
}

export interface LinkPreviewData {
  url: string;
  title?: string;
  description?: string;
  imageUrl?: string;
  domain?: string;
}
```

---

## 7. STEP-BY-STEP IMPLEMENTATION ROADMAP

1. **Step 1: Scaffolding & State Setup**
   - Setup Next.js/React with Tailwind CSS, Lucide icons, Zustand stores (`useAuthStore`, `useChatStore`, `useMessageStore`, `useSettingsStore`).
2. **Step 2: Network & Socket Services**
   - Implement Axios instance with Bearer auth and token auto-refresh.
   - Implement `SocketService` singleton with reconnect backoff, heartbeat (25s), room join/leave, and full event listeners.
   - Implement `UploadService` for S3 direct presigned uploads.
3. **Step 3: Authentication & QR Login**
   - Build `/login`, `/register`, `/verify-otp`, `/forgot-password`.
   - Build QR code companion login on web canvas.
4. **Step 4: Desktop 3-Column Layout & Chat Canvas**
   - Navigation rail, Sidebar with A-Z contact index and stories row.
   - Main chat window with pinned message bar, custom wallpaper, context action menu (Reply, Edit, Copy, Pin, React, Delete), and composer with 500ms debounce.
5. **Step 5: Voice Notes, Link Previews & Media**
   - Waveform audio recorder & player.
   - Link preview cards.
   - S3 image/video/document uploads with progress bars.
6. **Step 6: Discover & Extras**
   - Radar scanner animation for nearby/trending discovery.
   - Stories viewer modal with 24-hour progress segment timers.
   - Device Management & 2FA security settings.
   - Keyboard shortcuts (`Cmd+K`, `Cmd+F`, `Esc`, `Up Arrow`).
