# AI Features - Technical Architecture Specification

**Date:** October 22, 2025  
**Version:** 1.0  
**For:** @dev (Implementation)  
**Approved By:** @architect

---

## Executive Summary

This document specifies the technical architecture for implementing 6 AI-powered features using a Python backend with LangChain + Pinecone, integrated with the existing iOS/Firebase application.

**Key Architectural Decisions:**
- Python backend with FastAPI for AI services
- LangChain framework for LLM orchestration and vector operations
- Pinecone for vector storage and semantic search
- OpenAI GPT-4o-mini for chat, text-embedding-3-small for embeddings
- Lightweight RAG for decision detection (vector search + context)
- Hybrid storage: Events in Firestore, Reminders/Decisions in Pinecone + Firestore

---

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   iOS App (Swift/SwiftUI)                   │
│                                                             │
│  • ChatView, CalendarView, ConversationListView            │
│  • AIBackendService (HTTP client)                           │
│  • EventService, ReminderService, DecisionService           │
└─────────────────────────────────────────────────────────────┘
                           │
                      HTTP/REST
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│       Python Backend (FastAPI + LangChain + Pinecone)       │
│                                                             │
│  API Layer (FastAPI)                                        │
│  ├─ POST /api/v1/analyze-message                           │
│  ├─ POST /api/v1/events/search                             │
│  ├─ POST /api/v1/reminders (create, list, search)          │
│  ├─ POST /api/v1/decisions (create, list, search)          │
│  └─ POST /api/v1/proactive-assist                          │
│                                                             │
│  Service Layer                                              │
│  ├─ VectorStoreService (Pinecone + LangChain)              │
│  ├─ OpenAIService (Chat completions + embeddings)          │
│  ├─ AgentService (LangChain agents + tools)                │
│  └─ FirebaseService (optional Firestore access)            │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
  ┌───────────┐      ┌──────────────┐      ┌──────────────┐
  │  OpenAI   │      │   Pinecone   │      │   Firebase   │
  │    API    │      │    Cloud     │      │  Firestore   │
  │           │      │              │      │              │
  │ • GPT-4o  │      │ • messages   │      │ • events     │
  │ • Embed   │      │ • events     │      │ • users      │
  └───────────┘      │ • reminders  │      │ • convos     │
                     │ • decisions  │      └──────────────┘
                     └──────────────┘
```

### Data Flow

#### Message Analysis Flow
```
User sends message in iOS
    ↓
Message saved to Firestore (existing flow)
    ↓
iOS calls POST /analyze-message
    ↓
Python backend:
  1. Generate embedding (OpenAI)
  2. Store in Pinecone (for future retrieval)
  3. Analyze message with GPT-4o-mini
  4. Return structured analysis
    ↓
iOS displays AI prompts below message
```

#### Decision Detection with Lightweight RAG Flow
```
User sends message → iOS calls POST /analyze-message
    ↓
Python backend:
  1. Search Pinecone for recent messages in conversation (k=5)
  2. Build context from retrieved messages
  3. Call GPT-4o-mini with context + current message
  4. AI extracts decision using full conversation context
  5. Generate embedding for message
  6. Store message in Pinecone
    ↓
iOS displays decision prompt with contextual summary
```

#### Event Deduplication Flow
```
User creates event → iOS calls Python backend
    ↓
Python backend:
  1. Generate event embedding
  2. Search Pinecone for similar events
  3. If similarity > 0.85 → Suggest linking
    ↓
iOS shows modal: "Link to existing event?"
```

#### LangChain Agent Flow
```
User types message with scheduling intent
    ↓
iOS calls POST /proactive-assist with message + calendar
    ↓
Python backend:
  1. LangChain agent analyzes message
  2. Agent uses tools:
     - check_calendar (look for conflicts)
     - search_related_messages (vector search)
     - suggest_alternatives (generate options)
  3. Agent returns structured response
    ↓
