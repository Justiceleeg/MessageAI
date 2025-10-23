# AI Features - Architectural Briefing

**Date:** October 22, 2025  
**For:** @architect  
**From:** @po  
**Priority:** HIGH  
**Timeline:** Implementation starts Oct 23, must complete by Oct 25

---

## Executive Summary

We're implementing 6 AI-powered features for the "Busy Person with Friends" persona. These features introduce:
- OpenAI API integration (new dependency)
- 3 new data models (Events, Reminders, Decisions)
- Message linking system (navigation back to source messages)
- Third-party calendar library integration
- Real-time AI processing on user messages

**Your input is critical for:** API integration strategy, data model design, and storage architecture.

---

## Feature Overview

### Persona: Busy Person with Friends
**Goal:** Help users manage social plans, track decisions, and stay organized without manual effort.

### 6 AI Features:

| # | Feature | AI Task | User Interaction |
|---|---------|---------|------------------|
| 1 | Smart Calendar Extraction | Detect dates/times/events in messages | Click "➕ Add to calendar?" → Modal → Confirm |
| 2 | Decision Summarization | Detect when decisions are made | Click "✓ Confirm decision?" → Modal → Edit/Confirm |
| 3 | Priority Message Highlighting | Classify urgency (Yellow/Red) | Passive (background tints in UI) |
| 4 | RSVP Tracking | Detect invitations & RSVPs | Click "🎉 Create event?" or "✓ RSVP?" → Modal |
| 5 | Deadline/Reminder Extraction | Detect commitments/deadlines | Click "⏰ Set reminder?" → Modal → Confirm |
| 6 | Proactive Assistant | Detect scheduling conflicts | Show "⚠️" warning → Suggest alternatives |

---

## UI Pattern (Consistent Across All Features)

```
Chat View:
┌────────────────────────────────┐
│ Me: Let's meet at Coffee Place │
│     Tuesday at 3pm             │
│     ┌────────────────────────┐ │
│     │ ➕ Add to calendar?    │ │ ← AI-generated prompt
│     └────────────────────────┘ │
└────────────────────────────────┘

User clicks → Modal appears → User confirms/edits → Action taken
```

**Key Points:**
- AI analyzes outgoing messages in real-time
- Prompts appear below user's message bubble
- Click opens modal for confirmation/editing
- All actions link back to source message for navigation

---

## Critical Architectural Decisions Needed

### 1. OpenAI API Integration ⚠️ CRITICAL

**Requirements:**
- Analyze every outgoing message for all 6 feature types
- Real-time detection (minimal latency)
- Must handle 6 simultaneous classifications per message
- Cost-sensitive (user budget: TBD)

**Questions:**
1. **API Call Pattern:**
   - **Option A:** Single API call with 6-part prompt (detect all features at once)
   - **Option B:** 6 parallel API calls (faster but more expensive)
   - **Option C:** Background processing queue (slower but cheaper)
   - **Recommendation?**

2. **Which OpenAI Model:**
   - **GPT-4:** Most accurate, expensive (~$0.03/1K tokens)
   - **GPT-3.5-Turbo:** Fast, cheap (~$0.002/1K tokens), less accurate
   - **GPT-4-mini:** Balance? (~$0.005/1K tokens)
   - **Recommendation?**

3. **Where to Store API Key:**
   - Environment variable? (not committed to repo)
   - Encrypted in Keychain?
   - Backend service? (not in scope yet)
   - **Recommendation?**

4. **Request Structure:**
   ```swift
   // Pseudo-code example
   func analyzeMessage(_ text: String) async throws -> AIAnalysis {
       let prompt = """
       Analyze this message for:
       1. Calendar events (date, time, location)
       2. Decisions made (what was decided)
       3. Priority level (low/medium/high)
       4. RSVP intent (creating event or responding)
       5. Deadlines/reminders (task, due date)
       6. Scheduling conflicts (check against: \(userCalendar))
       
       Message: "\(text)"
       
       Return JSON: { calendar: {...}, decision: {...}, ... }
       """
       
       // How should we structure this?
       // Single call or separate calls?
       // Token optimization strategy?
   }
   ```

5. **Error Handling:**
   - If API fails, default to no AI suggestions?
   - Retry logic?
   - Timeout threshold?
   - **Recommendation?**

6. **Rate Limiting:**
   - OpenAI has rate limits (TBD based on tier)
   - How to handle burst messaging?
   - Queue vs. drop vs. throttle?
   - **Recommendation?**

---

### 2. Data Model Design ⚠️ CRITICAL

#### **Event Model**

**Requirements:**
- User creates event in Chat A → Event created
- User mentions same event in Chat B → Links to existing event (NOT new event)
- Multiple chats can reference same event
- Track attendees from each chat separately
- RSVP status per attendee
- Navigation to source messages (creation + all RSVPs)

