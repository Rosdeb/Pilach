# PILACH MESSENGER - COMPREHENSIVE SOCKET.IO EVENT SPECIFICATION

> **Target Audience:** Frontend Developers, Web Developers, Mobile Engineers, and QA Teams.  
> **Server Endpoint:** `https://messenger.xdtunnel.icu`  
> **Protocol:** Socket.IO v4 Client (`transports: ['websocket']`)

---

## 1. CONNECTION LIFECYCLE & HANDSHAKE

### 1.1 Handshake Configuration
All socket connections require a valid JWT Bearer access token passed in the handshake options.

```typescript
import { io, Socket } from 'socket.io-client';

const socket: Socket = io('https://messenger.xdtunnel.icu', {
  transports: ['websocket'], // WebSocket only, disable HTTP long-polling
  auth: {
    token: accessToken,
  },
  extraHeaders: {
    Authorization: `Bearer ${accessToken}`,
    Cookie: `access_token=${accessToken}`,
  },
  autoConnect: true,
  reconnection: true,
  reconnectionAttempts: Infinity,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 30000,
  timeout: 12000, // 12 seconds connection timeout
});
```

### 1.2 Connection States
| State | Description |
|---|---|
| `connecting` | Initiating handshake with server. |
| `connected` | Handshake completed, session authenticated, rooms joined. |
| `reconnecting` | Disconnected unintentionally; exponential backoff active. |
| `disconnected` | Socket closed manually or terminated by server. |

### 1.3 Built-in Socket.IO Events
- **`connect`**: Socket is open. Server assigns `socket.id`.
  - Re-emit `conversation:join` for all active / foreground rooms.
  - Start presence heartbeat timer (every 25 seconds).
- **`disconnect`**: Connection lost.
  - Reason `io server disconnect`: Server kicked client (e.g. session revoked, force logout). Do **not** auto-reconnect.
  - Reason `ping timeout` / `transport close`: Transient network loss; initiate exponential backoff reconnect.
- **`connect_error`**: Handshake rejected. Check if error is `Unauthorized` or `Token expired`. If so, request a new JWT via `POST /api/v1/auth/refresh` before reconnecting.

---

## 2. ROOM SUBSCRIPTIONS & CONVERSATIONS

Clients must join conversation rooms to receive messages and status events for active chats.

### 2.1 Join Conversation Room
- **Event Name:** `conversation:join`
- **Direction:** Client ➔ Server (supports Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345"
  }
  ```
- **Server Ack Response:**
  ```json
  {
    "ok": true
  }
  ```
  *Error case:* `{ "ok": false, "error": { "code": "FORBIDDEN", "message": "Not a participant in this conversation" } }`

### 2.2 Leave Conversation Room
- **Event Name:** `conversation:leave`
- **Direction:** Client ➔ Server
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345"
  }
  ```

---

## 3. PRESENCE, HEARTBEAT & ONLINE STATUS

### 3.1 Periodic Presence Heartbeat
To keep the server's in-memory presence active, the client must send a heartbeat every **25 seconds**.
- **Event Name:** `presence:heartbeat`
- **Direction:** Client ➔ Server
- **Payload:** `{}` (empty object)

### 3.2 Toggle Online Visibility Preference
Allows users to appear "Offline" while still connected.
- **Event Name:** `presence:visibility`
- **Direction:** Client ➔ Server
- **Payload:**
  ```json
  {
    "visible": true // or false
  }
  ```

### 3.3 Bulk Query Presence
Query current online status and last active timestamp for multiple users (max 200 users per query).
- **Event Name:** `presence:get`
- **Direction:** Client ➔ Server (with Acknowledgement)
- **Payload:**
  ```json
  {
    "userIds": ["usr_uuid_1", "usr_uuid_2", "usr_uuid_3"]
  }
  ```
