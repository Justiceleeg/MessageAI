# Core Workflows

This section illustrates key system workflows using sequence diagrams.

## Workflow 1: User Sends a 1:1 Message (Online)

```mermaid
sequenceDiagram
    participant User
    participant App as iOS App (SwiftUI)
    participant SDK as Firebase SDK
    participant Firestore
    participant Func as Cloud Functions
    participant FCM
    participant RecipientApp as Recipient's iOS App

    User->>App: Types message & taps Send
    App->>App: Display message optimistically (status: sending) (NFR2)
    App->>SDK: Save message to Firestore
    SDK->>Firestore: Write message document (conversation/messages)
    Firestore-->>SDK: Acknowledge write
    SDK-->>App: Confirm write success
    App->>App: Update message status (status: sent)
    Firestore-->>SDK: Real-time update triggered
    SDK-->>App: (No action needed, already displayed optimistically)

    Firestore-->>Func: Firestore Trigger (newMessage)
    Func->>FCM: Trigger push notification for recipient (FR8)
    FCM-->>RecipientApp: Deliver push notification

    Firestore-->>RecipientApp: Real-time update (via SDK listener)
    RecipientApp->>RecipientApp: Display new message (FR2)
```

## Workflow 2: User Receives a Message (App in Foreground)

```mermaid
sequenceDiagram
    participant SenderApp
    participant Firestore
    participant Func as Cloud Functions
    participant FCM
    participant App as Recipient's iOS App (SwiftUI)
    participant SDK as Firebase SDK (Recipient)
    participant User as Recipient User

    SenderApp->>Firestore: Writes new message
    Firestore-->>SDK: Real-time update triggered
    SDK-->>App: Receive new message data
    App->>App: Display new message in Chat View (FR2)
    App->>App: Update Conversation List View preview
    App->>SDK: Mark message as delivered in Firestore
    SDK->>Firestore: Update message status to 'delivered'

    Firestore-->>Func: Firestore Trigger (newMessage)
    Func->>FCM: Trigger push notification (FR8)
    FCM-->>App: Deliver push notification
    App->>App: Handle notification (e.g., update badge, optional in-app banner)

    User->>App: Views message in Chat View
    App->>SDK: Mark message as read in Firestore (FR6)
    SDK->>Firestore: Update message status to 'read'
```

## Workflow 3: App Launch & Loading Messages (Offline First)

```mermaid
sequenceDiagram
    participant User
    participant App as iOS App (SwiftUI)
    participant SwiftData as Local Cache
    participant SDK as Firebase SDK
    participant Firestore

    User->>App: Launches App
    App->>SwiftData: Load conversations & messages immediately (NFR1)
    SwiftData-->>App: Return cached data
    App->>App: Display cached conversations & messages
    App->>SDK: Initiate Firestore listeners for real-time updates
    SDK->>Firestore: Establish connection & listeners
    Firestore-->>SDK: Send any new data since last sync
    SDK-->>App: Receive updates
    App->>App: Update UI with new data
    App->>SwiftData: Store newly synced data
```
