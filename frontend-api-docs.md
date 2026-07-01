# Frontend API Integration Guide

Base URL for all REST endpoints: `/api/v1`

## 1. Profile & Users

### Check Username Availability
- **Method:** `GET`
- **Path:** `/profile/username/check/:username`
- **Response:** `{ data: { available: true/false } }`

---

## 2. Conversations (Chats)

### Get Chat List
- **Method:** `GET`
- **Path:** `/conversations`
- **Query Params:** `?limit=30&cursor=&query=` (query searches group titles)
- **Response:** `{ data: [...], pagination: { mode: "offset", ... } }`

### Get Single Chat
- **Method:** `GET`
- **Path:** `/conversations/:id`

### Create a Chat
- **Method:** `POST`
- **Path:** `/conversations`
- **Body:**
  ```json
  {
    "type": "PRIVATE", // or "GROUP"
    "title": "My Group", // optional, only for groups
    "userIds": ["user-id-1", "user-id-2"]
  }
  ```

### Rename a Group
- **Method:** `PATCH`
- **Path:** `/conversations/:id`
- **Body:** `{ "title": "New Name" }`

### Add Members to a Group
- **Method:** `POST`
- **Path:** `/conversations/:id/members`
- **Body:** `{ "userIds": ["user-id-3"] }`

### Remove a Member (Kick / Leave)
- **Method:** `DELETE`
- **Path:** `/conversations/:id/members/:userId`

---

## 3. Messages (REST)

### Get Messages (Pagination)
- **Method:** `GET`
- **Path:** `/chats/:chatId/messages`
- **Query Params:** `?limit=30&cursor=&query=` (cursor is the `seq` of the oldest message loaded)
- **Response:** `{ data: [...], pagination: { mode: "cursor", nextCursor: "...", hasNext: true } }`

### Send a Message (REST Fallback)
*Note: You can use this for sending messages via HTTP (e.g. for heavy file uploads). It will automatically broadcast to the WebSocket.*
- **Method:** `POST`
- **Path:** `/chats/:chatId/messages`
- **Body:** 
  ```json
  {
    "type": "TEXT",
    "text": "Hello world",
    "attachments": [
      {
        "type": "IMAGE",
        "url": "https://r2.bucket.com/path",
        "mimeType": "image/jpeg"
      }
    ]
  }
  ```

---

## 4. WebSockets (Real-Time)

**Connection:** Connect via Socket.io to the root `/` namespace.

### Emit to Server (Actions)

1. **Send Message:**
   - Event: `message:send`
   - Payload:
     ```json
     {
       "conversationId": "uuid",
       "text": "Hello",
       "type": "TEXT",
       "attachments": [
         {
           "type": "IMAGE",
           "url": "https://r2.bucket.com/path",
           "mimeType": "image/jpeg"
         }
       ]
     }
     ```

2. **Edit Message:**
   - Event: `message:edit`
   - Payload:
     ```json
     {
       "messageId": "uuid",
       "text": "Edited text"
     }
     ```

3. **Delete Message:**
   - Event: `message:delete`
   - Payload:
     ```json
     {
       "messageId": "uuid"
     }
     ```

4. **Mark as Read:**
   - Event: `message:read`
   - Payload:
     ```json
     {
       "conversationId": "uuid",
       "seq": 123 
     }
     ```
     *(send highest message seq visible on screen)*

5. **Typing Indicator:**
   - Event: `message:typing`
   - Payload:
     ```json
     {
       "conversationId": "uuid"
     }
     ```

6. **Toggle Reaction:**
   - Event: `message:react`
   - Payload:
     ```json
     {
       "messageId": "uuid",
       "emoji": "👍",
       "isAdded": true
     }
     ```

7. **Pin/Unpin Message:**
   - Event: `message:pin`
   - Payload:
     ```json
     {
       "conversationId": "uuid",
       "messageId": "uuid",
       "isPinned": true
     }
     ```

### Listen from Server (Updates)

1. **New Message Received:**
   - Event: `message:new`
   - Payload: `Message` object

2. **Message Edited:**
   - Event: `message:edited`
   - Payload: `Message` object

3. **Message Deleted:**
   - Event: `message:deleted`
   - Payload:
     ```json
     {
       "messageId": "uuid"
     }
     ```

4. **Read Receipt (Update Double Ticks):**
   - Event: `message:read_receipt`
   - Payload:
     ```json
     {
       "conversationId": "uuid",
       "seq": 123
     }
     ```
     *(Any messages you sent with seq <= this value are now read ✓✓)*

5. **Someone is Typing:**
   - Event: `user:action`
   - Payload:
     ```json
     {
       "userId": "uuid",
       "action": "typing"
     }
     ```

6. **Reaction Changed:**
   - Event: `message:reacted`
   - Payload: `MessageReaction` object

7. **Message Pin Toggled:**
   - Event: `message:pinned` or `message:unpinned`
   - Payload: `Message` object

8. **Chat Metadata Changed:**
   - Event: `chat:updated`
   - Payload: `Chat` object

9. **Membership Changed:**
   - Event: `member:updated`
   - Payload: `ChatMember` object

---

## 5. Message Types & Media Uploads

The `type` field on a message dictates how the frontend should render it. The supported values are:
- `TEXT` (Default)
- `IMAGE`
- `VIDEO`
- `GIF` (Muted looping video)
- `AUDIO` (Music / voice notes)
- `VOICE` (Voice notes)
- `FILE` (Arbitrary documents)
- `POLL`
- `LOCATION`
- `CONTACT`
- `SYSTEM` (e.g., "Alice joined the group")

### How to Send Media Files (Images, Videos, etc.)

Media is NOT sent directly through the WebSocket. You must upload the file to cloud storage first, then send the message with the returned URL.

**Step 1: Get an Upload URL**
- **Method:** `POST /api/v1/uploads/presign`
- **Body:**
  ```json
  {
    "purpose": "MESSAGE_ATTACHMENT",
    "contentType": "image/jpeg"
  }
  ```
- **Response:** Returns a `presignedUrl` (for uploading) and a `publicUrl` (for viewing).

**Step 2: Upload the File**
- Do an HTTP `PUT` request directly to the `presignedUrl` with the raw file binary as the body.

**Step 3: Send the Message**
- Emit the `message:send` socket event (or use the REST fallback). 
- Pass the URL inside the `attachments` array in your JSON payload.