**Questions:**
1. **Storage Location:**
   - **Option A:** Firestore (cloud-first, real-time sync)
   - **Option B:** SwiftData (local-first, offline support)
   - **Option C:** Hybrid (Firestore primary, SwiftData cache)
   - **Recommendation?**

2. **Schema Design:**
   ```swift
   // Proposed Event Schema
   struct Event {
       let id: String                    // Unique event ID
       let title: String                 // "David's Birthday Party"
       let date: Date                    // When
       let time: Date?                   // Optional time
       let location: String?             // Optional location
       let creatorUserId: String         // Who created it
       let createdInConversationId: String // Where created
       let createdAtMessageId: String    // Link to message
       
       // Multi-chat tracking
       let linkedConversations: [String: [Attendee]]
       // ["chatId1": [attendees from chat 1], "chatId2": [attendees from chat 2]]
       
       // Total attendees across all chats
       let allAttendees: [Attendee]
   }
   
   struct Attendee {
       let userId: String
       let status: RSVPStatus // .pending, .accepted, .declined
       let rsvpMessageId: String? // Link to RSVP message
       let invitedFrom: String // conversationId
   }
   
   enum RSVPStatus {
       case pending
       case accepted
       case declined
   }
   ```
   **Is this structure sound? Improvements?**

3. **Event Deduplication:**
   - AI suggests: "Link to existing 'Birthday Party' event?"
   - How to match? (title similarity + date + creator?)
   - Fuzzy matching algorithm?
   - **Recommendation?**

4. **Cross-Chat Event Discovery:**
   - How does User A's event in Chat 1 appear in Chat 2?
   - Do we query Firestore for matching events?
   - Performance implications?
   - **Recommendation?**

---

#### **Reminder Model**

**Requirements:**
- User commits to task → AI suggests reminder
- Reminders are personal (not shared)
- Notification triggered at due time
- Linked to source message

**Questions:**
1. **Storage:**
   - SwiftData (local notifications)?
   - Firestore (cloud-based reminders)?
   - **Recommendation?**

2. **Schema:**
   ```swift
   struct Reminder {
       let id: String
       let title: String              // "Send docs to John"
       let dueDate: Date              // When
       let conversationId: String     // Which chat
       let sourceMessageId: String    // Link to message
       let userId: String             // Owner
       let completed: Bool            // Status
       let notificationId: String?    // Local notification ID
   }
   ```
   **Is this sufficient?**

3. **Notification Scheduling:**
   - Use UNUserNotificationCenter?
   - Background refresh limitations?
   - What if app not running at due time?
   - **Recommendation?**

---

#### **Decision Model**

**Requirements:**
- Track decisions made in conversations
- User can edit AI's wording before confirming
- Linked to source message
- Displayed in Decisions view (per-chat + global)

**Questions:**
1. **Storage:**
   - SwiftData (local-first)?
   - Firestore (shared decisions)?
   - Are decisions private or visible to chat participants?
   - **Recommendation?**

2. **Schema:**
   ```swift
   struct Decision {
       let id: String
       let text: String               // "Going to Italian restaurant for dinner"
       let conversationId: String     // Which chat
       let sourceMessageId: String    // Link to message
       let userId: String             // Who logged it
       let timestamp: Date            // When decided
   }
   ```
   **Is this sufficient?**

---

### 3. Message Linking System ⚠️ MEDIUM

**Requirements:**
- Events/Reminders/Decisions link back to source messages
- User can tap to navigate to exact message in conversation
- Scroll to message + brief highlight

**Questions:**
1. **Navigation Architecture:**
   - How to implement deep linking to specific message?
   - ScrollViewReader with message ID anchor?
   - State management for scroll position?
   - **Recommendation?**

2. **Message ID Reference:**
   - Do our Message documents have stable IDs?
   - Are they queryable efficiently?
   - **Confirmation?**

3. **Highlight Animation:**
   - Temporary background color change?
   - Fade-in/fade-out effect?
   - **Implementation approach?**

---

### 4. Third-Party Library ⚠️ MEDIUM

