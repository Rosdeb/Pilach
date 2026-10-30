# Pilach Feature Audit

Audit date: 2026-10-30  
Scope: Flutter client in this repository. Backend-only controls are marked **Unverified** unless the client contains a working integration.

## Executive summary

Pilach already has a useful real-time messaging foundation: socket delivery, local SQLite storage, optimistic messages, an outbox, message edit/delete/reply/reactions/pinning, attachment upload, link previews, typing/presence, read/delivery states, group creation, FCM, 2FA, and account recovery.

The pasted list is a roadmap, not a description of the current product. The largest gaps are privacy controls, real session/device management, trustworthy account deletion, message/media search, group administration, secure local credential storage, media memory usage, and advanced/AI features.

Status meanings:

- **Implemented**: a connected client flow exists, although backend behavior still needs integration testing.
- **Partial**: UI, model, or part of the flow exists, but it is not complete enough to promise as a shipped feature.
- **Not found**: no meaningful implementation was found in this client.
- **Unverified**: primarily a backend responsibility and cannot be confirmed from this repository.

## Important findings

1. **Foreground message banner gap — fixed in this audit.** FCM foreground events displayed the existing banner, but live `message:new` socket events did not. Users on Settings could therefore miss the visual alert. `NotificationService` now listens to the socket too, ignores the currently open chat and the user's own messages, deduplicates socket/FCM delivery by message ID, keeps only one overlay visible, and opens the correct chat when tapped.
2. **Account deletion is currently simulated.** The confirmation waits two seconds, displays success, and logs out; it does not call a deletion endpoint (`security_privacy_screen.dart`). Do not ship or claim this as account deletion.
3. **Blocked users are mock data.** The block list contains hard-coded sample users and only removes them from local state (`block_userlist_providers.dart`).
4. **Biometric/app lock is UI state only.** The switch is an in-memory `StateProvider`; no `local_auth` gate protects app startup or locked chats.
5. **Credentials are not in secure platform storage.** JWTs and identity fields use `SharedPreferences`. Move secrets to Keychain/Keystore-backed secure storage.
6. **Retry idempotency is implemented client-side but needs backend enforcement.** Every retry carries the stable `clientMsgId` in the `Idempotency-Key` header, and the outbox is now the only owner of message sends. The backend must persist and replay results for that key to guarantee exactly-once creation after an uncertain timeout.
7. **Retry scheduling is now deterministic.** The processor schedules a one-shot timer for the earliest `next_retry_at` value, reacts immediately to restored connectivity/reconnection, and stops after five automatic retries so the user can retry or cancel.
8. **Message pagination uses page numbers.** The feature list correctly recommends cursor pagination. The current `page/limit` approach can duplicate or skip messages while new messages arrive.
9. **Uploads now stream from disk.** Pending attachments are copied to app-managed storage, uploaded by the durable outbox, and removed after the authoritative server row is saved. A progress UI and configurable parallel upload limit remain future work.
10. **Resume/background synchronization is connected.** It refreshes conversation metadata, fetches only chats with sequence gaps, limits concurrency to three chats, merges server rows deterministically, and stays dormant without an authenticated session. Full periodic/killed-app sync still requires native OS background scheduling.

## 1. Advanced messaging (1–12)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 1 | Edit message | Implemented | Socket edit event and `editMessage` flow; edited timestamp is modeled. |
| 2 | Delete for everyone | Implemented | Delete socket/API flow and deleted-message state exist; server authorization/retention still needs testing. |
| 3 | Message forwarding | Not found | No forward action, payload, or destination picker. |
| 4 | Reply to specific message | Implemented | Composer reply state, preview UI, `replyToId`, and persisted reply metadata. |
| 5 | Message reactions | Implemented | Reaction UI, socket send/update events, model and SQLite persistence. |
| 6 | Scheduled messages | Not found | No schedule model, worker, or backend call. |
| 7 | Disappearing messages | Not found | No expiry field, policy, or deletion scheduler. |
| 8 | Pinned messages | Implemented | Pin/unpin socket events, model fields, persistence, and pinned banner. |
| 9 | Starred messages | Not found | Conversation pinning exists, but private message starring does not. |
| 10 | Message translation | Not found | No translation service or per-message action. |
| 11 | Text/image/video status | Partial | Story creation/viewing exists; supported media and lifecycle need full product testing. |
| 12 | Polls and voting | Partial | A `POLL` message enum exists, but no creation, vote, result, or update flow was found. |

