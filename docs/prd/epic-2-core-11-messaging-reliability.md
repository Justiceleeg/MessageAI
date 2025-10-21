# Epic 2: Core 1:1 Messaging & Reliability

**Epic Goal**: Implement the primary 1:1 chat functionality (FR1), real-time message delivery (FR2), message timestamps (FR5), local persistence (NFR1), and optimistic UI updates (NFR2).

## Story 2.1: View Conversation List

**As a** user, **I want to** see a list of all my existing conversations, **so that** I can select one to continue chatting.

**Acceptance Criteria**
- The main app screen (after login) displays a list of the user's 1:1 conversations.
- Each item in the list shows the other user's display name and a preview of the most recent message.
- The list is updated in real-time if a new message is received in any conversation.
- Tapping a conversation navigates the user to the Chat View for that specific chat.
- If the user has no conversations, a "No conversations yet" message is displayed.

## Story 2.2: Send & Receive Real-time 1:1 Messages

**As a** user, **I want to** send and receive messages in a 1:1 chat, **so that** I can communicate with another user.

**Acceptance Criteria**
- When a user opens a Chat View, they see the message history for that conversation (FR1).
- Messages sent by the current user are displayed on one side (e.g., right), and messages from the other user are on the other (e.g., left).
- A user can type text into an input field and tap "Send".
- The sent message is immediately saved to the Firestore messages sub-collection for that conversation.
- Any new message received in this conversation appears at the bottom of the chat history in real-time (FR2).
- Every message displayed in the chat history includes a human-readable timestamp (e.g., "10:30 AM") (FR5).

## Story 2.3: Ensure Offline Persistence & Optimistic UI

**As a** user, **I want** my messages to appear instantly and be available when I'm offline, **so that** the app feels fast and I am never without my data.

**Acceptance Criteria**
- When a user taps "Send", the message immediately appears in their Chat View with a "sending..." indicator (NFR2).
- Once the message is confirmed by Firestore, the indicator disappears (or changes to "sent").
- All received and sent messages are saved to the local SwiftData database (NFR1).
- If the user restarts the app, all previously synced messages are loaded instantly from SwiftData before any network request is made (NFR1).
- If a user sends a message while offline, it appears in their UI optimistically and is added to a queue.
- When the user's device reconnects, all queued messages are automatically sent.
