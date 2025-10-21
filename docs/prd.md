# MessageAI Product Requirements Document (PRD)

## Goals and Background Context

### Goals

- **Primary Goal (MVP)**: Successfully build and deploy a production-quality messaging app that meets all MVP requirements within the 24-hour sprint deadline.
- **Secondary Goal (Project)**: Create a robust, reliable, and scalable messaging infrastructure comparable to WhatsApp, capable of serving as a foundation for advanced AI features.
- **Final Goal (Project)**: Successfully implement all 5 required AI features and one advanced AI capability tailored to a specific user persona by the final 7-day deadline.

### Background Context

The core technical challenge of modern messaging is twofold. First, building a production-quality infrastructure is complex, requiring solutions for real-time delivery, offline support, and data sync. Second, as communication volume increases, users face significant pain points like information overload, language barriers, and scheduling chaos that basic messaging does not solve.

This project addresses the urgent need to bridge that gap by first building a reliable messaging engine (the MVP) and then layering on intelligent AI features to make communication more productive, accessible, and meaningful.

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| October 20, 2025 | 1.0 | Initial PRD draft | John (PM) |

## Requirements

### Functional

- **FR1**: The system must support one-on-one chat functionality.
- **FR2**: The system must deliver messages in real-time between two or more online users.
- **FR3**: The system must support basic group chat functionality for three or more users in one conversation.
- **FR4**: The system must provide user authentication, allowing users to create accounts and have profiles.
- **FR5**: The system must display timestamps for all messages.
- **FR6**: The system must provide message read receipts.
- **FR7**: The system must display online/offline status indicators for users.
- **FR8**: The system must deliver push notifications, at least while the app is in the foreground.

### Non Functional

- **NFR1**: Messages must persist locally and survive application restarts (Offline-First).
- **NFR2**: The UI must update optimistically, with sent messages appearing instantly in the UI before server confirmation.
- **NFR3**: The application must be runnable on a local emulator/simulator, connecting to a deployed backend (Firebase).
- **NFR4**: The system must be built using the "Golden Path" stack: Swift/SwiftUI, Firebase (Firestore, Functions, Auth, FCM), and SwiftData.

## User Interface Design Goals

### Overall UX Vision

The user experience must be fast, reliable, and intuitive, prioritizing function over flash. The design should get out of the way and let the user communicate. It must gracefully handle poor network conditions and offline states, clearly communicating the status of messages (e.g., sending, sent, delivered, read).

### Key Interaction Paradigms

The app will follow established, native iOS messaging patterns. The primary interaction will be a standard conversation list view that drills into a chat view. Gestures and interactions should feel native to the iOS platform.

**Theme Support:**

The UI must automatically respond to the user's system-preferred theme (Dark Mode or Light Mode).

A setting must be provided to allow the user to override this behavior and manually select one of three options:
- System Default
- Always Light
- Always Dark

### Core Screens and Views

- **Authentication View**: A screen for user sign-up and login.
- **Conversation List View**: A list of all active 1:1 and group conversations, showing the contact/group name and the last message.
- **Chat View**: The main interface for a single conversation, showing the message history, a text input field, and a send button.
- **Contact/Profile View**: A simple view to display user profile information.
- **Settings View**: A view to manage preferences, including the new theme setting.

### Accessibility: WCAG AA

The app should aim for WCAG AA compliance to be accessible.

### Branding

(TBD - Assumed to be clean, minimalist, and professional. No specific branding guidelines provided.)

### Target Device and Platforms: iOS

The app will be built as a native iOS application using Swift and SwiftUI.

## Technical Assumptions

### Repository Structure: Monorepo

A monorepo is assumed to co-locate the iOS Swift project and the Firebase Cloud Functions backend, simplifying dependency management and shared code.

### Service Architecture: Serverless

The backend will be a serverless architecture using Firebase Cloud Functions. This aligns with the MVP's need for rapid deployment and automatic scaling.

### Testing Requirements: Unit + Integration

Development will include unit tests for business logic (e.g., in Cloud Functions) and local persistence (SwiftData).

Integration testing will be required to validate the end-to-end flow from the SwiftUI client to the Firestore database.

### Additional Technical Assumptions and Requests

- **Language (Mobile)**: Swift.
- **UI Framework**: SwiftUI.
- **Backend Logic**: Firebase Cloud Functions.
- **Database (Remote)**: Firebase Firestore.
- **Database (Local)**: SwiftData.
- **Authentication**: Firebase Auth.
- **Push Notifications**: Firebase Cloud Messaging (FCM).

## Epic List

- **Epic 1: Foundation, Auth & Profile Management**: Establish the core application foundation, user authentication (FR4), and basic user-facing features like the profile/contact view and the theme settings (UI Goals).
- **Epic 2: Core 1:1 Messaging & Reliability**: Implement the primary 1:1 chat functionality (FR1), real-time message delivery (FR2), message timestamps (FR5), local persistence (NFR1), and optimistic UI updates (NFR2).
- **Epic 3: Group Chat & Presence Features**: Expand functionality to include basic group chat (FR3), message read receipts (FR6), online/offline status indicators (FR7), and foreground push notifications (FR8).

## Epic 1: Foundation, Auth & Profile Management

**Epic Goal**: Establish the core application foundation, user authentication (FR4), and basic user-facing features like the profile/contact view and the theme settings (UI Goals).

### Story 1.1: New User Account Creation

**As a** new user, **I want to** create a new account, **so that** I can access the messaging application.