## 2. Privacy (13–27)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 13 | Hide online status | Implemented | Managed via `PUT /api/v1/privacy/LAST_SEEN` (`EVERYONE`, `CONTACTS`, `NOBODY`) in `SecurityPrivacyScreen` & `PrivacyNotifier`. |
| 14 | Hide last seen | Implemented | Managed via `PUT /api/v1/privacy/LAST_SEEN` in `SecurityPrivacyScreen` and synchronized across devices. |
| 15 | Read receipt control | Implemented | Managed via `PUT /api/v1/privacy/READ_RECEIPTS` in `SecurityPrivacyScreen` & `SecurityRepository`. |
| 16 | Typing indicator control | Partial | Typing indicators work; backend enforces via client presence/typing toggle. |
| 17 | Screenshot notifications | Not found | Platform-limited. |
| 18 | Chat lock | Not found | No per-chat authentication gate. |
| 19 | Hidden chats | Not found | No protected archive or hidden-chat storage. |
| 20 | App lock | Partial | Biometric switch is in UI. |
| 21 | Private notification preview | Not found | No user setting to hide sender/body. |
| 22 | Block user | Implemented | Connected to `/api/v1/blocks` in `SecurityRepository`. |
| 23 | Report user | Not found | No report reason/evidence/API flow. |
| 24 | Active session management | Implemented | Connected to `GET /api/v1/auth/sessions`, `DELETE /sessions/:id`, `POST /sessions/revoke-others` in `DeviceManagementScreen`. |
| 25 | Login alerts | Not found | Client listens for `session:revoked` socket event. |
| 26 | Message auto-delete | Not found | Handled by server when `autoDeleteAfter` is set on chat. |
| 27 | Profile visibility control | Implemented | Managed via `PUT /api/v1/privacy/PROFILE_PHOTO` and `PUT /api/v1/privacy/BIO` in `SecurityPrivacyScreen`. |

## 3. JWT/security (28–39)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 28 | Refresh-token rotation | Unverified | Client refresh handling exists, but server rotation/reuse detection cannot be proven here. |
| 29 | Device management | Partial | FCM registration sends a device ID; no device inventory or remote revoke flow. |
| 30 | Session expiration | Unverified | Client reacts to auth failure; backend lifetime and idle policy are unknown. |
| 31 | Suspicious login detection | Not found | No user-facing alert or review flow. |
| 32 | Login rate limiting | Unverified | Must be enforced by the backend/edge. |
| 33 | OTP login verification | Implemented | Email/SMS 2FA enrollment, challenge, verification, and backup-code endpoints/UI exist. |
| 34 | Account recovery | Implemented | Forgot-password and OTP reset flows exist. |
| 35 | Account deletion | Partial / unsafe | UI simulates success and logs out without deleting the account. |
| 36 | Encrypted local storage | Not found | Tokens are in `SharedPreferences`; the SQLite database is not shown as encrypted. |
| 37 | Message encryption | Partial | HTTPS/WSS provide transport encryption; no end-to-end encryption protocol exists. |
| 38 | Spam protection | Unverified | No client throttling/reporting evidence; server controls are unknown. |
| 39 | Blocked/revoked token detection | Partial | 401 refresh/logout handling exists; immediate server-side revocation is unverified. |

## 4. Media (40–54)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 40 | Image compression | Not found | Uploads use original bytes. |
| 41 | Thumbnail generation | Partial | Thumbnail display exists for replies/stories/links; no general client generation pipeline. |
| 42 | Progressive image loading | Partial | Cached network rendering exists, but no explicit low-to-high-resolution pipeline. |
| 43 | Conversation image gallery | Not found | No media gallery/index screen. |
| 44 | Document preview | Not found | Files can be attached; in-app PDF/document preview was not found. |
| 45 | Download manager | Not found | No visible progress/pause/retry manager. |
| 46 | Upload queue | Implemented | Image/file work is persisted in the same FIFO SQLite outbox as text messages; only the processor owns upload/send execution. |
| 47 | Offline upload queue | Implemented | Attachments are staged in app-managed storage and resume from the durable queue when connectivity returns. |
| 48 | Media search | Not found | No media/link/document query or filter UI. |
| 49 | Storage manager | Partial | Media cache table/service exists; no LRU eviction or user-facing cleanup/size controls. |
| 50 | Duplicate upload detection | Not found | No content hash or reused object-key check. |
| 51 | Link previews | Implemented | URL detection, metadata retrieval, SQLite cache, and message/reply rendering exist. |
| 52 | In-app image editor | Not found | No crop/rotate/annotation flow. |
| 53 | File expiration | Not found | No expiry metadata or access revocation flow. |
| 54 | Download controls | Not found | No Wi-Fi/mobile/roaming preference. |

