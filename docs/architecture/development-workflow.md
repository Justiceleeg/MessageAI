# Development Workflow

Setup and commands for local development.

## Local Development Setup

### Prerequisites

- Xcode (Latest)
- Node.js (18.x LTS)
- Firebase CLI (npm install -g firebase-tools)
- Firebase Account
- (Optional) Java JDK (for Firestore emulator)

### Initial Setup

```bash
git clone <repo> MessageAI; cd MessageAI # Clone
firebase login; firebase use --add          # Configure Firebase
cd firebase-functions; npm install; cd ..   # Install Func deps
open ios-app/MessageAI.xcodeproj            # Open Xcode (ensure Firebase SDK via SPM)
```

## Development Commands

```bash
# iOS App: Use Run (▶) in Xcode

# Firebase Backend (from firebase-functions dir):
firebase setup:emulators:firestore functions auth # Install emulators (once)
firebase emulators:start                         # Run emulators locally
firebase deploy --only functions                 # Deploy functions
firebase deploy --only firestore:rules           # Deploy rules
```

## Environment Configuration

- **iOS App**: Uses GoogleService-Info.plist file from Firebase console.
- **Firebase Functions**: Use `firebase functions:config:set key="value"` for backend secrets (e.g., Post-MVP AI keys). Access via `functions.config()`.
