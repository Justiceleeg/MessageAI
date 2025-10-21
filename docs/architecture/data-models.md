# Data Models

This section defines the core data entities required for the MVP, considering both their representation in Firestore (backend) and how they might be structured locally with SwiftData (frontend).

## User

**Purpose**: Represents a registered user of the application.

**Key Attributes**:
- `userId`: string - Unique identifier (matches Firebase Auth UID).
- `displayName`: string - User's chosen display name.
- `email`: string - User's email address (optional, mainly for lookup).
- `presence`: string (enum: "online", "offline") - User's current status (FR7).
- `lastSeen`: timestamp - Timestamp of the user's last activity.

**TypeScript Interface (for Cloud Functions/conceptual sharing)**

```typescript
interface User {
  userId: string;
  displayName: string;
  email?: string;
  presence: 'online' | 'offline';
  lastSeen: FirebaseFirestore.Timestamp; // Or appropriate timestamp type
}
```

**Relationships**: None directly stored, linked implicitly via userId.

## Conversation

**Purpose**: Represents a single chat thread, either 1:1 or group.

**Key Attributes**:
- `conversationId`: string - Unique identifier for the conversation.
- `participants`: array<string> - List of userIds participating in this chat (FR1, FR3).
- `lastMessageText`: string - Preview text of the most recent message.
- `lastMessageTimestamp`: timestamp - Timestamp of the most recent message.
- `isGroupChat`: boolean - Flag indicating if it's a group chat (derived from participants.length > 2).

**TypeScript Interface (for Cloud Functions/conceptual sharing)**

```typescript
interface Conversation {
  conversationId: string;
  participants: string[];
  lastMessageText?: string;
  lastMessageTimestamp?: FirebaseFirestore.Timestamp;
  isGroupChat: boolean;
}
```

**Relationships**: Contains an array of userIds. Will contain a sub-collection of Message documents in Firestore.

## Message

**Purpose**: Represents a single message within a conversation.

**Key Attributes**:
- `messageId`: string - Unique identifier for the message.
- `senderId`: string - userId of the sender.
- `text`: string - The content of the message.
- `timestamp`: timestamp - When the message was sent (FR5).
- `status`: string (enum: "sending", "sent", "delivered", "read") - Delivery/read status (NFR2, FR6).

**TypeScript Interface (for Cloud Functions/conceptual sharing)**

```typescript
interface Message {
  messageId: string;
  senderId: string;
  text: string;
  timestamp: FirebaseFirestore.Timestamp;
  status: 'sending' | 'sent' | 'delivered' | 'read';
}
```

**Relationships**: Belongs to a specific Conversation (will be stored in a sub-collection in Firestore). Linked to a User via senderId.