iOS shows ⚠️ if conflict detected
```

---

## Technology Stack

### Python Backend

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Web Framework | FastAPI | 0.109+ | REST API server |
| ASGI Server | Uvicorn | 0.27+ | Run FastAPI app |
| LLM Framework | LangChain | 0.1.4+ | LLM orchestration, RAG, agents |
| OpenAI Integration | langchain-openai | 0.0.5+ | OpenAI chat + embeddings |
| Vector DB | Pinecone | 3.0+ | Vector storage |
| Vector Integration | langchain-pinecone | 0.0.1+ | LangChain → Pinecone |
| OpenAI Client | openai | 1.12+ | Direct API access |
| Firebase | firebase-admin | 6.3+ | Optional Firestore access |
| Data Validation | Pydantic | 2.5+ | Request/response models |
| Config | python-dotenv | 1.0+ | Environment variables |

### iOS App (Existing + New)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| HTTP Client | URLSession | Call Python backend |
| New Service | AIBackendService | Wrapper for backend API calls |
| Existing Services | FirestoreService, EventService, etc. | Continue using for Firebase |

### External Services

| Service | Purpose | Free Tier | Cost |
|---------|---------|-----------|------|
| OpenAI API | LLM + embeddings | $5 credit | ~$0.20/month |
| Pinecone | Vector database | 100K vectors, 1 index | $0 |
| Render.com | Backend hosting | 750 hrs/month | $0 |

---

## API Specification

### Base URL
- **Development:** `http://localhost:8000/api/v1`
- **Production:** `https://messageai-backend.onrender.com/api/v1` (or your chosen host)

### Authentication
- For MVP: No authentication (trust iOS app)
- Post-MVP: Add API key or Firebase Auth token validation

### Endpoints

#### 1. Analyze Message
```http
POST /analyze-message
Content-Type: application/json

Request:
{
  "message_text": "Let's meet at 3pm Friday",
  "conversation_id": "conv_123",
  "user_id": "user_456",
  "user_calendar": [
    {"id": "evt1", "title": "Coffee", "date": "2025-10-27", "time": "15:00"}
  ]
}

Response:
{
  "calendar": {
    "detected": true,
    "title": "Meeting",
    "date": "2025-10-27",
    "time": "15:00",
    "location": null
  },
  "decision": null,
  "priority": {
    "level": "medium",
    "reason": "Time-specific request"
  },
  "rsvp": {
    "type": "create",
    "event_title": "Meeting"
  },
  "reminder": null,
  "conflict": {
    "detected": true,
    "conflicts": ["Coffee at 15:00"],
    "suggestions": ["14:00", "16:00"]
  }
}
```

#### 2. Search Decisions
```http
GET /decisions/search?user_id=user_456&query=restaurant&conversation_id=conv_123

Response:
{
  "results": [
    {
      "id": "dec_001",
      "text": "Going to Italian restaurant for dinner",
      "conversation_id": "conv_123",
      "source_message_id": "msg_999",
      "timestamp": "2025-10-22T18:00:00Z",
      "similarity": 0.88
    }
  ]
}
```

#### 3. Create Reminder
```http
POST /reminders
Content-Type: application/json

Request:
{
  "user_id": "user_456",
  "title": "Send docs to John",
  "due_date": "2025-10-24T17:00:00Z",
  "conversation_id": "conv_123",
  "source_message_id": "msg_789"
}

Response:
{
  "id": "rem_001",
  "title": "Send docs to John",
  "due_date": "2025-10-24T17:00:00Z",
  "conversation_id": "conv_123",
  "source_message_id": "msg_789",
  "completed": false
}
```

#### 4. List Reminders
```http
GET /reminders?user_id=user_456&conversation_id=conv_123

Response:
{
  "reminders": [
    {
      "id": "rem_001",
      "title": "Send docs to John",
      "due_date": "2025-10-24T17:00:00Z",
      "conversation_id": "conv_123",
      "source_message_id": "msg_789",
      "completed": false
    }
  ]
}
```