**Library:** [Mijick CalendarView](https://github.com/Mijick/CalendarView)

**Why:**
- SwiftUI-native
- Highly customizable
- MIT License (permissive)
- Active maintenance

**Questions:**
1. **Approval to use?**
   - Fits our tech stack philosophy?
   - Any concerns about external dependencies?
   - Alternative: Build custom calendar view? (adds ~10-15 hours)

2. **Integration:**
   - Swift Package Manager (already in use)
   - Potential conflicts with existing dependencies?

---

### 5. AI Processing Architecture ⚠️ MEDIUM

**Requirements:**
- Analyze outgoing messages in real-time
- Minimal user-perceived latency
- Handle API failures gracefully
- Work offline (show cached suggestions?)

**Questions:**
1. **Processing Timing:**
   - **Option A:** Analyze BEFORE message sent (blocks send)
   - **Option B:** Send message immediately, analyze in background (AI prompt appears after)
   - **Option C:** Analyze on-device first, then confirm with API
   - **Recommendation?**

2. **Offline Handling:**
   - Queue AI requests when offline?
   - Process when back online?
   - Or disable AI features offline?
   - **Recommendation?**

3. **Caching Strategy:**
   - Cache AI responses for edited messages?
   - Cache event deduplication matches?
   - TTL for cached responses?
   - **Recommendation?**

---

### 6. Calendar View Architecture ⚠️ LOW

**Requirements:**
- Show events in calendar grid (Mijick CalendarView)
- Show reminders in list view (separate tab)
- Filter by chat (per-chat Events & Reminders view)
- Query efficiency for upcoming events/reminders

**Questions:**
1. **Data Fetching:**
   - Query events/reminders on calendar view load?
   - Real-time listeners for updates?
   - Pagination for large datasets?
   - **Recommendation?**

2. **Performance:**
   - How many events/reminders before performance degrades?
   - Lazy loading strategy?
   - **Recommendation?**

---

## Existing Architecture Context

### Current Tech Stack:
- **Frontend:** SwiftUI (iOS 14+)
- **Backend:** Firebase (Auth, Firestore, Realtime Database)
- **Local Persistence:** SwiftData
- **Networking:** Native async/await
- **Dependency Management:** Swift Package Manager

### Current Data Flow:
```
User Action → ViewModel → Service Layer → Firebase/SwiftData → ViewModel → View Update
```

### Existing Services:
- `AuthService` - Firebase Authentication
- `FirestoreService` - Firestore operations
- `PresenceService` - Realtime Database presence
- `OfflineMessageQueue` - Message queuing for offline
- `NetworkMonitor` - Network status tracking
- `NotificationManager` - Local notifications

### Where AI Fits:
```
User sends message → ChatViewModel.sendMessage()
                  ↓
                  → AIAnalysisService.analyze(message) [NEW]
                  ↓
                  → OpenAI API call [NEW]
                  ↓
                  → Parse response [NEW]
                  ↓
                  → Show AI prompts in UI [NEW]
```

---

## Priority Decisions

### Must Decide Before Implementation (Oct 23):
1. ✅ OpenAI API integration pattern (single call vs parallel vs background)
2. ✅ Event storage location (Firestore vs SwiftData vs hybrid)
3. ✅ Message linking architecture (navigation approach)
4. ✅ API key storage strategy
5. ✅ Which OpenAI model to use

### Can Decide During Implementation:
6. Event deduplication algorithm details
7. Caching strategy specifics
8. Performance optimization techniques
9. Notification scheduling approach

### Post-MVP:
10. Cost optimization
11. Advanced conflict detection
12. Scalability improvements

---

## Constraints & Considerations

### Timeline:
- **Oct 23-25:** 3 days for full implementation
- **Total estimated:** 26-34 hours of dev work
- **Reality:** Must be efficient, no time for major refactors

### Budget:
- OpenAI API costs (TBD - need user's OpenAI tier/limits)
- Free tier: ~$5 credit, limited requests
- User has OpenAI API key (confirmed)

### User Experience:
- AI suggestions should feel fast (<1 second ideal)
- Graceful degradation if API fails
- Offline support where possible

### Security:
- API keys must never be committed to repo (public until Oct 27)
- User data sent to OpenAI (privacy implications?)
- Event/Reminder data privacy (who can see what?)

---

## Recommended Reading

Before consultation, please review:
- **Tech Stack:** `docs/architecture/tech-stack.md`
- **Current Architecture:** `docs/architecture/backend-architecture.md`
- **Data Models:** `docs/architecture/data-models.md`
- **Coding Standards:** `docs/architecture/coding-standards.md`

---

## Next Steps

1. **Architect reviews this document** (~30-60 min)
2. **Consultation call/chat** with @po (~1-2 hours)
3. **Architect provides technical decisions** (documented)
4. **@sm creates Epic + Stories** based on architectural guidance (~1 hour)
5. **@dev begins implementation** (Oct 23)

---

## Questions?

Please prepare answers/recommendations for the questions marked ⚠️ CRITICAL.

For MEDIUM/LOW priority items, high-level guidance is sufficient - we can iterate during implementation.

---

**Thank you for your architectural guidance! This is a major feature set and your expertise is crucial for success.** 🏗️