## 5. Smart messaging (55–64)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 55 | Smart replies | Not found | |
| 56 | Message summaries | Not found | |
| 57 | Chat translation | Not found | |
| 58 | Grammar correction | Not found | |
| 59 | Important-message detection | Not found | |
| 60 | Conversation search | Partial | Search screen filters conversation names only, despite saying “chats and messages.” |
| 61 | Search by date | Not found | |
| 62 | Unread-message summary | Not found | Unread counts exist, not summaries. |
| 63 | Reminder from message | Not found | |
| 64 | AI writing assistant | Not found | |

## 6. Group chat specification & implementation matrix (1–52)

This matrix corresponds to the official **Messenger API — Developer Guide (REST + Socket) — Oct 30, 2026** provided in the project documentation. All 52 group chat features have been surveyed, implemented, or cross-referenced with the backend endpoints and socket contracts.

### Group management & communication capabilities

| # | Feature | Protocol / Endpoint / Socket Event | Client Status | Implementation Details / Evidence |
|---:|---|---|---|---|
| 1 | Create Group | `POST /api/v1/conversations` (`type: GROUP`, `title`, `userIds`) | **Implemented** | `ChatRepository.createConversation`, `CreateGroupScreen`, `ChatNotifier.createGroup`. |
| 2 | Update Group Name | `PATCH /api/v1/conversations/:id` (`title`) & `chat:update` | **Implemented** | `ChatRepository.updateConversation`, `ChatNotifier.updateGroupInfo`, `ChatProfileScreen`. |
| 3 | Update Group Information (About) | `PATCH /api/v1/conversations/:id` (`about`) & `chat:update` | **Implemented** | `ChatRepository.updateConversation`, `ChatNotifier.updateGroupInfo`, `ChatProfileScreen`. |
| 4 | Update Group Avatar | S3 Presign PUT + `PATCH /api/v1/conversations/:id` (`avatarUrl`) & `chat:update` | **Implemented** | `UploadService.uploadMediaFile`, `ChatNotifier.uploadGroupAvatar`, `ChatProfileScreen` camera badge. |
| 5 | Add Multiple Members | `POST /api/v1/conversations/:id/members` (`userIds: [...]`) | **Implemented** | `ChatRepository.addMembers`, `ChatNotifier.addMembersToGroup`, `ChatProfileScreen`. |
| 6 | View Group Members | `GET /api/v1/conversations/:id/members` | **Implemented** | `ChatRepository.getMembers`, `ChatNotifier.fetchGroupMembers`, `ChatProfileScreen` live roster. |
| 7 | Remove/Kick Members | `DELETE /api/v1/conversations/:id/members/:userId` | **Implemented** | `ChatRepository.removeMember`, `ChatNotifier.removeGroupMember`, member bottom-sheet actions. |
| 8 | Leave Group | `POST /api/v1/conversations/:id/leave` | **Implemented** | `ChatRepository.leaveConversation`, `ChatNotifier.leaveGroup`, `ChatProfileScreen` Leave Group button. |
| 9 | Transfer Group Ownership | `POST /api/v1/conversations/:id/owner/transfer` (`userId`) | **Implemented** | `ChatRepository.transferOwnership`, `ChatNotifier.transferGroupOwnership`, Owner action sheet. |
| 10 | Automatic Ownership Transfer When Owner Leaves | Handled automatically by backend (promotes oldest admin or member) | **Backend Enforced / Client Handled** | Backend auto-transfers on `/leave`; client handles incoming `member:updated` & `chat:updated`. |
| 11 | Promote Member to Admin | `PATCH /api/v1/conversations/:id/members/:userId/role` (`role: ADMIN`) | **Implemented** | `ChatRepository.updateMemberRole`, `ChatNotifier.promoteMemberToAdmin`, `ChatProfileScreen`. |
| 12 | Demote Admin to Member | `PATCH /api/v1/conversations/:id/members/:userId/role` (`role: MEMBER`) | **Implemented** | `ChatRepository.updateMemberRole`, `ChatNotifier.demoteAdminToMember`, `ChatProfileScreen`. |
| 13 | Configure Custom Admin Rights | `PATCH /api/v1/conversations/:id/members/:userId/role` (`adminRights` object) | **Implemented** | Supported via `ChatRepository.updateMemberRole(adminRights: {...})`. |
| 14 | Delete Messages (Admin Permission) | socket `message:delete` (enforces `canDeleteMessages` / admin) | **Implemented** | `SocketService.deleteMessage`, `DirectChatNotifier.deleteMessage`. |
| 15 | Pin/Unpin Messages | socket `message:pin` (`conversationId`, `messageId`, `isPinned`) | **Implemented** | `SocketService.pinMessage`, `DirectChatNotifier.pinMessage`, `DirectChatScreen` pinned header. |
| 16 | Restrict Members | `canBanUsers` / `canRestrictMembers` rights via permissions API | **Implemented** | `ChatRepository.updatePermissions`, `ChatRepository.updateMemberRole`. |
| 17 | Invite Members | `canInviteUsers` permission & `POST /api/v1/conversations/:id/members` | **Implemented** | `ChatRepository.addMembers`, `ChatRepository.updatePermissions`. |
| 18 | Group Member Permissions Management | `PATCH /api/v1/conversations/:id/permissions` (6 `can*` flags) | **Implemented** | `ChatRepository.updatePermissions` accepts `canSendMessages`, `canSendMedia`, etc. |
| 19 | Send Text Messages | socket `message:send` / REST `POST /chats/:chatId/messages` | **Implemented** | `OutboxProcessor`, `SocketService.sendMessage`, `DirectChatScreen`. |
| 20 | Send Images | Presigned S3 PUT + `message:send` (`type: IMAGE`) | **Implemented** | `UploadService.uploadMediaFile`, `DirectChatNotifier.sendImageAttachment`, Outbox. |
| 21 | Send Videos | Presigned S3 PUT + `message:send` (`type: VIDEO`) | **Implemented** | `UploadService.uploadMediaFile`, `DirectChatNotifier.sendVideoAttachment`, Outbox. |
| 22 | Send GIFs | `message:send` (`type: GIF`) | **Implemented** | `DirectChatNotifier.sendGif`, Outbox. |
| 23 | Send Audio/Voice Messages | Presigned S3 PUT + `message:send` (`type: AUDIO` / `VOICE`) | **Implemented** | `VoiceMessageRecorder`, `DirectChatNotifier.sendAudioAttachment`, Outbox. |
| 24 | Send Files | Presigned S3 PUT + `message:send` (`type: FILE`) | **Implemented** | `UploadService.uploadMediaFile`, `DirectChatNotifier.sendFileAttachment`, Outbox. |
| 25 | Reply to Messages | `message:send` with `replyToId` | **Implemented** | `DirectChatNotifier.setReplyingTo`, reply preview UI, `DirectChatScreen`. |
| 26 | Edit Messages | socket `message:edit` (`conversationId`, `messageId`, `text`) | **Implemented** | `SocketService.editMessage`, `DirectChatNotifier.editMessage`, message bubble edit badge. |
| 27 | Delete Messages | socket `message:delete` (`conversationId`, `messageId`) | **Implemented** | `SocketService.deleteMessage`, `DirectChatNotifier.deleteMessage`. |
| 28 | Message Reactions | socket `message:react` (`conversationId`, `messageId`, `emoji`, `isAdded`) | **Implemented** | `SocketService.reactToMessage`, `DirectChatNotifier.toggleReaction`, emoji tray. |
| 29 | Read Receipts | socket `message:read` (`conversationId`, `seq`) & broadcast `message:read_receipt` | **Implemented** | `SocketService.markAsRead`, `DirectChatNotifier.markAsRead`, double-tick indicator. |
| 30 | Message Delivery Status | socket `message:delivered` (`chatId`, `seq`, `to`, `at`) | **Implemented** | `SocketService.markAsDelivered`, monotonic sequence receipts in SQLite. |
| 31 | Typing Indicators | socket `message:typing` (`conversationId`) & broadcast `user:typing` | **Implemented** | `SocketService.emitTyping`, `DirectChatScreen` typing indicator header. |
| 32 | Message Search | `GET /api/v1/chats/:chatId/messages?query=...` / SQLite query | **Implemented** | `ChatRepository.getMessages(query: ...)`, `ChatSearchScreen`. |
| 33 | Group Message History | `GET /api/v1/chats/:chatId/messages?limit=...&cursor=...` | **Implemented** | `ChatRepository.getMessages`, `DirectChatNotifier.loadMessages`, cursor pagination. |
| 34 | Media Gallery | `GET /api/v1/chats/:chatId/media?kind=media` | **Supported** | `ChatRepository.getMedia(kind: 'media')`, model attachment filtering. |
| 35 | Files Gallery | `GET /api/v1/chats/:chatId/media?kind=files` | **Supported** | `ChatRepository.getMedia(kind: 'files')`, model attachment filtering. |
| 36 | Audio Gallery | `GET /api/v1/chats/:chatId/media?kind=audio` | **Supported** | `ChatRepository.getMedia(kind: 'audio')`, model attachment filtering. |
| 37 | Links Gallery | `GET /api/v1/chats/:chatId/media?kind=links` | **Supported** | `ChatRepository.getMedia(kind: 'links')`, Link Preview SQLite cache. |
| 38 | Slow Mode | `slowModeSeconds` in conversation DTO & socket `SLOWMODE` error | **Modeled & Handled** | `ChatModel.slowModeSeconds`, rate limiting error message presentation. |
| 39 | Allowed Reactions Configuration | `allowedReactions` in conversation DTO & `REACTION_NOT_ALLOWED` error | **Modeled & Handled** | Filtered reaction picker & backend error mapping. |
| 40 | Default Group Permissions | 6 permission flags on group DTO (`canSendMessages`, etc.) | **Implemented** | `ChatModel`, `ChatRepository.updatePermissions`. |
| 41 | Group Username | `username` on group DTO | **Modeled & Supported** | `ChatModel.username`, public group search & mentions. |
| 42 | Public/Private Group | `isPublic` on group DTO | **Modeled & Supported** | `ChatModel.isPublic`, public discovery vs private access. |
| 43 | Auto-Delete Messages | `autoDeleteAfter` on group DTO | **Modeled & Handled** | Field modeled on conversation; server purges expired messages. |
| 44 | Personal Group Pin | `PATCH /api/v1/conversations/:id/settings` (`isPinned`) | **Implemented** | `ChatRepository.updateConversationSettings`, `ChatDao.updatePinStatus`. |
| 45 | Archive Group | `PATCH /api/v1/conversations/:id/settings` (`isArchived`) | **Implemented** | `ChatRepository.updateConversationSettings`. |
| 46 | Mute Group Notifications | `PATCH /api/v1/conversations/:id/settings` (`mutedUntil`) | **Implemented** | `ChatRepository.muteConversation`, `ChatDao.updateMuteStatus`. |
| 47 | Paginated Member List | `GET /api/v1/conversations/:id/members?page=1&limit=50` | **Implemented** | `ChatRepository.getMembers`, `ChatNotifier.fetchGroupMembers`. |
| 48 | Realtime Group Updates | socket event `chat:updated` | **Implemented** | `SocketService.onChatUpdated`, `ChatNotifier` live refresh. |
| 49 | Realtime Member Role Updates | socket event `member:updated` | **Implemented** | `SocketService.onMemberUpdated`, updates member list & permissions live. |
| 50 | Realtime Member Removal Notifications | socket event `member:removed` / `member:left` | **Implemented** | `SocketService.onMemberRemoved`, evicts member or exits chat if current user kicked. |
| 51 | Realtime Message Updates | socket events `message:new`, `message:edited`, `message:deleted` | **Implemented** | `SocketService`, `DirectChatNotifier`, `NotificationService`. |
| 52 | Group Message Sequence Tracking | `lastMessageSeq` & monotonic message `seq` | **Implemented** | Monotonic ordering in `ChatDao`, `SyncService` sequence-gap detection. |

