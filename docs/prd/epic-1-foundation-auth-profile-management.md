# Epic 1: Foundation, Auth & Profile Management

**Epic Goal**: Establish the core application foundation, user authentication (FR4), and basic user-facing features like the profile/contact view and the theme settings (UI Goals).

## Story 1.1: New User Account Creation

**As a** new user, **I want to** create a new account, **so that** I can access the messaging application.

**Acceptance Criteria**
- A user can access a sign-up screen.
- A user can create a new account using Firebase Auth (e.g., email/password).
- Upon successful account creation, a corresponding user profile is created in the users collection in Firestore.
- Upon success, the user is navigated into the main app (e.g., Conversation List View).
- If sign-up fails, a clear error message is displayed to the user.

## Story 1.2: Existing User Login & Logout

**As an** existing user, **I want to** log in and log out of my account, **so that** I can access my messages securely.

**Acceptance Criteria**
- A user can access a login screen.
- A user can log in using their existing Firebase Auth credentials.
- Upon successful login, the user is navigated to the main app (e.g., Conversation List View).
- If login fails (e.g., wrong password), a clear error message is displayed.
- A logged-in user can find a "Logout" button (e.g., in the Settings View).
- Tapping "Logout" signs the user out of Firebase Auth and navigates them back to the login screen.

## Story 1.3: User Theme Selection

**As a** user, **I want to** change my app's theme, **so that** it matches my visual preference (light, dark, or system default).

**Acceptance Criteria**
- A "Settings View" is accessible from the main app.
- The app, by default, respects the system's Light or Dark Mode.
- The "Settings View" provides three options: "System Default," "Light," and "Dark."
- Selecting "Light" forces the app into Light Mode, regardless of the system setting.
- Selecting "Dark" forces the app into Dark Mode, regardless of the system setting.
- Selecting "System Default" reverts the app to respecting the system's setting.
- The user's choice is persisted and applied on the next app launch.
