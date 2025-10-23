# AI Features Overview - Events, Reminders, and Decisions

**Purpose:** Clarify the distinctions between the three core AI-extracted features in Epic 5

**Last Updated:** October 23, 2025

---

## 🎯 **Quick Reference**

| Feature | Type | When? | Action? | Notification? | Who? |
|---------|------|-------|---------|---------------|------|
| **📅 Event** | Happening | Specific time | No | No | Multiple people |
| **⏰ Reminder** | Task | Deadline | Yes (you do it) | Yes | Personal |
| **✅ Decision** | Agreement | N/A | No | No | Group |

---

## 📅 **Events** (Story 5.1)

### What Is It?
A **social gathering, meeting, or appointment** - something that happens at a specific date/time.

### AI Detection Patterns:
- Date + time: "Friday at 7pm", "tomorrow at 3pm"
- Social language: "let's meet", "dinner", "party", "appointment"  
- Location: "at Coffee Place", "my house", "downtown"

### Key Characteristics:
- ✅ Specific date AND time
- ✅ Multiple people involved (attendees)
- ✅ Location-based
- ✅ **Something happening** (not something to do)
- ✅ Shows on calendar grid

### Examples:
```
✅ "Dinner at Italian restaurant Friday 7pm"
✅ "Coffee meeting tomorrow at 3pm"  
✅ "David's birthday party Saturday at 8pm"
✅ "Doctor appointment next Tuesday at 10am"
```

### What Gets Created:
- Calendar entry on specific date
- Attendee list (for RSVP tracking)
- Location pin
- Link to source message

### User Value:
- Visual calendar showing all upcoming events
- Never miss social commitments
- See who's attending (RSVP status)
- Quick reference: "What am I doing Friday?"

---

## ⏰ **Reminders** (Story 5.5)

### What Is It?
A **personal task or commitment** - something YOU need to DO by a certain time.

### AI Detection Patterns:
- Commitment verbs: "I'll", "I need to", "remind me to"
- Action verbs: "send", "call", "buy", "book", "review", "pick up"
- Deadline language: "by tomorrow", "before Friday", "this afternoon"

### Key Characteristics:
- ✅ Action required by you
- ✅ Due date/deadline (not exact time)
- ✅ Personal (not shared)
- ✅ Triggers iOS notification
- ✅ Can mark complete
- ✅ Shows in reminders list

### Examples:
```
✅ "I'll send the documents by 5pm tomorrow"
✅ "I need to call the dentist this afternoon"
✅ "Remind me to buy groceries after work"
✅ "I'll pick up the decorations Friday morning"
```

### What Gets Created:
- Task in reminders list
- iOS notification at due time
- Completion checkbox
- Link to source message

### User Value:
- Never forget commitments made in chats
- Get notified at the right time
- Track personal accountability
- Mark tasks complete

---

## ✅ **Decisions** (Story 5.2)

### What Is It?
A **group agreement or conclusion** - what was decided/agreed upon by the group.

### AI Detection Patterns:
- Agreement language: "let's do", "we'll go with", "we decided"
- Confirmation: "okay", "yeah", "sounds good", "that works"
- Consensus: "we're going to", "we should"

### Key Characteristics:
- ✅ Group agreement (we/us)
- ✅ Past-tense or confirmed
- ✅ Reference/memory tool
- ✅ No action required
- ✅ No notification
- ✅ Shows in decisions list

### Examples:
```
✅ "Let's go to the Italian restaurant for dinner"
✅ "We decided on the blue design"
✅ "Okay, we'll meet at Coffee Place"
✅ "We're going with Option A"
```

### What Gets Created:
- Searchable log entry
- Reference in decisions list
- Link to source message

### User Value:
- Group memory: "What did we decide?"
- Prevents confusion in group chats
- Searchable across all conversations
- Quick consensus reference

---

## 🔄 **How They Work Together**

### Example Conversation: Planning Dinner