- **Server Ack Response:**
  ```json
  {
    "ok": true,
    "data": [
      {
        "userId": "usr_uuid_1",
        "isOnline": true,
        "lastSeen": "2026-10-31T04:15:30.000Z"
      },
      {
        "userId": "usr_uuid_2",
        "isOnline": false,
        "lastSeen": "2026-10-30T19:22:00.000Z"
      }
    ]
  }
  ```

### 3.4 Inbound Presence Events
- **`presence:online`** (Server ➔ Client):
  ```json
  {
    "userId": "usr_uuid_1",
    "isOnline": true
  }
  ```
- **`presence:offline`** (Server ➔ Client):
  ```json
  {
    "userId": "usr_uuid_1",
    "isOnline": false,
    "lastSeen": "2026-10-31T04:18:00.000Z"
  }
  ```

---

## 4. MESSAGES: SENDING, EDITING, DELETING & STATUS

### 4.1 Send Message via Socket
*(Note: Can also use HTTP `POST /api/v1/chats/:id/messages` with `Idempotency-Key` for heavy file attachments. Both methods broadcast `message:new`).*
- **Event Name:** `message:send`
- **Direction:** Client ➔ Server (supports Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345",
    "type": "TEXT", // 'TEXT', 'IMAGE', 'VIDEO', 'AUDIO', 'VOICE', 'FILE'
    "text": "Hello world!",
    "replyToId": "msg_parent_uuid", // Optional
    "attachments": [                // Optional
      {
        "type": "IMAGE",
        "url": "uploads/attachments/2026/img.jpg",
        "mimeType": "image/jpeg",
        "fileName": "screenshot.jpg",
        "size": 154200
      }
    ]
  }
  ```
- **Server Broadcast:** Broadcasts `message:new` to all room members.

---

### 4.2 Inbound New Message (`message:new`)
- **Event Name:** `message:new`
- **Direction:** Server ➔ Client
- **Payload:**
  ```json
  {
    "id": "msg_uuid_9999",
    "clientMsgId": "client_generated_uuid",
    "conversationId": "conv_uuid_12345",
    "senderId": "usr_uuid_alice",
    "senderName": "Alice Smith",
    "senderAvatar": "https://cdn.xdtunnel.icu/avatars/alice.jpg",
    "type": "TEXT",
    "text": "Hello world!",
    "createdAt": "2026-10-31T04:20:00.000Z",
    "editedAt": null,
    "isEdited": false,
    "isDeleted": false,
    "isPinned": false,
    "seq": 156,
    "status": "sent",
    "replyToId": null,
    "replyToMessage": null,
    "attachments": [],
    "reactions": []
  }
  ```

---

### 4.3 Edit Message
- **Event Name:** `message:edit`
- **Direction:** Client ➔ Server (with Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345",
    "messageId": "msg_uuid_9999",
    "text": "Corrected message text"
  }
  ```
- **Server Ack Response:**
  ```json
  {
    "ok": true,
    "data": {
      "messageId": "msg_uuid_9999",
      "text": "Corrected message text",
      "editedAt": "2026-10-31T04:21:00.000Z"
    }
  }
  ```
- **Server Broadcast Event:** `message:edited` or `message:updated`
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "messageId": "msg_uuid_9999",
      "text": "Corrected message text",
      "editedAt": "2026-10-31T04:21:00.000Z",
      "isEdited": true
    }
    ```

---

### 4.4 Delete Message (Soft Delete / Tombstone)
- **Event Name:** `message:delete`
- **Direction:** Client ➔ Server (with Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345",
    "messageId": "msg_uuid_9999"
  }
  ```
- **Server Ack Response:**
  ```json
  {
    "ok": true
  }
  ```
- **Server Broadcast Event:** `message:deleted`
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "messageId": "msg_uuid_9999",
      "isDeleted": true
    }
    ```

---

### 4.5 Pin / Unpin Message
- **Event Name:** `message:pin`
- **Direction:** Client ➔ Server (with Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345",
    "messageId": "msg_uuid_9999",
    "isPinned": true // true to pin, false to unpin
  }
  ```
