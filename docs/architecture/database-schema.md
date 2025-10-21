# Database Schema

This section outlines the schema for both the remote database (Firestore) and the local persistence layer (SwiftData).

## Firestore Schema (Remote)

Firestore's NoSQL structure will be organized as follows:

**users Collection**:
- **Document ID**: userId
- **Fields**: displayName, email?, presence, lastSeen
- **Indexes**: Default single-field.

**conversations Collection**:
- **Document ID**: Auto-generated.
- **Fields**: participants (array), lastMessageText?, lastMessageTimestamp?, isGroupChat
- **Indexes**: participants (array-contains), lastMessageTimestamp (ordering).
- **Sub-collection**: messages

**messages Sub-collection (within conversations)**:
- **Document ID**: Auto-generated.
- **Fields**: senderId, text, timestamp, status
- **Indexes**: timestamp (ordering).

**Firestore Security Rules**: Critical. Must ensure users can only access their own data and conversations they participate in.

## SwiftData Schema (Local Cache - iOS App)

SwiftData models will mirror the Firestore structure.

```swift
import SwiftData
import FirebaseFirestore // For Timestamp type if needed, or use Date

@Model
final class UserEntity {
    @Attribute(.unique) var userId: String
    var displayName: String
    var email: String?
    var presence: String // "online" or "offline"
    var lastSeen: Date

    init(userId: String, displayName: String, email: String? = nil, presence: String = "offline", lastSeen: Date = Date()) { /*...*/ }
}

@Model
final class ConversationEntity {
    @Attribute(.unique) var conversationId: String
    var participants: [String]
    var lastMessageText: String?
    var lastMessageTimestamp: Date?
    var isGroupChat: Bool

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    var messages: [MessageEntity]? = []

    init(conversationId: String, participants: [String], lastMessageText: String? = nil, lastMessageTimestamp: Date? = nil, isGroupChat: Bool = false) { /*...*/ }
}

@Model
final class MessageEntity {
    @Attribute(.unique) var messageId: String
    var senderId: String
    var text: String
    var timestamp: Date
    var status: String // "sending", "sent", "delivered", "read"
    var conversation: ConversationEntity?

    init(messageId: String, senderId: String, text: String, timestamp: Date, status: String = "sending", conversation: ConversationEntity? = nil) { /*...*/ }
}
```
