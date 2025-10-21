# Requirements

## Functional

- **FR1**: The system must support one-on-one chat functionality.
- **FR2**: The system must deliver messages in real-time between two or more online users.
- **FR3**: The system must support basic group chat functionality for three or more users in one conversation.
- **FR4**: The system must provide user authentication, allowing users to create accounts and have profiles.
- **FR5**: The system must display timestamps for all messages.
- **FR6**: The system must provide message read receipts.
- **FR7**: The system must display online/offline status indicators for users.
- **FR8**: The system must deliver push notifications, at least while the app is in the foreground.

## Non Functional

- **NFR1**: Messages must persist locally and survive application restarts (Offline-First).
- **NFR2**: The UI must update optimistically, with sent messages appearing instantly in the UI before server confirmation.
- **NFR3**: The application must be runnable on a local emulator/simulator, connecting to a deployed backend (Firebase).
- **NFR4**: The system must be built using the "Golden Path" stack: Swift/SwiftUI, Firebase (Firestore, Functions, Auth, FCM), and SwiftData.