```
Alice: "Want to get dinner Friday?"
You: "Sure! Where should we go?"
Bob: "How about Italian Place downtown?"
You: "Yeah, let's do Italian Place at 7pm Friday"
     ↓
     📅 EVENT CREATED:
        "Dinner at Italian Place"
        Friday 7pm, downtown
        Attendees: You, Alice, Bob
        
     ✅ DECISION LOGGED:
        "Going to Italian Place for dinner Friday"
     
Alice: "Perfect! Can someone make a reservation?"
You: "I'll book it tomorrow afternoon"
     ↓
     ⏰ REMINDER CREATED:
        "Book reservation at Italian Place"
        Due: Tomorrow afternoon
        Notification: Tomorrow 2pm
```

**Result:**
- **1 Event:** Shows on calendar Friday 7pm
- **1 Decision:** Searchable log of what was agreed
- **1 Reminder:** Your task with notification

**On Friday:**
- Calendar shows: "Dinner at Italian Place 7pm"
- Decisions shows: "Going to Italian Place" (in case you forgot)
- Reminder: ✅ Completed (you booked it yesterday)

---

## 💡 **When to Use Each**

### Use **Events** when:
- Something is happening at a specific date/time
- Multiple people are involved
- You need calendar visualization
- Example: Meetings, dinners, parties, appointments

### Use **Reminders** when:
- YOU need to DO something
- There's a deadline or due date
- You need a notification
- Example: Tasks, to-dos, commitments, errands

### Use **Decisions** when:
- Group needs to remember what was agreed
- Multiple options were discussed
- Avoiding "wait, what did we decide?" moments
- Example: Plans, choices, agreements, consensus

---

## 🎨 **Visual Comparison**

### In Chat (All Three on Same Message):

```
┌─────────────────────────────────────────┐
│ Me: Yeah, let's do Italian Place at     │
│     7pm Friday. I'll book it tomorrow.  │
│                                         │
│     ┌─────────────────────────┐        │
│     │ 📅 Add to calendar?     │ ← Event │
│     └─────────────────────────┘        │
│     ┌─────────────────────────┐        │
│     │ ✅ Confirm decision?    │ ← Decision │
│     └─────────────────────────┘        │
│     ┌─────────────────────────┐        │
│     │ ⏰ Set reminder?        │ ← Reminder │
│     └─────────────────────────┘        │
└─────────────────────────────────────────┘
```

### In Calendar View:

```
┌─────────────────────────────────┐
│         FRIDAY OCT 27           │
├─────────────────────────────────┤
│ 📅 3pm  Coffee with Alice       │ ← Event
│ 📅 7pm  Dinner at Italian Place │ ← Event
└─────────────────────────────────┘

┌─────────────────────────────────┐
│          REMINDERS              │
├─────────────────────────────────┤
│ TODAY                           │
│ ⏰ Book restaurant (2pm)        │ ← Reminder
│ ⏰ Send documents (5pm)         │ ← Reminder
│                                 │
│ TOMORROW                        │
│ ⏰ Buy groceries                │ ← Reminder
└─────────────────────────────────┘

┌─────────────────────────────────┐
│          DECISIONS              │
├─────────────────────────────────┤
│ Oct 27 | Dinner Plans           │
│ "Going to Italian Place         │ ← Decision
│  for dinner Friday"             │
│                                 │
│ Oct 26 | Project Design         │
│ "Using blue color scheme"       │ ← Decision
└─────────────────────────────────┘
```

---

## 🧠 **Mental Model**

**Think of it like a personal assistant helping with:**

1. **📅 Events = Calendar/Scheduling**
   - "When are things happening?"
   - Shows up on calendar
   - Time-bound, multi-person

2. **⏰ Reminders = Task Manager**
   - "What do I need to do?"
   - Shows up in to-do list
   - Action-oriented, personal

3. **✅ Decisions = Meeting Notes**
   - "What did we agree on?"
   - Shows up in searchable log
   - Reference, group memory

---

## 🔍 **Disambiguation Examples**

