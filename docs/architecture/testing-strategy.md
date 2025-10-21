# Testing Strategy

Approach for ensuring quality across the stack.

## Testing Pyramid

Standard pyramid: Unit (XCTest, Jest) -> Integration (XCTest, Firebase Emulators/Jest) -> UI/E2E (XCUITest).

## Test Organization

- **Frontend**: ios-app/MessageAITests/ (Unit/Integration), ios-app/MessageAIUITests/ (UI/E2E).
- **Backend**: firebase-functions/tests/ (Unit/Integration using Jest and Emulators).

## Test Examples

- **Frontend**: XCTest for ViewModel unit tests (mocking services).
- **Backend**: Jest with Firebase Emulator Suite (firebase-functions-test) for trigger integration tests.
