# Security and Performance

Key security and performance considerations.

## Security Requirements

- **Frontend (iOS)**: Use Keychain for sensitive storage (if needed beyond Firebase Auth). Ensure TLS via Firebase SDK.
- **Backend (Firebase)**: Firestore Security Rules are primary defense. Use Functions config for secrets. Validate triggers.
- **Authentication**: Managed by Firebase Auth SDK/Service.

## Performance Optimization

- **Frontend (iOS)**: SwiftUI best practices, aggressive SwiftData caching (Offline-First), efficient listener management.
- **Backend (Firebase)**: Efficient Firestore queries/indexes, lean Cloud Functions, data denormalization where needed.
