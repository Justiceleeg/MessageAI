# Unified Project Structure

Monorepo structure housing iOS and Firebase code.

```
MessageAI/                  # Root
├── .github/                 # Optional: CI/CD
├── ios-app/                 # Xcode Project
│   ├── MessageAI/           # Source (Models, Views, ViewModels, Services, Persistence)
│   ├── MessageAI.xcodeproj
│   └── ...Tests/
├── firebase-functions/      # Cloud Functions (Node/TS)
│   ├── src/                 # Function source (index.ts, notifications.ts)
│   ├── tests/               # Jest tests
│   ├── package.json
│   ├── firebase.json        # Firebase config
│   └── firestore.rules      # Security Rules
├── docs/                    # BMad docs (brief.md, prd.md, architecture.md)
├── scripts/                 # Optional: Utility scripts
└── README.md
```