#### 5. Create Decision
```http
POST /decisions
Content-Type: application/json

Request:
{
  "user_id": "user_456",
  "text": "Going to Italian restaurant for dinner",
  "conversation_id": "conv_123",
  "source_message_id": "msg_999"
}

Response:
{
  "id": "dec_001",
  "text": "Going to Italian restaurant for dinner",
  "conversation_id": "conv_123",
  "source_message_id": "msg_999",
  "timestamp": "2025-10-22T18:00:00Z"
}
```

#### 6. Search Decisions
```http
GET /decisions/search?user_id=user_456&query=restaurant&conversation_id=conv_123

Response:
{
  "results": [
    {
      "id": "dec_001",
      "text": "Going to Italian restaurant for dinner",
      "conversation_id": "conv_123",
      "source_message_id": "msg_999",
      "timestamp": "2025-10-22T18:00:00Z",
      "similarity": 0.88
    }
  ]
}
```

#### 7. Proactive Assistant (LangChain Agent)
```http
POST /proactive-assist
Content-Type: application/json

Request:
{
  "message_text": "Let's meet at 3pm Friday",
  "user_calendar": [
    {"id": "evt1", "title": "Coffee with Alice", "date": "2025-10-27", "time": "15:00"}
  ],
  "conversation_context": "Previous discussion about urgent project"
}

Response:
{
  "conflict_detected": true,
  "conflicts": ["Coffee with Alice at 15:00 on Friday"],
  "suggestions": [
    "Change to 14:00",
    "Change to 16:00",
    "Move to Thursday at 15:00"
  ],
  "reasoning": "I found a conflict with your Coffee with Alice meeting at 3pm Friday. Based on the conversation context about the urgent project, I suggest meeting at 2pm or 4pm on Friday instead."
}
```

---

## Data Models

### Pinecone Index Structure

**Index Name:** `messageai`  
**Dimensions:** 1536 (text-embedding-3-small)  
**Metric:** cosine  
**Namespaces:**
- `messages` - Message embeddings
- `events` - Event embeddings
- `reminders` - Reminder embeddings
- `decisions` - Decision embeddings

#### Message Vector
```json
{
  "id": "msg_123",
  "values": [0.123, -0.456, ...],  // 1536-dim embedding
  "metadata": {
    "message_id": "msg_123",
    "conversation_id": "conv_456",
    "user_id": "user_789",
    "text": "Let's meet at 3pm",
    "timestamp": "2025-10-22T14:30:00Z",
    "type": "message"
  }
}
```

#### Event Vector
```json
{
  "id": "evt_123",
  "values": [0.789, -0.234, ...],
  "metadata": {
    "event_id": "evt_123",
    "title": "David's Birthday Party",
    "date": "2025-10-27",
    "time": "20:00",
    "user_id": "user_789",
    "creator_id": "user_456",
    "type": "event"
  }
}
```

#### Reminder Vector
```json
{
  "id": "rem_123",
  "values": [0.456, -0.789, ...],
  "metadata": {
    "reminder_id": "rem_123",
    "title": "Send docs to John",
    "due_date": "2025-10-24T17:00:00Z",
    "conversation_id": "conv_456",
    "source_message_id": "msg_789",
    "user_id": "user_123",
    "completed": false,
    "type": "reminder"
  }
}
```

#### Decision Vector
```json
{
  "id": "dec_123",
  "values": [0.321, -0.654, ...],
  "metadata": {
    "decision_id": "dec_123",
    "text": "Going to Italian restaurant",
    "conversation_id": "conv_456",
    "source_message_id": "msg_999",
    "user_id": "user_123",
    "timestamp": "2025-10-22T18:00:00Z",
    "type": "decision"
  }
}
```

### Firestore Collections (Existing + New)

#### Events Collection (NEW)
```
events/{eventId}
  - id: string
  - title: string
  - date: Timestamp
  - time: string (optional, "HH:mm")
  - location: string (optional)
  - creatorUserId: string
  - createdAt: Timestamp
  
  - invitations: map<conversationId, object>
    - messageId: string
    - invitedUserIds: array<string>
  
  - attendees: map<userId, object>
    - status: "pending" | "accepted" | "declined"
    - rsvpMessageId: string (optional)
    - rsvpConversationId: string (optional)
    - rsvpAt: Timestamp (optional)
```