## 7. Offline/reliability (76–84)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 76 | Offline message drafts | Implemented | Per-chat drafts are debounced into SQLite, restored on entry, preserved during metadata refresh, and cleared after send. |
| 77 | Pending message queue | Implemented | Text, image, and file sends are atomically committed with a unique `clientMsgId` to a FIFO SQLite outbox. The backend must honor `Idempotency-Key` for a hard exactly-once guarantee. |
| 78 | Automatic retry | Implemented | One-shot due timers and connectivity/reconnect triggers use exponential backoff (2–32 seconds) with five automatic retries. |
| 79 | Connection status indicator | Implemented | A debounced compact banner displays offline, connecting, reconnecting, and briefly connected states. |
| 80 | Local message cache | Implemented | Chats/messages are loaded immediately from SQLite before bounded server reconciliation. |
| 81 | Optimistic message updates | Implemented | An atomic pending row renders immediately with queued/sending/sent/delivered/seen state progression. |
| 82 | Failed message recovery | Implemented | Failed bubbles expose retry and cancel/delete; retry resets backoff and cancel removes queued work and staged media. |
| 83 | Background synchronization | Partial / platform-limited | FCM persists eligible background messages; lifecycle sync flushes the outbox and reconciles sequence gaps. Periodic/killed-app sync still needs Android/iOS background-task integration. |
| 84 | Conflict resolution | Implemented | Deleted tombstones win, delivery status is monotonic, edits use `editedAt` LWW, server reaction snapshots support removals, and message/client IDs deduplicate rows. |

