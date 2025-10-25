# Epic 5: AI-Powered Messaging Features

## Epic Overview

**Status:** Near Complete (5.6 remaining)  
**Priority:** High  
**Timeline:** Oct 23-26, 2025 (4 days)  
**Dependencies:** Requires Epic 4 completion (Post-MVP UX)

## Description

This epic introduces AI-powered capabilities to MessageAI using a Python backend with LangChain + Pinecone. The system intelligently analyzes messages to help the "Busy Person with Friends" persona manage social plans, track decisions, and stay organized without manual effort. The AI provides contextual assistance by detecting events, decisions, reminders, and scheduling conflicts directly from natural conversation.

## Goals

1. **Smart Event Management:** Automatically detect and extract calendar events from messages, enable RSVP tracking, and prevent double-booking with proactive conflict detection.

2. **Context-Aware Decision Tracking:** Detect when decisions are made in conversations and provide semantic search across all logged decisions.

3. **Intelligent Reminders:** Extract commitments and deadlines from messages and schedule notifications automatically.

4. **Priority Intelligence:** Classify message urgency automatically to help users focus on what matters.

5. **RAG-Enhanced Summarization:** Provide context-aware conversation summaries using vector search to retrieve relevant historical context.

## User Value

- **Effortless Organization:** AI handles the mental load of extracting calendar events, deadlines, and decisions from natural conversation
- **Never Miss Important Info:** Priority detection and reminders ensure critical messages and commitments don't slip through
- **Quick Catch-Up:** RAG-powered summaries provide instant context from conversation history
- **Smarter Scheduling:** Proactive conflict detection prevents double-booking and suggests alternatives
- **Semantic Search:** Find past decisions and events by meaning, not just keywords

## Architecture Overview

### System Components
- **Python Backend:** FastAPI server with LangChain orchestration
- **Vector Database:** Pinecone for semantic search and embeddings
- **LLM:** OpenAI GPT-4o-mini for analysis, text-embedding-3-small for vectors
- **iOS Integration:** REST API calls from Swift to Python backend
- **Storage:** Hybrid approach with consistent pattern:
  - **iOS Services:** Handle all Firestore CRUD operations (Events, Reminders, Decisions)
  - **Backend:** Only handles Pinecone vector storage for semantic search
  - **No Firebase Admin SDK** required on backend (cleaner separation)

### Key Technologies
- LangChain for RAG chains and agent-based reasoning
- Pinecone for vector similarity search
- OpenAI API for embeddings and chat completion
- FastAPI for REST API endpoints

## Success Criteria

1. **Functional Requirements:**
   - All 6 AI features working end-to-end
   - Python backend deployed and accessible from iOS
   - Vector search returns semantically relevant results
   - RAG summaries include historical context
   - LangChain agent successfully detects scheduling conflicts

2. **Performance Requirements:**
   - Message analysis: < 2 seconds
   - Thread summarization: < 3 seconds  
   - Event/decision search: < 500ms
   - Agent conflict detection: < 5 seconds

3. **Quality Requirements:**
   - No API keys committed to repository
   - Graceful error handling when backend unavailable
   - All features tested manually end-to-end
   - Code documented and follows coding standards

4. **Security Requirements:**
   - API keys stored in gitignored config files
   - No sensitive data in logs
   - Proper error messages (no stack traces to client)

## Recent Architecture Updates

**Date:** October 25, 2025  
**Impact:** Stories 5.1-5.5 implementation

### Key Changes Made During Epic 5 Implementation:

1. **Function Calling Implementation**
   - Moved from direct JSON generation to OpenAI function calling
   - More reliable, type-safe responses from AI
   - See `ai-features-technical-spec.md` lines 958-1054

2. **Performance Optimization**
   - Model change: `gpt-4o-mini` → `gpt-3.5-turbo`
   - Response time: 22+ seconds → ~3 seconds

3. **API Response Format Updates**
   - Added `is_invitation` field to calendar detection
   - Added `event_reference` to RSVP responses
   - Proper snake_case/camelCase mapping with CodingKeys

4. **UI Consolidation**
   - Single menu with three dots (Calendar, Decisions, Reminders)
   - Unified event creation flow using `EventInvitationModal`

**Note:** All pending stories (5.6) have been updated to reflect current API format and architecture patterns.

---

## Stories

### Story 5.0: Python Backend Foundation
**Effort:** 1 day  
**Value:** Critical infrastructure  
**Status:** ✅ Done

Sets up Python backend with FastAPI, LangChain, and Pinecone integration:
- FastAPI application structure
- Pinecone index creation and configuration
- OpenAI API integration
- Basic health check and test endpoints
- Environment configuration and secrets management
- Deployment to Render.com

**Dependencies:** None  
**Acceptance Criteria:** See Story 5.0 document

---