#### Reminders Collection (NEW - for persistence)
```
reminders/{reminderId}
  - id: string
  - userId: string
  - title: string
  - dueDate: Timestamp
  - conversationId: string
  - sourceMessageId: string
  - completed: boolean
  - createdAt: Timestamp
  - notificationScheduled: boolean
```

#### Decisions Collection (NEW - for persistence)
```
decisions/{decisionId}
  - id: string
  - userId: string
  - text: string
  - conversationId: string
  - sourceMessageId: string
  - timestamp: Timestamp
```

---

## LangChain Architecture

### Components

#### 1. Embeddings
```python
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(
    model="text-embedding-3-small",
    openai_api_key=OPENAI_API_KEY
)
```

#### 2. Vector Store
```python
from langchain_pinecone import PineconeVectorStore

vector_store = PineconeVectorStore(
    index=pinecone_index,
    embedding=embeddings,
    namespace="messages"  # or events, reminders, decisions
)
```

#### 3. Lightweight RAG for Decision Detection
```python
from langchain_openai import ChatOpenAI

# Step 1: Retrieve recent context
recent_messages = vector_store.similarity_search(
    query=current_message,
    k=5,
    filter={"conversation_id": conversation_id}
)

# Step 2: Build context string
context = "\n".join([msg.page_content for msg in recent_messages])

# Step 3: Call LLM with context
llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.3)
prompt = f"""
Previous conversation:
{context}

Current message: "{current_message}"

Analyze for decisions. Use context to create complete statement.
"""

response = llm.invoke(prompt)
```

#### 4. Agent with Tools
```python
from langchain.agents import AgentExecutor, create_openai_functions_agent
from langchain.tools import Tool

tools = [
    Tool(
        name="check_calendar",
        func=check_calendar_function,
        description="Check user calendar for conflicts"
    ),
    Tool(
        name="search_messages",
        func=search_messages_function,
        description="Search conversation history"
    )
]

agent = create_openai_functions_agent(llm, tools, prompt)
executor = AgentExecutor(agent=agent, tools=tools)
```

---

## Directory Structure

```
MessageAI/
├── ios-app/                          # Existing iOS app
│   ├── MessageAI/
│   │   ├── Services/
│   │   │   ├── AIBackendService.swift      # NEW - HTTP client
│   │   │   ├── EventService.swift          # UPDATED
│   │   │   ├── ReminderService.swift       # NEW
│   │   │   ├── DecisionService.swift       # NEW
│   │   │   └── ...existing services...
│   │   └── ...
│   └── MessageAI.xcodeproj/
│
├── python-backend/                   # NEW Python backend
│   ├── app/
│   │   ├── main.py                   # FastAPI app entry point
│   │   ├── config.py                 # Configuration
│   │   │
│   │   ├── routes/                   # API endpoints
│   │   │   ├── __init__.py
│   │   │   ├── analysis.py           # Message analysis
│   │   │   ├── events.py             # Event search
│   │   │   ├── reminders.py          # Reminder CRUD
│   │   │   ├── decisions.py          # Decision CRUD
│   │   │   └── agent.py              # LangChain agent
│   │   │
│   │   ├── services/                 # Business logic
│   │   │   ├── __init__.py
│   │   │   ├── vector_store.py       # Pinecone + LangChain
│   │   │   ├── openai_service.py     # OpenAI API wrapper
│   │   │   ├── agent_service.py      # LangChain agents
│   │   │   └── firebase_service.py   # Optional Firestore
│   │   │
│   │   ├── models/                   # Data models
│   │   │   ├── __init__.py
│   │   │   ├── requests.py           # Pydantic request models
│   │   │   ├── responses.py          # Pydantic response models
│   │   │   └── database.py           # DB models
│   │   │
│   │   └── utils/                    # Utilities
│   │       ├── __init__.py
│   │       └── helpers.py
│   │
│   ├── tests/                        # Tests
│   │   ├── test_routes.py
│   │   └── test_services.py
│   │
│   ├── requirements.txt              # Python dependencies
│   ├── .env.example                  # Example env vars
│   ├── .env                          # Actual env vars (gitignored)
│   ├── .gitignore
│   └── README.md
│
├── docs/
│   └── architecture/
│       ├── ai-features-briefing.md
│       └── ai-features-technical-spec.md  # This document
│
└── README.md
```