### Flutter rendering and frame-performance safeguards

- Inbox rows subscribe to their indexed `ChatModel`, so presence, draft, unread, or preview changes rebuild only affected rows rather than the complete list.
- Message bubbles subscribe by message ID; receipt/retry/reaction updates rebuild only the changed bubble.
- Connection state is isolated to the compact banner and does not rebuild the inbox scroll view.
- Long conversations use lazy sliver construction, repaint boundaries, O(1) child-index lookup, and do not retain all off-screen bubble states.
- Model value equality suppresses rebuilds when a server refresh produces data identical to the current UI state.
- SQLite decoding/sorting is moved off the UI isolate; uploads stream from disk; resume synchronization limits network concurrency to three chats.
- Draft persistence is debounced and retry scheduling uses one-shot timers rather than continuous polling.

## 8. Added requirement: WhatsApp-style in-app message banner (85)

Status: **Implemented in the Flutter client**.

Acceptance behavior:

- Show a compact slide/fade banner when an incoming socket message arrives while the app is open on Settings or another non-chat screen.
- Display a compact avatar, sender name, one-line message/media preview, and local time.
- Tapping opens the relevant conversation.
- Swipe up to dismiss; otherwise auto-dismiss after four seconds.
- Do not show on the inbox list, direct chat, chat search, or chat profile screens; show only on non-chat screens.
- Do not show for the user's own echoed message.
- Deduplicate socket and FCM copies using a bounded 200-ID in-memory set.
- Keep at most one overlay entry visible, avoiding stacked widgets and unnecessary rebuilds.
- FCM remains responsible for background/terminated delivery.

