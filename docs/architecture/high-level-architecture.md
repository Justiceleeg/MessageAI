# High Level Architecture

## Technical Summary

The MessageAI architecture follows a mobile-first, serverless approach. The frontend is a native iOS application built with SwiftUI, leveraging SwiftData for local persistence and offline capabilities. The backend relies entirely on Firebase services, including Firestore for real-time data synchronization and persistence, Firebase Auth for user management, Firebase Cloud Functions for serverless logic (like push notifications), and Firebase Cloud Messaging (FCM) for push delivery. Key architectural patterns include Offline-First design, Optimistic UI updates, and Real-time Synchronization to achieve the reliability and responsiveness goals outlined in the PRD.

## Platform and Infrastructure Choice

**Platform**: Firebase.

**Rationale**: Firebase directly provides the core real-time database, authentication, serverless functions, and push notification capabilities required by the PRD. Its tight integration with iOS and built-in handling of real-time sync and offline persistence significantly accelerates development towards the MVP goals.

**Key Services**:
- Firebase Authentication
- Firebase Firestore
- Firebase Cloud Functions
- Firebase Cloud Messaging (FCM)

**Deployment Host and Regions**: Firebase Hosting (if any web component needed later, otherwise N/A for pure backend services), Functions typically run multi-region or can be pinned (e.g., us-central1).

## Repository Structure

**Structure**: Monorepo.

**Rationale**: As specified in the PRD's technical assumptions, a monorepo structure will co-locate the iOS application code and the Firebase Cloud Functions code. This simplifies management, particularly if shared logic or types emerge later (though less common between Swift and Node.js/TypeScript for Functions).

**Monorepo Tool**: N/A (Standard folder structure within a single Git repository).

**Package Organization**: A root directory containing separate folders for the ios-app (Xcode project) and firebase-functions (Node.js/TypeScript project).

## High Level Architecture Diagram

```mermaid
graph TD
    subgraph "iOS Device"
        App[📱 MessageAI iOS App (SwiftUI)]
        LocalDB[(📁 SwiftData - Local Cache)]
    end

    subgraph "Firebase Cloud"
        Auth[🔒 Firebase Auth]
        Firestore[📄 Firestore (Real-time DB)]
        Functions[⚡ Cloud Functions (Node.js/TS)]
        FCM[📬 FCM (Push Notifications)]
    end

    App -- Authentication --> Auth
    App -- Real-time Sync --> Firestore
    App -- Read/Write --> LocalDB
    App -- Sends Message --> Functions
    Functions -- Writes to --> Firestore
    Functions -- Triggers --> FCM
    Firestore -- Real-time Updates --> App
    FCM -- Sends Push --> App

    style App fill:#cce5ff
    style LocalDB fill:#e5ccff
```

## Architectural Patterns

- **Serverless Architecture**: Using Firebase Cloud Functions for backend logic. **Rationale**: Aligns with PRD requirement for rapid deployment and automatic scaling.
- **Offline-First**: Leveraging SwiftData for local message caching and offline access. **Rationale**: Meets NFR1 for persistence and app availability during network outages.
- **Real-time Synchronization**: Utilizing Firestore's real-time listeners for instant message updates. **Rationale**: Meets FR2 for real-time delivery.
- **Optimistic UI Updates**: Updating the UI immediately upon user action (e.g., sending a message) before server confirmation. **Rationale**: Meets NFR2 for perceived app responsiveness.
- **Model-View-ViewModel (MVVM)**: Standard pattern for SwiftUI development. **Rationale**: Promotes separation of concerns, testability, and state management within the iOS app.
- **Repository Pattern (for Local Data)**: Abstracting SwiftData access logic. **Rationale**: Enables cleaner data management and easier testing of local persistence logic within the iOS app.