---

## Environment Configuration

### Python Backend (.env)
```bash
# OpenAI
OPENAI_API_KEY=sk-your-key-here

# Pinecone
PINECONE_API_KEY=your-pinecone-key
PINECONE_ENVIRONMENT=us-east-1

# Optional: Firebase
FIREBASE_CREDENTIALS_PATH=./firebase-admin-key.json

# Server
HOST=0.0.0.0
PORT=8000
DEBUG=true
```

### iOS App (Config.xcconfig)
```
OPENAI_API_KEY = sk-your-key-here
AI_BACKEND_URL = http://localhost:8000/api/v1
```

---

## Security Considerations

### API Keys
1. **Never commit API keys to git**
   - Use `.env` files (gitignored)
   - Use `Config.xcconfig` (gitignored)
   - Provide `.example` versions for documentation

2. **Python Backend**
   - Load from environment variables
   - Validate on startup
   - Fail fast if missing

3. **iOS App**
   - Store in xcconfig
   - Read from Info.plist
   - Consider Keychain for production

### Data Privacy
1. **User Data to OpenAI**
   - Message text is sent to OpenAI API
   - Acknowledge in privacy policy
   - Acceptable for toy project

2. **Vector Storage**
   - Pinecone stores embeddings + metadata
   - Metadata includes message text
   - Free tier data is encrypted at rest

### Authentication (Post-MVP)
- Add API key validation in FastAPI middleware
- Use Firebase Auth tokens from iOS
- Validate user_id matches auth token

---

## Performance Considerations

### Latency Targets
- Message analysis: < 2 seconds
- Thread summarization: < 3 seconds
- Event search: < 500ms
- Agent response: < 5 seconds

### Optimization Strategies
1. **Caching**
   - Cache frequent vector searches (Redis - post-MVP)
   - Cache OpenAI responses for identical inputs
   
2. **Batch Processing**
   - Batch embed multiple messages
   - Use Pinecone batch upsert

3. **Async Operations**
   - Use FastAPI async endpoints
   - Concurrent OpenAI + Pinecone calls where possible

### Scalability (Post-MVP)
- Pinecone: Upgrade to paid tier for more vectors
- Backend: Add load balancer, multiple instances
- Caching: Add Redis for hot data

---

## Error Handling

### Python Backend
```python
# Standard error response
{
  "error": {
    "code": "OPENAI_API_ERROR",
    "message": "Failed to generate embedding",
    "details": "Rate limit exceeded"
  }
}
```

### iOS App
- Graceful degradation if backend unavailable
- Show cached data when possible
- User-friendly error messages
- Silent failures for non-critical AI features

### Retry Logic
- OpenAI API: 1 retry with exponential backoff
- Pinecone: 2 retries
- Network errors: Show error to user, allow retry

---

## Testing Strategy

### Unit Tests (Python)
- Test each service function
- Mock external APIs (OpenAI, Pinecone)
- Use pytest

### Integration Tests (Python)
- Test API endpoints
- Use test Pinecone index
- Mock OpenAI (or use low rate limit)

### Manual Testing (iOS)
- Test each AI feature end-to-end
- Test offline behavior
- Test error scenarios

---

## Deployment

### Python Backend Deployment (Render.com)

**Steps:**
1. Create account on Render.com
2. Connect GitHub repo
3. Create new Web Service
4. Configure:
   - Build command: `pip install -r requirements.txt`
   - Start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - Environment variables: Add OPENAI_API_KEY, PINECONE_API_KEY
5. Deploy

**Alternative:** Railway.app (similar process)

### iOS App
- Update `AI_BACKEND_URL` to production URL
- Build and test with production backend
- Deploy via TestFlight or direct install

