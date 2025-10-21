# Frontend Architecture

This section details the iOS application's internal architecture.

## Component Architecture

### Component Organization

The SwiftUI application will follow a standard MVVM pattern.

```
ios-app/
├── MessageAIApp.swift
├── Models/              # SwiftData Models
├── Views/               # SwiftUI Views (Auth, Conversations, Chat, Settings, Shared)
├── ViewModels/          # ObservableObjects (AuthViewModel, ConversationListViewModel, etc.)
├── Services/            # Firebase interaction (AuthService, FirestoreService, etc.)
└── Persistence/         # SwiftData setup
```

### Component Template (SwiftUI View)

```swift
import SwiftUI

struct ExampleView: View {
    @State private var localState: String = ""
    // @StateObject private var viewModel = ExampleViewModel()

    var body: some View {
        VStack { Text("Hello, World!") }
        .onAppear { /* Fetch data */ }
    }
}
#Preview { ExampleView() }
```

## State Management Architecture

### State Structure

Utilizes SwiftUI's built-in property wrappers (@State, @StateObject, @ObservedObject, @EnvironmentObject) and ViewModels. SwiftData (@Query, @Model) manages persistent local state. No external libraries needed for MVP.

### State Management Patterns

- **MVVM**: ViewModels expose state via @Published properties.
- **Dependency Injection**: Services injected into ViewModels.
- **Single Source of Truth**: Firestore (remote), SwiftData (local offline).

## Routing Architecture

### Route Organization

Managed using NavigationStack (iOS 16+). Root view checks auth state to show Auth or Main App. NavigationLink for drill-down (ConversationList -> ChatView). .sheet or .fullScreenCover for modals (Settings).

### Protected Route Pattern

Achieved by conditionally rendering the main NavigationStack based on authentication state provided by AuthService.

## Frontend Services Layer

### API Client Setup

Dedicated service classes encapsulate Firebase SDK calls (not direct HTTP).

```swift
// FirestoreService Example
import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    func fetchConversations(userId: String, completion: @escaping ([ConversationEntity]) -> Void) { /* ... listener ... */ }
    func sendMessage(conversationId: String, message: MessageEntity, completion: @escaping (Error?) -> Void) { /* ... write ... */ }
}

// AuthService Example
import FirebaseAuth

class AuthService: ObservableObject {
    @Published var currentUser: User?
    func signUp(...) { /* ... createUser ... */ }
    func signIn(...) { /* ... signIn ... */ }
    func signOut() { /* ... signOut ... */ }
}
```

### Service Example (Integration in ViewModel)

ViewModels use injected service dependencies.

```swift
import SwiftUI
import FirebaseFirestore // For ListenerRegistration

class ChatViewModel: ObservableObject {
    @Published var messages: [MessageEntity] = []
    private var firestoreService: FirestoreService
    private var conversationId: String
    private var messageListenerRegistration: ListenerRegistration?

    init(firestoreService: FirestoreService, conversationId: String) { /* ... store deps, call listen ... */ }
    func listenForMessages() { /* ... use service, setup listener ... */ }
    func sendMessage(text: String, senderId: String) { /* ... create entity, call service ... */ }
    deinit { messageListenerRegistration?.remove() }
}
```
