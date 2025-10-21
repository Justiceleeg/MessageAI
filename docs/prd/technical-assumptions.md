# Technical Assumptions

## Repository Structure: Monorepo

A monorepo is assumed to co-locate the iOS Swift project and the Firebase Cloud Functions backend, simplifying dependency management and shared code.

## Service Architecture: Serverless

The backend will be a serverless architecture using Firebase Cloud Functions. This aligns with the MVP's need for rapid deployment and automatic scaling.

## Testing Requirements: Unit + Integration

Development will include unit tests for business logic (e.g., in Cloud Functions) and local persistence (SwiftData).

Integration testing will be required to validate the end-to-end flow from the SwiftUI client to the Firestore database.

## Additional Technical Assumptions and Requests

- **Language (Mobile)**: Swift.
- **UI Framework**: SwiftUI.
- **Backend Logic**: Firebase Cloud Functions.
- **Database (Remote)**: Firebase Firestore.
- **Database (Local)**: SwiftData.
- **Authentication**: Firebase Auth.
- **Push Notifications**: Firebase Cloud Messaging (FCM).