---

## Monitoring & Debugging

### Logging
```python
# Python backend logging
import logging

logger = logging.getLogger(__name__)
logger.info("Message analyzed", extra={"user_id": user_id})
logger.error("OpenAI API failed", exc_info=True)
```

### Metrics to Track
- API endpoint latency
- OpenAI API call count & cost
- Pinecone query count
- Error rates per endpoint
- Active users

### Tools
- FastAPI built-in `/docs` (Swagger UI)
- Render.com logs (stdout/stderr)
- Pinecone dashboard (vector count, queries)
- OpenAI usage dashboard (token usage, cost)

---

## Implementation Phases

### Phase 1: Foundation (Day 1)
**Goal:** Working Python backend with basic endpoints

**Tasks:**
1. Create `python-backend/` directory structure
2. Install dependencies (`requirements.txt`)
3. Set up FastAPI app (`app/main.py`)
4. Configure environment variables (`.env`)
5. Initialize Pinecone client
6. Create health check endpoint
7. Test: `curl http://localhost:8000/health`

**Deliverables:**
- Python backend running locally
- Pinecone index created
- OpenAI API key configured

---

### Phase 2: Vector Store & Basic Analysis (Day 1-2)
**Goal:** Message analysis and vector storage working

**Tasks:**
1. Implement `VectorStoreService` with LangChain + Pinecone
2. Create `/analyze-message` endpoint
3. Generate embeddings and store in Pinecone
4. Test with sample messages
5. Create `AIBackendService.swift` in iOS app
6. Wire up iOS → Python backend
7. Test end-to-end: Send message → See AI prompt

**Deliverables:**
- Message analysis working
- Vectors stored in Pinecone
- iOS displays AI prompts

---

### Phase 3: Events, Reminders, Decisions (Day 2-3)
**Goal:** CRUD operations with vector search

**Tasks:**
1. Implement event search endpoint
2. Implement reminder CRUD endpoints
3. Implement decision CRUD endpoints
4. Add vector search for each
5. Create iOS services for each
6. Wire up UI for each feature
7. Test all flows

**Deliverables:**
- Event deduplication working
- Reminders created and searched
- Decisions logged and searched

---

### Phase 4: LangChain Agent (Day 3)
**Goal:** Proactive assistant with conflict detection

**Tasks:**
1. Implement `AgentService` with LangChain
2. Create agent tools (calendar check, search, suggest)
3. Create `/proactive-assist` endpoint
4. Test agent with sample scenarios
5. Update iOS to call agent
6. Show ⚠️ warnings in UI
7. Test conflict detection flow

**Deliverables:**
- LangChain agent working
- Conflict warnings shown in iOS

---

### Phase 5: Polish & Deploy (Day 4)
**Goal:** Production-ready system

**Tasks:**
1. Error handling for all endpoints
2. Add logging throughout
3. Write README for backend
4. Deploy to Render.com
5. Update iOS with production URL
6. End-to-end testing
7. Bug fixes
8. Performance optimization

**Deliverables:**
- Backend deployed
- iOS connected to production
- All features working end-to-end

---

## Success Criteria

### Functional
- ✅ All 6 AI features working
- ✅ iOS can call Python backend
- ✅ Vector search returns relevant results
- ✅ Decision detection uses lightweight RAG for context
- ✅ LangChain agent detects conflicts

### Non-Functional
- ✅ API latency < 3 seconds (p95)
- ✅ No API keys committed to git
- ✅ Backend deployed and accessible
- ✅ Error handling graceful
- ✅ Code documented

---

## Open Questions / Future Considerations

1. **Firestore Security Rules:**
   - Need to update rules for new collections (events, reminders, decisions)
   - Should Python backend have admin access?

2. **Notification Scheduling:**
   - iOS local notifications for reminders?
   - Or push notifications from backend?

3. **Cross-Device Sync:**
   - If user adds iPad, reminders/decisions should sync
   - Consider moving to Firestore entirely

4. **Cost Monitoring:**
   - Set up OpenAI usage alerts?
   - Track Pinecone vector count?