- **Server Ack Response:** `{ "ok": true }`
- **Server Broadcast Event:**
  - When pinned: `message:pinned`
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "messageId": "msg_uuid_9999",
      "isPinned": true,
      "pinnedAt": "2026-10-31T04:22:00.000Z"
    }
    ```
  - When unpinned: `message:unpinned`
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "messageId": "msg_uuid_9999",
      "isPinned": false
    }
    ```

---

### 4.6 Reactions: Add or Remove Emoji Reaction
- **Event Name:** `message:react`
- **Direction:** Client ➔ Server (with Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345",
    "messageId": "msg_uuid_9999",
    "emoji": "👍",
    "isAdded": true // true to add, false to remove
  }
  ```
- **Server Ack Response:** `{ "ok": true }`
- **Server Broadcast Event:** `message:reacted` or `message:reaction_updated`
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "messageId": "msg_uuid_9999",
      "reactions": [
        { "emoji": "👍", "userId": "usr_uuid_bob" },
        { "emoji": "❤️", "userId": "usr_uuid_alice" }
      ]
    }
    ```

---

### 4.7 Realtime Read Receipts & Delivery Status
- **Mark as Read:**
  - **Event Name:** `message:read`
  - **Direction:** Client ➔ Server
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "seq": 156 // highest message sequence visible on screen
    }
    ```
- **Inbound Read Receipt (`message:read_receipt`):**
  - **Direction:** Server ➔ Client
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "userId": "usr_uuid_reader",
      "seq": 156,
      "readAt": "2026-10-31T04:23:00.000Z"
    }
    ```
    *Rule:* All outgoing messages with `seq <= 156` transition status to `seen` (double blue checks).
- **Inbound Delivered Status (`message:delivered`):**
  - **Direction:** Server ➔ Client
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "messageId": "msg_uuid_9999",
      "deliveredAt": "2026-10-31T04:20:05.000Z"
    }
    ```

---

### 4.8 Realtime Typing Indicator
- **Emit Typing:**
  - **Event Name:** `message:typing`
  - **Direction:** Client ➔ Server
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345"
    }
    ```
  - **Client-Side Debounce Rules:**
    1. Only emit on keystroke if text input is **NOT empty or whitespace**.
    2. Emit immediately on the first keystroke (leading edge).
    3. Block redundant emits for **3 seconds**.
    4. When user pauses typing for >3 seconds, reset the debounce flag.
- **Inbound Typing Events:**
  - The server broadcasts on either `user:action`, `user:typing`, or `message:typing`.
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "userId": "usr_uuid_alice",
      "action": "typing",
      "isTyping": true
    }
    ```
  - **UI Rule:** Render animated typing indicator; auto-dismiss after **3.5 seconds** if no subsequent typing event arrives.

---

## 5. CONVERSATION & GROUP METADATA EVENTS

### 5.1 Update Conversation Metadata
Used to update group description, avatar URL, slow mode, or permissions without calling REST.
- **Event Name:** `chat:update`
- **Direction:** Client ➔ Server (with Acknowledgement)
- **Payload:**
  ```json
  {
    "conversationId": "conv_uuid_12345",
    "title": "Engineering Team",
    "avatarUrl": "https://cdn.xdtunnel.icu/avatars/eng.jpg",
    "about": "All discussions related to web & backend",
    "slowModeSeconds": 0
  }
  ```
- **Server Ack Response:** `{ "ok": true }`

### 5.2 Inbound Conversation Updates
- **`chat:updated`** (Server ➔ Client):
  - **Payload:** Full `ChatModel` object.
  - Action: Update chat in sidebar list, title bar, or details drawer.
- **`chat:added`** (Server ➔ Client):
  - **Payload:** Full `ChatModel` object.
  - Action: Prepend new conversation to conversation list and join its room.

### 5.3 Member Role & Membership Updates
- **`member:updated`** (Server ➔ Client):
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "userId": "usr_uuid_bob",
      "role": "ADMIN", // 'OWNER', 'ADMIN', 'MEMBER'
      "adminRights": {
        "canChangeInfo": true,
        "canDeleteMessages": true,
        "canPinMessages": true,
        "canInviteUsers": true
      }
    }
    ```
