# Components

Based on the serverless architecture, native iOS client, and direct Firebase SDK integration, the major logical components and their responsibilities are:

## iOS Application (SwiftUI)

**Responsibility**: Provides the user interface, manages local application state, handles user input, interacts with local storage (SwiftData), and communicates directly with Firebase services (Auth, Firestore) via the Firebase SDK.

**Key Interfaces**: User Interface (Views), ViewModels (state and logic), Local Repository (SwiftData interaction), Firebase Service Layer (wrappers around Firebase SDK calls).

**Dependencies**: Firebase iOS SDK, SwiftData.

**Technology Stack**: Swift, SwiftUI, SwiftData.

## Firebase Authentication

**Responsibility**: Manages user sign-up, login, sessions, and provides user identity (UIDs).

**Key Interfaces**: Firebase Auth SDK methods (e.g., createUser, signIn, signOut, currentUser).

**Dependencies**: None (Managed Cloud Service).

**Technology Stack**: Firebase Cloud Service.

## Firebase Firestore

**Responsibility**: Stores and synchronizes application data (Users, Conversations, Messages) in real-time across connected clients. Enforces data access rules via Security Rules.

**Key Interfaces**: Firestore SDK methods (e.g., setData, updateData, addSnapshotListener, getDocuments). Firestore Security Rules.

**Dependencies**: None (Managed Cloud Service).

**Technology Stack**: Firebase Cloud Service (NoSQL Database).

## Firebase Cloud Functions

**Responsibility**: Executes server-side logic triggered by events (e.g., new Firestore documents). For MVP, its main role is triggering push notifications.

**Key Interfaces**: Firestore Triggers (e.g., onWrite, onCreate), FCM API.

**Dependencies**: Firebase Admin SDK, FCM SDK.

**Technology Stack**: Node.js, TypeScript.

## Firebase Cloud Messaging (FCM)

**Responsibility**: Delivers push notifications to iOS devices based on triggers from Cloud Functions.

**Key Interfaces**: FCM API (used by Cloud Functions), Apple Push Notification service (APNs) integration.

**Dependencies**: None (Managed Cloud Service).

**Technology Stack**: Firebase Cloud Service.

## Component Diagrams

```mermaid
C4Container
    title Component Diagram for MessageAI MVP

    System_Boundary(c1, "MessageAI System") {
        Container(ios_app, "iOS Application", "Swift/SwiftUI", "Provides the UI, manages local state, interacts with Firebase.")
        ContainerDb(local_db, "Local Cache", "SwiftData", "Stores local copy of messages for offline access.")

        System_Ext(firebase, "Firebase Platform", "Managed Cloud Services")
    }

    System_Ext(apns, "Apple Push Notification Service (APNs)")

    Rel(ios_app, local_db, "Reads/Writes")
    Rel(ios_app, firebase, "Uses Firebase SDK for Auth, Firestore")
    Rel(firebase, ios_app, "Sends Real-time Updates (Firestore), Push Notifications (FCM via APNs)")
    Rel(firebase, apns, "Sends Push Notifications via FCM")

    UpdateElementStyle(ios_app, $bgColor="lightblue")
    UpdateElementStyle(local_db, $bgColor="lightgrey")
```

```mermaid
graph LR
    subgraph "iOS Application"
        UI(SwiftUI Views) --> VM(ViewModels)
        VM --> Repo(Local Repository)
        VM --> FirebaseSvc(Firebase Service Layer)
        Repo --> SD[(SwiftData)]
        FirebaseSvc --> SDK{Firebase SDK}
    end

    subgraph "Firebase Backend"
        SDK -- Interacts --> Auth[Firebase Auth]
        SDK -- Interacts --> FS[Firestore DB]
        FS -- Triggers --> Funcs[Cloud Functions]
        Funcs -- Calls --> FCM[Firebase Cloud Messaging]
    end

    FCM --> APNS[APNs]
    APNS --> UI
```