5. **Advanced RAG:**
   - Experiment with different chunk sizes
   - Try hybrid search (keyword + vector)

---

## Recent Updates (January 2025)

### AI Analysis System Improvements

**Date:** January 27, 2025  
**Changes:** Major refactoring of AI analysis system for improved reliability and performance

#### Key Changes Made:

1. **Function Calling Implementation**
   - **Before:** Direct JSON generation from LLM (error-prone)
   - **After:** OpenAI function calling with structured schema
   - **Benefit:** More reliable, type-safe responses from AI

2. **Unified Event Handling**
   - **Before:** Two separate event creation flows (calendar vs invitation)
   - **After:** Single unified flow using `EventInvitationModal`
   - **Benefit:** Consistent UX, easier maintenance

3. **Enhanced Date Parsing**
   - **Added:** `dateparser` library integration for all detection types
   - **Added:** Time acronym expansion (EOD, EOB, etc.)
   - **Benefit:** Better AI understanding of temporal expressions

4. **Performance Optimization**
   - **Model Change:** `gpt-5-nano` → `gpt-3.5-turbo`
   - **Response Time:** 22+ seconds → ~3 seconds
   - **Benefit:** Much faster user experience

5. **Field Mapping Fixes**
   - **Issue:** iOS camelCase vs Backend snake_case mismatch
   - **Solution:** Added `CodingKeys` to all iOS models
   - **Benefit:** Reliable data parsing between frontend/backend

6. **UI Consolidation**
   - **Before:** Three separate toolbar icons (Calendar, Decisions, Reminders)
   - **After:** Single menu with three horizontal dots
   - **Benefit:** Cleaner interface, more scalable

#### Technical Implementation Details:

**Backend Changes:**
- `openai_service.py`: Implemented function calling with structured schema
- `analysis.py`: Enhanced with acronym expansion and date parsing
- `responses.py`: Updated models with `is_invitation` field

**iOS Changes:**
- `AIBackendService.swift`: Added `CodingKeys` for all models
- `ChatView.swift`: Unified event creation UI
- `EventInvitationModal.swift`: Enhanced to handle both calendar and invitation flows
- `ChatViewModel.swift`: Added message status caching

**API Response Format:**
```json
{
  "message_id": "string",
  "calendar": {
    "detected": boolean,
    "title": "string|null",
    "date": "string|null",
    "time": "string|null", 
    "location": "string|null",
    "is_invitation": boolean
  },
  "reminder": {
    "detected": boolean,
    "title": "string|null",
    "due_date": "string|null"
  },
  "decision": {
    "detected": boolean,
    "text": "string|null"
  },
  "rsvp": {
    "detected": boolean,
    "status": "string|null",
    "event_reference": "string|null"
  },
  "priority": {
    "detected": boolean,
    "level": "string|null",
    "reason": "string|null"
  },
  "conflict": {
    "detected": boolean,
    "conflicting_events": ["string"]
  }
}
```

#### Testing Results:
- ✅ Reminder detection: "I'll finish the presentation by noon tomorrow"
- ✅ Event detection: "Let's meet Friday at 3pm for coffee"
- ✅ Response time: ~3 seconds (down from 22+ seconds)
- ✅ UI prompts: Orange "Set reminder" and blue "Add to calendar" buttons working

---

## References

### Documentation
- **LangChain:** https://python.langchain.com/docs/
- **Pinecone:** https://docs.pinecone.io/
- **OpenAI API:** https://platform.openai.com/docs/
- **FastAPI:** https://fastapi.tiangolo.com/

### Code Examples
- LangChain RAG: https://python.langchain.com/docs/use_cases/question_answering/
- LangChain Agents: https://python.langchain.com/docs/modules/agents/
- Pinecone + LangChain: https://docs.pinecone.io/integrations/langchain

---

## Approval

This technical specification has been reviewed and approved by:

**Architect:** ✅ Approved (Oct 22, 2025)

**Next Step:** Hand off to @dev for implementation

---

**End of Technical Specification**

