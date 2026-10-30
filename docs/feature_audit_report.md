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
| 13 | Hide online status | Partial | A persistent Show Active Status toggle now controls heartbeats and emits `presence:visibility`; backend enforcement still requires integration verification. |
| 14 | Hide last seen | Partial | Last-active data is displayed; no visibility control. |
| 15 | Read receipt control | Partial | Read receipts work; users cannot disable them. |
| 16 | Typing indicator control | Partial | Typing indicators work; users cannot disable broadcasting. |
| 17 | Screenshot notifications | Not found | Correctly treat this as platform-limited even if later added. |
| 18 | Chat lock | Not found | No per-chat authentication gate. |
| 19 | Hidden chats | Not found | No protected archive or hidden-chat storage. |
| 20 | App lock | Partial | Biometric switch is UI-only and defaults to true; it does not lock the app. |
| 21 | Private notification preview | Not found | No user setting to hide sender/body. |
| 22 | Block user | Partial | Profile action and block-list UI exist, but the list is hard-coded and no backend block call was found. |
| 23 | Report user | Not found | No report reason/evidence/API flow. |
| 24 | Active session management | Not found | No device/session list or revocation UI/API. |
| 25 | Login alerts | Not found | No client flow; push/email backend behavior is unverified. |
| 26 | Message auto-delete | Not found | Same missing foundation as disappearing messages. |
| 27 | Profile visibility control | Not found | Profile editing exists; audience rules do not. |

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

## 6. Group chat (65–75)

| # | Feature | Status | Evidence / gap |
|---:|---|---|---|
| 65 | Group admin roles | Not found | Basic group creation/member changes exist, not role management. |
| 66 | Group join requests | Not found | |
| 67 | Invite links | Not found | |
| 68 | Mention notifications | Not found | |
| 69 | Group polls | Not found | Poll enum alone is insufficient. |
| 70 | Group announcements | Not found | |
| 71 | Slow mode | Not found | |
| 72 | Member permissions | Partial | Add/remove member calls exist; granular permissions do not. |
| 73 | Group message search | Not found | |
| 74 | Group event planner | Not found | A separate Events screen is not a chat-integrated group planner. |
| 75 | Temporary group membership | Not found | |

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
