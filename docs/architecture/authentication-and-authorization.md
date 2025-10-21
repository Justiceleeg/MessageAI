# Authentication and Authorization

## Auth Flow

Primarily client-side via Firebase Auth iOS SDK. Backend relies on trigger/Admin SDK context.

```mermaid
sequenceDiagram
    participant User
    participant App
    participant AuthService
    participant SDK
    participant FirebaseAuth
    User->>App: Enter Creds, Tap Login
    App->>AuthService: initiateLogin()
    AuthService->>SDK: Auth.signIn()
    SDK->>FirebaseAuth: Verify
    FirebaseAuth-->>SDK: Result
    SDK-->>AuthService: Result
    alt Success
        AuthService->>App: Update State
        App->>App: Navigate Main
    else Failure
        AuthService->>App: Error
        App->>User: Show Error
    end
```

## Middleware/Guards

Authorization enforced mainly via Firestore Security Rules checking request.auth.uid.

**Example Rule**:

```javascript
match /conversations/{convId} { allow read: if request.auth.uid in resource.data.participants; }
```