- **`member:removed`** (Server ➔ Client):
  - **Payload:**
    ```json
    {
      "conversationId": "conv_uuid_12345",
      "userId": "usr_uuid_bob"
    }
    ```
  - *Rule:* If `userId` matches the current authenticated user, leave the conversation room, display a notification ("You were removed from this group"), and navigate back to the chats list.

---

## 6. SECURITY & SESSION TERMINATION

### 6.1 Remote Session Revocation
When a session is revoked (either from Device Management on another device, password change, or admin action), the server sends:
- **Event Name:** `session:revoked`
- **Direction:** Server ➔ Client
- **Payload:**
  ```json
  {
    "sessionId": "sess_uuid_999",
    "reason": "SESSION_REVOKED"
  }
  ```
- **Client Handling Requirement:**
  1. Immediately close the WebSocket (`socket.disconnect()`).
  2. Clear access and refresh tokens from storage.
  3. Clear cached local database/state.
  4. Navigate user to `/login` with toast: *"Your session was terminated from another device"*.

---

## 7. COMPLETE EVENT SUMMARY CHEATSHEET

| Event Name | Direction | ACK? | Description |
|---|:---:|:---:|---|
| `conversation:join` | Client ➔ Server | Yes | Subscribe to real-time events for a chat room |
| `conversation:leave` | Client ➔ Server | No | Unsubscribe from a chat room |
| `presence:heartbeat` | Client ➔ Server | No | Sent every 25 seconds to maintain active presence |
| `presence:visibility` | Client ➔ Server | No | Toggle online active visibility (true/false) |
| `presence:get` | Client ➔ Server | Yes | Bulk query online/last seen for user IDs |
| `presence:online` | Server ➔ Client | - | Broadcasts when a user becomes active |
| `presence:offline` | Server ➔ Client | - | Broadcasts when a user goes offline + lastSeen |
| `message:send` | Client ➔ Server | Yes | Send text/attachments via socket |
| `message:new` | Server ➔ Client | - | Real-time inbound new message |
| `message:typing` | Client ➔ Server | No | Debounced typing keystroke notification |
| `user:typing` / `user:action` | Server ➔ Client | - | Someone in the chat is typing |
| `message:read` | Client ➔ Server | No | Send highest read sequence number |
| `message:read_receipt` | Server ➔ Client | - | Updates messages to double-check seen |
| `message:delivered` | Server ➔ Client | - | Updates message to delivered |
| `message:edit` | Client ➔ Server | Yes | Edit message text |
| `message:edited` / `message:updated` | Server ➔ Client | - | Inbound edited message notification |
| `message:delete` | Client ➔ Server | Yes | Soft-delete a message |
| `message:deleted` | Server ➔ Client | - | Inbound deleted message notification |
| `message:pin` | Client ➔ Server | Yes | Pin or unpin a message |
| `message:pinned` / `message:unpinned` | Server ➔ Client | - | Inbound pin/unpin notification |
| `message:react` | Client ➔ Server | Yes | Add/remove emoji reaction |
| `message:reacted` | Server ➔ Client | - | Inbound emoji reactions snapshot |
| `chat:update` | Client ➔ Server | Yes | Update group title, avatar, or description |
| `chat:updated` | Server ➔ Client | - | Inbound chat metadata change |
| `chat:added` | Server ➔ Client | - | New conversation created / added to user |
| `member:updated` | Server ➔ Client | - | Group member role or permissions changed |
| `member:removed` | Server ➔ Client | - | Group member kicked or left |
| `session:revoked` | Server ➔ Client | - | Force logout triggered by remote session termination |