### Story 5.0.5: iOS Data Models & Services Foundation
**Effort:** 0.4 days  
**Value:** Critical infrastructure  
**Status:** ✅ Done

Create Swift data models and service layers for AI features:
- Event, Reminder, and Decision models
- SwiftData entities for local persistence
- EventService, ReminderService, DecisionService for CRUD operations
- Firestore synchronization layer
- Consistent architecture pattern (iOS handles Firestore, Backend handles Pinecone)

**Dependencies:** None  
**Acceptance Criteria:** See Story 5.0.5 document

---

### Story 5.1: Smart Calendar Extraction
**Effort:** 0.5 days  
**Value:** High - Core feature  
**Status:** Not Started

AI detects calendar events in messages and provides one-click creation:
- Analyze outgoing messages for dates, times, locations
- Display "➕ Add to calendar?" prompt below message
- Modal confirmation with editable fields
- Store events in Firestore with proper schema
- Generate embeddings and store in Pinecone for deduplication

**Dependencies:** Story 5.0, Story 5.0.5  
**Acceptance Criteria:** See Story 5.1 document

---

### Story 5.1.5: Calendar & Reminders UI
**Effort:** 0.6 days  
**Value:** High - Visual interface  
**Status:** Approved

Create visual calendar interface using Mijick CalendarView:
- Events tab with monthly grid calendar
- Reminders tab with grouped list view (Today, Tomorrow, This Week, Later)
- Event detail view with attendee RSVP status
- Reminder detail view with completion tracking
- "Jump to Message" navigation for all items
- Real-time Firestore synchronization

**Dependencies:** Story 5.0.5, Story 5.1  
**Acceptance Criteria:** See Story 5.1.5 document

---

### Story 5.1.6: Message Linking Navigation
**Effort:** 0.4 days  
**Value:** High - User trust & context  
**Status:** Not Started

Implement navigation from events, reminders, and decisions back to source messages:
- Add "Jump to Message" buttons to EventDetailView, ReminderDetailView, DecisionDetailView
- Navigate to conversation and scroll to specific message
- Highlight target message with temporary visual effect
- Handle edge cases (deleted messages, missing conversations)
- Maintain proper navigation state and back button flow

**Dependencies:** Story 5.0.5, Story 5.1.5, Story 5.2  
**Acceptance Criteria:** See Story 5.1.6 document

---

### Story 5.2: Decision Detection and Tracking
**Effort:** 0.75 days  
**Value:** High - Unique feature  
**Status:** ✅ Done

AI detects decisions using lightweight RAG for context:
- Retrieve recent conversation context from Pinecone (k=5 messages)
- Analyze with GPT-4o-mini for complete, contextual decision statements
- Store decisions with embeddings in Pinecone
- Provide Decisions view (per-chat and global)
- Semantic decision search
- Navigate to source message from decision

**Dependencies:** Story 5.0, Story 5.0.5  
**Acceptance Criteria:** See Story 5.2 document

---

### Story 5.3: Priority Message Highlighting
**Effort:** 0.25 days  
**Value:** Medium - Simple but useful  
**Status:** Not Started

AI classifies message urgency automatically:
- Analyze incoming messages for urgency indicators
- Apply subtle color tints (yellow/red) to conversation list
- Optional: Priority notifications with colored backgrounds
- Store priority metadata in Firestore

**Dependencies:** Story 5.0  
**Acceptance Criteria:** See Story 5.3 document

---

### Story 5.4: RSVP Tracking
**Effort:** 0.75 days  
**Value:** High - Social coordination  
**Status:** ✅ Done

AI detects invitations and RSVPs for event management:
- Detect "create event and invite" intent
- Detect RSVP responses ("I'll be there", "Count me in")
- Multi-chat event linking (same event referenced in multiple chats)
- Track attendees and RSVP status
- Calendar view integration

**Dependencies:** Story 5.0, Story 5.0.5, Story 5.1, Story 5.1.5  
**Acceptance Criteria:** See Story 5.4 document

---

### Story 5.5: Deadline/Reminder Extraction
**Effort:** 0.5 days  
**Value:** High - Practical utility  
**Status:** ✅ Done

AI extracts commitments and schedules reminders:
- Detect commitment language in messages
- Display "⏰ Set reminder?" prompt
- Schedule local notifications via UNUserNotificationCenter
- Store reminders with embeddings in Pinecone (vector-only backend)
- Per-chat reminders view (global view in Story 5.1.5)

**Dependencies:** Story 5.0, Story 5.0.5, Story 5.1.5  
**Acceptance Criteria:** See Story 5.5 document

---

### Story 5.6: Proactive Assistant with LangChain
**Effort:** 0.75 days  
**Value:** High - AI showcase feature  
**Status:** Not Started