**Acceptance Criteria**
- A user can access a sign-up screen.
- A user can create a new account using Firebase Auth (e.g., email/password).
- Upon successful account creation, a corresponding user profile is created in the users collection in Firestore.
- Upon success, the user is navigated into the main app (e.g., Conversation List View).
- If sign-up fails, a clear error message is displayed to the user.

### Story 1.2: Existing User Login & Logout

**As an** existing user, **I want to** log in and log out of my account, **so that** I can access my messages securely.

**Acceptance Criteria**
- A user can access a login screen.
- A user can log in using their existing Firebase Auth credentials.
- Upon successful login, the user is navigated to the main app (e.g., Conversation List View).
- If login fails (e.g., wrong password), a clear error message is displayed.
- A logged-in user can find a "Logout" button (e.g., in the Settings View).
- Tapping "Logout" signs the user out of Firebase Auth and navigates them back to the login screen.

### Story 1.3: User Theme Selection

**As a** user, **I want to** change my app's theme, **so that** it matches my visual preference (light, dark, or system default).

**Acceptance Criteria**
- A "Settings View" is accessible from the main app.
- The app, by default, respects the system's Light or Dark Mode.
- The "Settings View" provides three options: "System Default," "Light," and "Dark."
- Selecting "Light" forces the app into Light Mode, regardless of the system setting.
- Selecting "Dark" forces the app into Dark Mode, regardless of the system setting.
- Selecting "System Default" reverts the app to respecting the system's setting.
- The user's choice is persisted and applied on the next app launch.

## Epic 2: Core 1:1 Messaging & Reliability

**Epic Goal**: Implement the primary 1:1 chat functionality (FR1), real-time message delivery (FR2), message timestamps (FR5), local persistence (NFR1), and optimistic UI updates (NFR2).

### Story 2.1: View Conversation List

**As a** user, **I want to** see a list of all my existing conversations, **so that** I can select one to continue chatting.

**Acceptance Criteria**
- The main app screen (after login) displays a list of the user's 1:1 conversations.
- Each item in the list shows the other user's display name and a preview of the most recent message.
- The list is updated in real-time if a new message is received in any conversation.
- Tapping a conversation navigates the user to the Chat View for that specific chat.
- If the user has no conversations, a "No conversations yet" message is displayed.

### Story 2.2: Send & Receive Real-time 1:1 Messages

**As a** user, **I want to** send and receive messages in a 1:1 chat, **so that** I can communicate with another user.

**Acceptance Criteria**
- When a user opens a Chat View, they see the message history for that conversation (FR1).
- Messages sent by the current user are displayed on one side (e.g., right), and messages from the other user are on the other (e.g., left).
- A user can type text into an input field and tap "Send".
- The sent message is immediately saved to the Firestore messages sub-collection for that conversation.
- Any new message received in this conversation appears at the bottom of the chat history in real-time (FR2).
- Every message displayed in the chat history includes a human-readable timestamp (e.g., "10:30 AM") (FR5).

### Story 2.3: Ensure Offline Persistence & Optimistic UI

**As a** user, **I want** my messages to appear instantly and be available when I'm offline, **so that** the app feels fast and I am never without my data.

**Acceptance Criteria**
- When a user taps "Send", the message immediately appears in their Chat View with a "sending..." indicator (NFR2).
- Once the message is confirmed by Firestore, the indicator disappears (or changes to "sent").
- All received and sent messages are saved to the local SwiftData database (NFR1).
- If the user restarts the app, all previously synced messages are loaded instantly from SwiftData before any network request is made (NFR1).
- If a user sends a message while offline, it appears in their UI optimistically and is added to a queue.
- When the user's device reconnects, all queued messages are automatically sent.

## Epic 3: Group Chat & Presence Features

**Epic Goal**: Expand functionality to include basic group chat (FR3), message read receipts (FR6), online/offline status indicators (FR7), and foreground push notifications (FR8).

### Story 3.1: Implement Basic Group Chat

**As a** user, **I want to** participate in group chats with 3 or more users, **so that** I can communicate with multiple people simultaneously.

**Acceptance Criteria**
- Users can create or be added to conversations involving 3 or more participants (FR3).
- The Conversation List View correctly displays group chats (e.g., showing group name or participant list).
- The Chat View functions correctly for group conversations, displaying messages from all participants.
- Messages sent in a group chat are delivered in real-time to all online participants in that group.
- Offline persistence and optimistic UI (from Epic 2) function correctly for group chat messages.

### Story 3.2: Display Message Read Receipts

**As a** user, **I want to** see if my messages have been read by recipients, **so that** I know if my communication was received.

**Acceptance Criteria**
- Each message sent by the user displays an indicator showing its current status (e.g., "sent," "delivered," "read") (FR6).
- The status updates in real-time as recipients receive and read the messages.
- In group chats, the "read" status indicates when all recipients have read the message (MVP scope).
- The system correctly updates message status in Firestore when a message is delivered or read.

### Story 3.3: Implement Presence & Notifications

**As a** user, **I want to** see if other users are online and receive notifications for new messages, **so that** I can manage my communication effectively.

**Acceptance Criteria**
- The app displays an indicator showing whether other users are currently online or offline (FR7).
- The presence status updates in (near) real-time.
- When a new message is received for a conversation the user is not currently viewing, a push notification is delivered to the device (FR8).
- This notification works reliably when the app is in the foreground (MVP scope).
- A Firebase Cloud Function is implemented and deployed to trigger FCM notifications based on new messages in Firestore.