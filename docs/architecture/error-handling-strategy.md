# Error Handling Strategy

Unified approach for frontend and backend.

## Error Flow

Handle errors close to source, log details, return user-friendly errors to UI.

## Error Response Format

- **Client (Swift)**: Use NSError from SDKs, custom Swift Error enums. Present user-friendly messages.
- **Backend (TS Functions)**: Log details via `functions.logger.error()`. Standard HTTP errors if HTTP endpoints were used (N/A for MVP).

## Frontend Error Handling (SwiftUI)

Use do-catch or Result for service calls. ViewModels catch, log (OSLog), update @Published state for UI (Alert, inline message).

## Backend Error Handling (TS Functions)

Use try-catch in handlers. Log extensively with `functions.logger`. Rely on Firebase auto-retries for triggers. Design for idempotency.