LangChain agent provides proactive scheduling assistance:
- Detect scheduling intent in messages
- Check user's calendar for conflicts
- Use agent tools: check_calendar, search_messages, suggest_alternatives
- Display "⚠️ Add to calendar?" if conflict detected
- Provide alternative time suggestions

**Dependencies:** Story 5.0, Story 5.1, Story 5.4  
**Acceptance Criteria:** See Story 5.6 document

---

## Technical Notes

### Reference Documentation
- **Technical Specification:** `docs/architecture/ai-features-technical-spec.md`
- **Architecture Briefing:** `docs/architecture/ai-features-briefing.md`

### Key Implementation Phases
1. **Foundation (Completed):** Backend + iOS foundation (Stories 5.0, 5.0.5, 5.2)
2. **Day 1-2:** Calendar features (Stories 5.1, 5.1.5)
3. **Day 2-3:** RSVP + Reminders (Stories 5.4, 5.5)
4. **Day 3-4:** Priority + Agent (Stories 5.3, 5.6)
5. **Day 4:** Integration, polish, deployment, testing

### Architecture Pattern (Established in Stories 5.0.5 & 5.2)

All AI features follow a **consistent storage pattern**:

**iOS Client (Swift):**
- EventService, ReminderService, DecisionService handle Firestore CRUD
- Full control over data models and persistence
- Offline support via local SwiftData cache

**Python Backend (FastAPI + LangChain):**
- Only handles Pinecone vector storage (`POST /[type]/vector`, `DELETE /[type]/vector/{id}`)
- Provides semantic search endpoints (`GET /[type]/search`)
- No Firebase Admin SDK needed

**Why this pattern?**
- Clean separation of concerns
- iOS owns user data (Firestore)
- Backend specializes in AI/ML operations (Pinecone)
- Simpler backend deployment (no Firebase credentials needed)
- Consistent across Events, Reminders, Decisions

### New iOS Components
- `AIBackendService.swift` - HTTP client for Python backend (semantic search only)
- `EventService.swift` - Event CRUD + Firestore sync (from Story 5.0.5)
- `ReminderService.swift` - Reminder CRUD + Firestore sync (from Story 5.0.5)
- `DecisionService.swift` - Decision CRUD + Firestore sync (from Story 5.0.5)
- `CalendarView.swift` - Visual calendar using Mijick CalendarView (Story 5.1.5)

### New Python Backend Structure
```
python-backend/
├── app/
│   ├── main.py (FastAPI app)
│   ├── routes/
│   │   ├── analysis.py (message analysis)
│   │   ├── events.py (/events/vector, /events/search)
│   │   ├── reminders.py (/reminders/vector, /reminders/search)
│   │   ├── decisions.py (/decisions/vector, /decisions/search)
│   │   └── agent.py (LangChain proactive assistant)
│   ├── services/
│   │   ├── vector_store.py (Pinecone + LangChain)
│   │   ├── openai_service.py (OpenAI API wrapper)
│   │   └── agent_service.py (LangChain agents)
│   └── models/ (Pydantic request/response models)
├── requirements.txt
└── .env (gitignored)
```

### External Services
- OpenAI API (GPT-4o-mini + embeddings)
- Pinecone (vector database, free tier)
- Render.com (backend hosting, free tier)

### Testing Strategy
- **Primary Validation:** Manual end-to-end testing for all features
- **Optional:** Python unit tests with pytest (may be skipped)
- **Optional:** iOS unit tests for core logic (may be skipped)
- **Approach:** Time-constrained manual testing focus, consistent with Epic 4
- **No integration tests required**

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| OpenAI API rate limits | High | Use GPT-4o-mini (cheaper), implement simple queuing |
| LangChain complexity | Medium | Follow documentation closely, keep agent simple |
| Backend deployment issues | High | Test locally first, use Render.com (proven platform) |
| Timeline too aggressive | High | Story 5.6 can be simplified or dropped if needed |
| Pinecone setup challenges | Medium | Use free tier, follow integration guide |

## Dependencies & Blockers

**Upstream:**
- Requires OpenAI API key (user has this)
- Requires Pinecone account (user needs to create)
- Requires Render.com account (user needs to create)

**Downstream:**
- No immediate dependencies, but enables future AI enhancements

## Out of Scope (Post-MVP)

- Cost optimization and usage monitoring
- Advanced RAG techniques (chunking strategies, hybrid search)
- Firebase security rules for Python backend
- Multi-device sync for reminders/decisions
- User feedback loop for AI accuracy improvement
- Notification customization
- Analytics and metrics tracking

## Success Metrics (Post-Launch)

- AI prompt click-through rate (% of prompts acted upon)
- Event creation via AI vs manual
- Decision tracking adoption rate
- Reminder completion rate
- User engagement with RAG summaries
- Proactive assistant conflict prevention count

---

**Epic 5 represents a significant technical leap for MessageAI, introducing sophisticated AI capabilities while maintaining the clean UX established in earlier epics.**

