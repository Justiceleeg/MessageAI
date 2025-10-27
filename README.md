# MessageAI

A production-quality iOS messaging app with real-time delivery, offline support, and intelligent notifications. Built with Swift, SwiftUI, and Firebase.

## Description

MessageAI is a modern messaging application inspired by WhatsApp's robust infrastructure. It provides fast, reliable real-time communication with a focus on user experience and technical excellence. The app features an offline-first architecture with optimistic UI updates, making it feel instantaneous even on poor network connections.

## About This App

MessageAI is an **AI-powered messaging platform** that goes beyond traditional chat apps by intelligently understanding your conversations. Built as a technical showcase project, it demonstrates production-grade iOS development, real-time synchronization, and cutting-edge AI integration.

### 🧠 **AI-Powered Intelligence**

The app uses **GPT-4** and **vector embeddings** to automatically extract actionable insights from your conversations:

- **📅 Event Detection & Scheduling** - Automatically detects when you're planning events ("Let's meet Tuesday at 3pm") and creates calendar entries with conflict detection
- **⏰ Smart Reminders** - Extracts reminders from natural language ("Remind me to call John tomorrow") and schedules local notifications
- **✅ Decision Tracking** - Captures important decisions made in conversations for easy reference later
- **🎯 Priority Detection** - Identifies urgent/important messages and highlights them appropriately
- **🔗 Multi-Chat Event Linking** - Links the same event across multiple conversations (great for coordinating group activities)
- **📍 RSVP Tracking** - Detects responses to event invitations and updates attendance status

### 🏗️ **Architecture Highlights**

**Frontend (iOS)**
- **Swift 5.9+** with **SwiftUI** for modern, declarative UI
- **SwiftData** for offline-first local persistence
- **MVVM architecture** for clean separation of concerns
- **Combine framework** for reactive data flow
- **Real-time listeners** via Firebase Firestore

**Backend (Python)**
- **FastAPI** server for AI processing
- **OpenAI GPT-4** for natural language understanding
- **LangChain** for prompt engineering and AI workflows
- **Pinecone** vector database for semantic search and conflict detection
- **Firebase Firestore** for scalable real-time data sync

### 💾 **Offline-First Design**

MessageAI works seamlessly even without internet:

- **Complete offline access** to messages, events, reminders, and decisions
- **SwiftData caching** with automatic background sync when online
- **Optimistic UI updates** for instant feedback
- **Offline message queue** with automatic retry when reconnected
- **Network-aware operations** that fallback gracefully to cached data

### 🎨 **User Experience Features**

- **Intelligent notifications** with smart suppression (no spam!)
- **Message highlighting** - jump directly to events/reminders from calendar
- **Read receipts** with delivery status tracking
- **Presence indicators** - see who's online in real-time
- **Theme support** - Light, Dark, or System default
- **Group chat support** with multi-participant coordination
- **Search & filter** for messages, events, and decisions

### 🧪 **Technical Excellence**

- **95+ unit tests** covering core functionality
- **Integration tests** for Firebase services
- **XCTest** and **XCUITest** for comprehensive coverage
- **Modular architecture** with clear service boundaries
- **Error handling** with graceful degradation
- **Logging & observability** via OSLog
- **Type-safe** Swift with minimal force unwrapping

### 🚀 **What Makes This Special**

1. **Production-Ready Code** - Not a tutorial project, but real production-quality architecture
2. **AI Integration Done Right** - Backend processing keeps the iOS app fast and battery-efficient
3. **Conflict Detection** - Vector similarity search prevents duplicate events
4. **Multi-Modal AI** - Combines rule-based logic with LLM intelligence
5. **Fully Offline Capable** - Works great even with spotty connections

This app demonstrates the future of messaging: conversations that don't just store messages, but understand them and take action on your behalf.

## Tech Stack

- **Frontend**: Swift 5.9+, SwiftUI
- **Backend**: Firebase (Firestore, Auth, Storage) + Python FastAPI
- **AI/ML**: OpenAI GPT-4, LangChain, Pinecone Vector DB
- **Local Persistence**: SwiftData (iOS 17+)
- **Testing**: XCTest, XCUITest
- **Build Tool**: Xcode (Latest)

## Features

### Core Messaging
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