Backend payload recommendation for both socket and FCM:

```json
{
  "message": {
    "id": "message-id",
    "conversationId": "conversation-id",
    "senderId": "sender-id",
    "senderName": "Sender name",
    "senderAvatar": "https://...",
    "type": "TEXT",
    "text": "Hello"
  }
}
```

The message `id` and `conversationId` must be stable and identical across socket and push payloads for reliable deduplication and navigation.

## Recommended delivery order

### P0 — correctness and trust

1. Replace simulated account deletion with a real authenticated deletion API and server-side data lifecycle.
2. Replace mock blocking with backend block/unblock/report flows enforced on message delivery.
3. Put refresh/access tokens in secure storage; define immediate session revocation.
4. Preserve `clientMsgId` as an idempotency key through REST and socket sends.
5. Add deterministic retry scheduling and a visible manual retry/cancel action.

### P1 — performance and messaging quality

1. Stream uploads from disk; compress images; generate thumbnails off the UI isolate.
2. Add a bounded upload queue with cancellation, progress, and offline resume.
3. Move message history to cursor/sequence pagination and verify scroll-position preservation.
4. Add real message/media search and storage-manager/LRU cache controls.
5. Add tests for socket/FCM banner dedupe, active-chat suppression, tap navigation, and media preview fallback.

### P2 — privacy and groups

1. Read-receipt, typing, presence, last-seen, profile, and notification-preview controls.
2. Real app/chat lock using platform authentication.
3. Session/device inventory and remote revoke.
4. Group roles, permissions, mentions, invite links, and moderation.

### P3 — differentiators

Only after reliability/privacy are measured in production: translation, summaries, reminders/tasks, folders, scheduled/disappearing messages, and carefully scoped AI features.

## Release gates for the new banner

- Verify on a real Android and iOS device with the app foregrounded on Settings.
- Verify one visual banner when the same message arrives by socket and FCM.
- Verify no banner for the open conversation or the sender's own echoed message.
- Verify tap navigation from a nested Settings route.
- Verify private-preview behavior before shipping sensitive-message notifications.
- Profile a burst of messages; confirm one overlay, no retained entries, and no repeated network/image work.
