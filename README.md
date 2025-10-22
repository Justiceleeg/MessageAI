# MessageAI

A production-quality iOS messaging app with real-time delivery, offline support, and intelligent notifications. Built with Swift, SwiftUI, and Firebase.

## Description

MessageAI is a modern messaging application inspired by WhatsApp's robust infrastructure. It provides fast, reliable real-time communication with a focus on user experience and technical excellence. The app features an offline-first architecture with optimistic UI updates, making it feel instantaneous even on poor network connections.

## Tech Stack

- **Frontend**: Swift 5.9+, SwiftUI
- **Backend**: Firebase (Firestore, Auth, Realtime Database, Storage)
- **Local Persistence**: SwiftData (iOS 17+)
- **Testing**: XCTest, XCUITest
- **Build Tool**: Xcode (Latest)

## Features

- **Real-time Messaging**: Instant message delivery with WebSocket-based synchronization
- **One-on-One & Group Chat**: Direct messaging and multi-participant conversations
- **Offline-First**: Access chat history and send messages without internet connection
- **User Authentication**: Secure sign-up and login with Firebase Auth
- **Read Receipts**: See when messages are delivered and read
- **Online/Offline Status**: Real-time presence indicators for contacts
- **User Presence**: Live activity status with last seen timestamps
- **Smart Notifications**: In-app banners and local notifications with intelligent suppression
- **Message Persistence**: All messages stored locally and synced to cloud
- **Optimistic UI**: Messages appear instantly before server confirmation
- **Theme Support**: System default, light, or dark mode options
- **Offline Message Queue**: Messages sent offline are queued and synced on reconnection
- **Network Monitoring**: Automatic detection and handling of connectivity changes
- **Profile Management**: User profiles with display names and settings

## Prerequisites

- **macOS**: Sonoma or later
- **Xcode**: 15.0 or later
- **iOS**: 17.0+ (Simulator or physical device)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Justiceleeg/MessageAI.git
cd MessageAI
```

### 2. Open the Project

```bash
cd ios-app
open MessageAI.xcodeproj
```

### 3. Install Dependencies

Xcode will automatically resolve Swift Package Manager dependencies when you open the project. If not, go to:
- **File → Packages → Resolve Package Versions**

Wait for the packages to download (first time may take a few minutes).

### 4. Build and Run

1. Select a simulator or connected device from the scheme selector (e.g., iPhone 16)
2. Press `Cmd + R` or click the Play button
3. Wait for build to complete (first build may take a few minutes)
4. The app will launch in the simulator or on your device

**That's it!** The Firebase backend is already configured and ready to use.

---

## Optional: Use Your Own Firebase Project

If you want to use your own Firebase backend instead of the included one:

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Add an iOS app to your Firebase project
4. Download the `GoogleService-Info.plist` file
5. Replace the existing file in `ios-app/MessageAI/` directory

### 2. Configure Firebase Services

In Firebase Console, enable these services:
- **Authentication** → Sign-in method → Email/Password
- **Firestore Database** → Create database (start in test mode)
- **Realtime Database** → Create database (start in test mode)
- **Storage** → Get started

### 3. Set Up Security Rules

Apply the following Firestore security rules:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection: All authenticated users can read
    // Users can only write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Conversations: Users can only read/write conversations they participate in
    match /conversations/{conversationId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.participants;
      
      allow create: if request.auth != null && 
                       request.auth.uid in request.resource.data.participants;
      
      allow update: if request.auth != null && 
                       request.auth.uid in resource.data.participants;
      
      // Messages subcollection
      match /messages/{messageId} {
        allow read: if request.auth != null && 
                       request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
        
        allow create: if request.auth != null && 
                         request.auth.uid == request.resource.data.senderId;
        
        allow update: if request.auth != null && (
          (request.auth.uid == resource.data.senderId) ||
          (request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants &&
           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'readBy']) &&
           request.resource.data.senderId == resource.data.senderId &&
           request.resource.data.text == resource.data.text &&
           request.resource.data.messageId == resource.data.messageId)
        );
      }
    }
  }
}
```

### 4. Rebuild and Run

Clean and rebuild the project to use your new Firebase configuration.

## Usage

1. **Sign Up**: Create a new account with email and password
2. **Start Chatting**: Search for users and start conversations
3. **Create Groups**: Add multiple participants to a group chat
4. **Send Messages**: Type and send messages in real-time
5. **Go Offline**: Test offline functionality by disabling network

## Project Structure

```
MessageAI/
├── ios-app/
│   ├── MessageAI/              # Main iOS app
│   │   ├── Models/             # Data models (User, Message, Conversation)
│   │   ├── Views/              # SwiftUI views
│   │   ├── ViewModels/         # View models (MVVM pattern)
│   │   ├── Services/           # Business logic and Firebase integration
│   │   ├── Persistence/        # SwiftData local storage
│   │   └── Utilities/          # Helper functions and extensions
│   └── MessageAITests/         # Unit and integration tests
└── docs/                       # Project documentation
```

## Testing

Run tests from Xcode:
- **Unit Tests**: `Cmd + U`
- **UI Tests**: Select test scheme and run

Or via command line:
```bash
xcodebuild test -scheme MessageAI -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Troubleshooting

**Build Errors:**
- Clean build folder: `Cmd + Shift + K`
- Delete derived data: `Cmd + Shift + Option + K`
- Ensure `GoogleService-Info.plist` is properly added to the project

**Firebase Connection Issues:**
- Verify `GoogleService-Info.plist` matches your Firebase project
- Check that Firebase services are enabled in console
- Ensure app bundle ID matches Firebase iOS app configuration

**Simulator Issues:**
- Background notifications are limited on simulator (use physical device for full testing)
- Reset simulator: Device → Erase All Content and Settings

## Contributing

This is a learning/portfolio project. Feel free to explore and fork!

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Inspired by WhatsApp's messaging infrastructure
- Built with Firebase and Apple's native iOS technologies
- Developed as a technical showcase project

