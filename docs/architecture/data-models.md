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

## Event

**Purpose**: Represents a calendar event or social gathering created from conversations (AI-powered feature).

**Key Attributes**:
- `eventId`: string - Unique identifier for the event.
- `title`: string - Event name/description (e.g., "Dinner Friday 7pm").
- `date`: timestamp - Event date.
- `time`: string (optional) - Event time in "HH:mm" format.
- `location`: string (optional) - Event location.
- `creatorUserId`: string - userId of the user who created the event.
- `createdAt`: timestamp - When the event was created.
- `createdInConversationId`: string - Conversation where the event was first created.
- `createdAtMessageId`: string - Message that triggered event creation.
- `invitations`: map<string, Invitation> - Map of conversationId to Invitation object for multi-chat tracking.
- `attendees`: map<string, Attendee> - Map of userId to Attendee object with RSVP status.

**Supporting Types**:
- `Invitation`: { messageId: string, invitedUserIds: string[] }
- `Attendee`: { status: RSVPStatus, rsvpMessageId?: string, rsvpConversationId?: string, rsvpAt?: timestamp }
- `RSVPStatus`: enum ("pending", "accepted", "declined")

**TypeScript Interface**

```typescript
interface Event {
  eventId: string;
  title: string;
  date: FirebaseFirestore.Timestamp;
  time?: string;
  location?: string;
  creatorUserId: string;
  createdAt: FirebaseFirestore.Timestamp;
  createdInConversationId: string;
  createdAtMessageId: string;
  invitations: { [conversationId: string]: Invitation };
  attendees: { [userId: string]: Attendee };
}

interface Invitation {
  messageId: string;
  invitedUserIds: string[];
}

interface Attendee {
  status: 'pending' | 'accepted' | 'declined';
  rsvpMessageId?: string;
  rsvpConversationId?: string;
  rsvpAt?: FirebaseFirestore.Timestamp;
}
```

**Relationships**: Created from Conversation and Message. Links to multiple users via attendees map.

## Reminder

**Purpose**: Represents a personal task or reminder with deadline (AI-powered feature).

**Key Attributes**:
- `reminderId`: string - Unique identifier for the reminder.
- `userId`: string - User who owns this reminder.
- `title`: string - Reminder text (e.g., "Send docs by tomorrow").
- `dueDate`: timestamp - When the reminder is due.
- `conversationId`: string - Conversation where reminder was created.
- `sourceMessageId`: string - Message that triggered reminder creation.
- `completed`: boolean - Completion status.
- `createdAt`: timestamp - When reminder was created.
- `notificationId`: string (optional) - System notification ID for local notifications.

**TypeScript Interface**

```typescript
interface Reminder {
  reminderId: string;
  userId: string;
  title: string;
  dueDate: FirebaseFirestore.Timestamp;
  conversationId: string;
  sourceMessageId: string;
  completed: boolean;
  createdAt: FirebaseFirestore.Timestamp;
  notificationId?: string;
}
```

**Relationships**: Belongs to a User. Created from Conversation and Message.

## Decision

**Purpose**: Represents a group decision or agreement made in conversations (AI-powered feature).

**Key Attributes**:
- `decisionId`: string - Unique identifier for the decision.
- `userId`: string - User who saved this decision.
- `text`: string - Decision text (e.g., "Going to Italian restaurant").
- `conversationId`: string - Conversation where decision was made.
- `sourceMessageId`: string - Message that contains the decision.
- `timestamp`: timestamp - When decision was recorded.

**TypeScript Interface**

```typescript
interface Decision {
  decisionId: string;
  userId: string;
  text: string;
  conversationId: string;
  sourceMessageId: string;
  timestamp: FirebaseFirestore.Timestamp;
}
```

**Relationships**: Belongs to a User. Created from Conversation and Message.