### Tricky: "I'll meet you at 3pm Friday"

**Could be:**
- 📅 Event (meeting at specific time) ✅
- ⏰ Reminder (I need to show up) ✅

**AI Creates:**
- Event: "Meeting at 3pm Friday" (calendar entry)
- Reminder: "Meet at 3pm Friday" (personal notification)

**Why both?** Different purposes:
- Event = Calendar visualization + attendees
- Reminder = Personal notification so you don't forget

---

### Tricky: "Let's book the restaurant for Friday"

**Could be:**
- ✅ Decision (agreeing to book it) 
- ⏰ Reminder (if YOU'RE booking it)

**Depends on:**
```
"Let's book..." (we should) → Decision only
"I'll book..." (I'm doing it) → Reminder + Decision
```

---

### Tricky: "Meeting tomorrow at 2pm to discuss the contract"

**Creates:**
- 📅 Event: "Meeting at 2pm" (on calendar)
- ✅ Decision: "Meeting tomorrow to discuss contract" (reference)

**Why both?**
- Event = Calendar entry with time
- Decision = What the meeting is about (searchable)

---

## 🚀 **User Journey: Complete Example**

### Monday Morning Chat:
```
Team: "We need to finalize the website design"
You: "How about we meet Friday at 2pm?"
Boss: "Works for me"
You: "Great, let's do it. I'll send the mockups by Thursday"
```

**AI Creates:**
- 📅 **Event:** "Design meeting Friday 2pm"
- ✅ **Decision:** "Meeting Friday at 2pm to finalize design"  
- ⏰ **Reminder:** "Send mockups" (Due: Thursday)

### Thursday:
- 🔔 **Notification:** "Send mockups by end of day"
- You send mockups → Mark reminder complete ✅

### Friday at 1:30pm:
- Check calendar → "Oh! Design meeting at 2pm"
- Check decisions → "Right, finalizing the design"
- All prepared!

---

## 📱 **Implementation Notes**

### Story Dependencies:
- **5.0.5:** Data models (Event, Reminder, Decision)
- **5.1:** Event extraction and creation
- **5.1.5:** Calendar UI (displays events and reminders)
- **5.2:** Decision detection and tracking
- **5.5:** Reminder extraction and notifications

### Shared Infrastructure:
- All use Pinecone for vector search
- All use Firestore for persistence
- All link back to source messages
- All use GPT-4o-mini for detection

### Key Differences in Implementation:
```
Events:    date/time required, attendee tracking, calendar display
Reminders: deadline required, notification system, completion status
Decisions: context-aware (RAG), no time component, search-focused
```

---

## ❓ **FAQ**

### Q: Can one message create all three?
**A:** Yes! Example: "Let's meet at Coffee Place at 3pm Friday. I'll bring the documents."
- Event: Meeting at 3pm Friday
- Decision: Meeting at Coffee Place
- Reminder: Bring documents

### Q: What if I just want to track a decision without creating an event?
**A:** Decision-only happens when there's no specific time. Example: "Let's go with Option A" → Only decision, no event.

### Q: Can reminders be shared with others?
**A:** No, reminders are personal. For shared tasks, consider creating an event with attendees instead.

### Q: Do decisions require consensus?
**A:** No, but they should represent agreement or conclusion. Even "I decided to X" can be logged as a decision for later reference.

### Q: Can I manually create these?
**A:** Future enhancement. MVP is AI-detection only, but manual creation is in backlog.

---

## 🏗️ **Technical References**

- **Events:** `docs/stories/5.1.story.md`
- **Reminders:** `docs/stories/5.5.story.md`
- **Decisions:** `docs/stories/5.2.story.md`
- **Data Models:** `docs/stories/5.0.5.story.md`
- **Calendar UI:** `docs/stories/5.1.5.story.md`

---

**This document serves as the single source of truth for understanding the distinction between Events, Reminders, and Decisions in MessageAI.**

**Last Updated:** October 23, 2025  
**Architect:** Winston 🏗️