### AI-Powered Features
- **🤖 Automatic Event Extraction**: Detects events in natural language and creates calendar entries
- **🔍 Smart Conflict Detection**: AI-powered vector search prevents double-booking
- **🗓️ Multi-Chat Event Linking**: Same event across multiple conversations automatically links
- **⏰ Intelligent Reminders**: Extracts and schedules reminders with local notifications
- **✅ Decision Tracking**: Captures important decisions for easy reference
- **📊 Priority Analysis**: Automatically identifies urgent/important messages
- **📍 RSVP Detection**: Tracks attendance responses across conversations
- **💬 Context-Aware AI**: GPT-4 understands conversation context and user intent
- **🔗 Semantic Search**: Find related events/decisions using meaning, not just keywords
- **📅 Calendar Integration**: Jump from calendar events directly to the original chat message

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

### 2. Configure Backend URL (IMPORTANT!)

The app is configured to use **localhost** for development by default. If you want to use the **production backend**, you need to change the configuration:

**Option A: Quick Change (For Testing Production Backend)**

Open `ios-app/MessageAI/Utilities/Config.swift` and modify line 18:

```swift
// Change from:
return "http://127.0.0.1:8000"  // Local development

// To:
return "https://messageai-backend-egkh.onrender.com"  // Production
```

**Option B: Proper Setup with Build Configurations (Recommended)**

1. Open the Xcode project: `cd ios-app && open MessageAI.xcodeproj`
2. In Project Navigator, verify these files exist:
   - `Config.xcconfig`
   - `Debug.xcconfig` (uses localhost)
   - `Release.xcconfig` (uses production)
3. Click on the **MessageAI project** (blue icon at top)
4. Go to **Info** tab
5. Under **Configurations**, set:
   - **Debug** → `Debug.xcconfig`
   - **Release** → `Release.xcconfig`
6. Open `Info.plist` and add:
   - Key: `AI_BACKEND_URL`
   - Type: `String`
   - Value: `$(AI_BACKEND_URL)`

Now Debug builds automatically use localhost, Release builds use production! 🎉

### 3. Open the Project

```bash
cd ios-app
open MessageAI.xcodeproj
```

### 4. Install Dependencies

Xcode will automatically resolve Swift Package Manager dependencies when you open the project. If not, go to:
- **File → Packages → Resolve Package Versions**

Wait for the packages to download (first time may take a few minutes).

### 5. Build and Run

1. Select a simulator or connected device from the scheme selector (e.g., iPhone 16)
2. Press `Cmd + R` or click the Play button
3. Wait for build to complete (first build may take a few minutes)
4. The app will launch in the simulator or on your device

**Check the console** for configuration info:
```
🔧 MessageAI Configuration
   Environment: Development
   Backend URL: https://messageai-backend-egkh.onrender.com
   Debug Mode: true
```

**That's it!** The Firebase backend is already configured and ready to use.

---

## Local Development (Running Python Backend Locally)

If you want to develop AI features locally instead of using the production backend:

### 1. Set Up Python Backend

```bash
cd python-backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create a `.env` file in `python-backend/`:

```bash
# Copy from example
cp .env.example .env

# Edit .env with your API keys:
OPENAI_API_KEY=your_openai_key_here
PINECONE_API_KEY=your_pinecone_key_here
PINECONE_ENVIRONMENT=your_pinecone_env
PINECONE_INDEX_NAME=messageai-vectors
```

### 3. Start Local Backend

```bash
# Make sure you're in python-backend directory
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

### 4. Verify Backend is Running

Open in browser: http://localhost:8000/docs

You should see the FastAPI interactive documentation.

### 5. Configure iOS App for Localhost

The iOS app is **already configured to use localhost by default** in Debug mode! Just:

1. Make sure backend is running (step 3 above)
2. Build and run the iOS app in Xcode
3. Check console for: `Backend URL: http://127.0.0.1:8000`

**That's it!** Messages you send will be analyzed by your local AI backend.

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
│   │   ├── Models/             # Data models & SwiftData entities
│   │   ├── Views/              # SwiftUI views (Chat, Calendar, etc.)
│   │   ├── ViewModels/         # View models (MVVM pattern)
│   │   ├── Services/           # Business logic & Firebase integration
│   │   ├── Persistence/        # SwiftData persistence controller
│   │   └── Utilities/          # Helper functions and extensions
│   └── MessageAITests/         # Unit and integration tests
├── python-backend/             # AI processing backend
│   ├── app/
│   │   ├── routes/            # FastAPI endpoints
│   │   ├── services/          # AI services (OpenAI, Pinecone)
│   │   └── models/            # Pydantic models
│   └── tests/                 # Backend tests
├── firebase/                   # Firebase configuration
│   ├── firestore.rules        # Security rules
│   └── firestore.indexes.json # Database indexes
└── docs/                       # Project documentation
    ├── architecture/          # Technical architecture docs
    ├── prd/                   # Product requirements
    └── stories/               # User stories
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

