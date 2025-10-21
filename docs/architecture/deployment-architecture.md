# Deployment Architecture

Strategy for deploying the iOS app and Firebase backend.

## Deployment Strategy

- **Frontend (iOS)**: Apple App Store (via TestFlight for testing). Build via Xcode (xcodebuild).
- **Backend (Firebase)**: Firebase Cloud Functions, Firestore. Build via `npm run build` (in firebase-functions). Deploy via Firebase CLI (`firebase deploy`).

## CI/CD Pipeline

- **Platform**: TBD (Xcode Cloud, GitHub Actions, etc.).
- **Workflows**: Needed for iOS build/test/deploy (TestFlight) and Functions build/test/deploy.

## Environments

| Environment | Frontend Distribution | Backend Project | Purpose |
|-------------|----------------------|-----------------|---------|
| Development | Xcode Simulator/Device | Firebase Emulators/Dev | Local dev & testing |
| Staging | TestFlight | Staging Firebase Project | Pre-prod testing |
| Production | App Store | Prod Firebase Project | Live |
