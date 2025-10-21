# Epic 3: Group Chat & Presence Features

**Epic Goal**: Expand functionality to include basic group chat (FR3), message read receipts (FR6), online/offline status indicators (FR7), and foreground push notifications (FR8).

## Story 3.1: Implement Basic Group Chat

**As a** user, **I want to** participate in group chats with 3 or more users, **so that** I can communicate with multiple people simultaneously.

**Acceptance Criteria**
- Users can create or be added to conversations involving 3 or more participants (FR3).
- The Conversation List View correctly displays group chats (e.g., showing group name or participant list).
- The Chat View functions correctly for group conversations, displaying messages from all participants.
- Messages sent in a group chat are delivered in real-time to all online participants in that group.
- Offline persistence and optimistic UI (from Epic 2) function correctly for group chat messages.

## Story 3.2: Display Message Read Receipts

**As a** user, **I want to** see if my messages have been read by recipients, **so that** I know if my communication was received.

**Acceptance Criteria**
- Each message sent by the user displays an indicator showing its current status (e.g., "sent," "delivered," "read") (FR6).
- The status updates in real-time as recipients receive and read the messages.
- In group chats, the "read" status indicates when all recipients have read the message (MVP scope).
- The system correctly updates message status in Firestore when a message is delivered or read.

## Story 3.3: Implement User Presence Indicators

**As a** user, **I want to** see if other users are online or offline, **so that** I know when someone is available to chat.

**Acceptance Criteria**
- The app displays an indicator showing whether other users are currently online or offline (FR7).
- The presence status updates in (near) real-time when users go online or offline.
- In 1:1 chats, the ChatView displays "Online" or "Last seen X ago" subtitle based on the other user's status.
- In group chats, the ChatView displays a green dot to the right of each sender's name if they are currently online.
- The app automatically sets the user's status to online when active and offline when backgrounded/disconnected.
- Presence uses Firebase Realtime Database with automatic disconnect detection for reliability.

## Story 3.4: Implement Push Notifications

**As a** user, **I want to** receive push notifications for new messages when I'm not viewing a conversation, **so that** I don't miss important communications.

**Acceptance Criteria**
- When a new message is received for a conversation the user is not currently viewing, a push notification is delivered to the device (FR8).
- Notifications work reliably when the app is in the foreground (MVP scope).
- Tapping a notification navigates the user to the relevant conversation.
- A Firebase Cloud Function is implemented and deployed to trigger FCM notifications based on new messages in Firestore.
- FCM device tokens are properly registered, refreshed, and synced to Firestore.