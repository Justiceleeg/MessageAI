# Tech Stack

This section defines the definitive technology choices for the MessageAI project, based on the "Golden Path" specified in the PRD and project brief. All development must adhere to these specific technologies and versions.

## Technology Stack Table

| Category | Technology | Version | Purpose | Rationale |
|----------|-----------|---------|---------|-----------|
| Frontend Language | Swift | 5.9+ | Native iOS development language | Required for SwiftUI, provides safety and performance |
| Frontend Framework | SwiftUI | Latest | Declarative UI framework for iOS | Recommended for fastest iOS development, modern approach |
| UI Component Library | Native SwiftUI Components | N/A | Standard iOS UI elements | Provides native look, feel, and accessibility |
| State Management | SwiftUI (@State, @Observed...) | N/A | Built-in state management for SwiftUI | Sufficient for MVP scope, avoids external dependencies |
| Backend Language | TypeScript | 5.x | Language for Firebase Cloud Functions | Strongly typed JavaScript, good tooling, common for serverless |
| Backend Framework | Node.js | 18.x (LTS) | Runtime for Firebase Cloud Functions | Standard runtime for Firebase Functions, LTS for stability |
| API Style | N/A (Direct Firestore SDK) | N/A | Client interacts directly with Firestore | Simplifies MVP, leverages Firebase real-time sync |
| Database (Remote) | Firebase Firestore | N/A (Cloud) | Real-time NoSQL database | Core requirement for real-time sync, offline support |
| Database (Local) | SwiftData | iOS 17+ | Local persistence framework | Recommended for local storage, integrates well with SwiftUI |
| Cache | N/A (Handled by SwiftData) | N/A | Local persistence serves as cache | SwiftData provides offline caching mechanism |
| File Storage | Firebase Storage | N/A (Cloud) | (Post-MVP) For media messages | Integrated Firebase solution for file uploads (needed for image support) |
| Authentication | Firebase Auth | N/A (Cloud) | User authentication service | Handles sign-up, login, sessions securely |
| Frontend Testing | XCTest | Xcode Default | Native iOS unit/UI testing framework | Standard Apple testing framework |
| Backend Testing | Jest | Latest | Testing framework for Node.js/TypeScript | Popular choice for testing Firebase Functions |
| E2E Testing | XCUITest | Xcode Default | Native iOS end-to-end testing | Standard Apple framework for UI automation |
| Build Tool | Xcode | Latest | iOS application build system | Standard Apple IDE and build tools |
| Bundler | N/A (Handled by Xcode) | N/A | App bundling handled by Xcode | Standard iOS development process |
| IaC Tool | Firebase CLI / Console | Latest | Infrastructure management for Firebase | Standard way to manage Firebase resources |
| CI/CD | TBD (e.g., GitHub Actions, ...) | N/A | Continuous integration/deployment pipeline | To be decided based on repository host / preference |
| Monitoring | Firebase Monitoring/Crashlytics | N/A (Cloud) | Performance and crash reporting | Integrated Firebase tools for app health |
| Logging | Firebase Functions Logs / OSLog | N/A | Backend / Native iOS logging mechanisms | Standard logging tools for the respective environments |
| CSS Framework | N/A (Handled by SwiftUI) | N/A | Styling is done via SwiftUI modifiers | Native iOS styling approach |
