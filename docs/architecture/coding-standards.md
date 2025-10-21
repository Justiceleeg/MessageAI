# Coding Standards

Critical rules for consistency, especially with AI developers.

## Critical Fullstack Rules

- Use official Firebase SDKs.
- Consistent error handling (Swift do-catch/Result, TS try-catch/logger).
- Access Function config via `functions.config()`, no hardcoded secrets.
- Use SwiftData on background threads for UI responsiveness.
- Rely on Firestore Security Rules, don't bypass client-side.
- Trigger notifications only from backend Functions.

## Naming Conventions

| Element | Frontend (Swift) | Backend (TS) | Example |
|---------|-----------------|--------------|---------|
| Files | PascalCase | camelCase | ChatView.swift, notify.ts |
| Classes/Structs | PascalCase | PascalCase | ChatViewModel, Message |
| Functions/Methods | camelCase | camelCase | sendMessage(), getUsers() |
| Variables | camelCase | camelCase | userName, msgText |
| Constants | camelCase | UPPER_SNAKE_CASE | maxLen, MAX_RETRIES |
| Firestore Colls | lowercase | lowercase | users, conversations |
| Firestore Fields | camelCase | camelCase | displayName, lastSeen |
