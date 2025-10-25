"""
Analysis Routes
Handles comprehensive message analysis including event detection, reminders, decisions, etc.
"""
from fastapi import APIRouter, HTTPException
from app.models.requests import MessageAnalysisRequest
from app.models.responses import MessageAnalysisResponse, CalendarDetection, ReminderDetection, DecisionDetection, RSVPDetection, PriorityDetection, ConflictDetection
from app.services.openai_service import get_openai_service
from app.services.vector_store import get_vector_store

router = APIRouter()


@router.post("/analyze-message", response_model=MessageAnalysisResponse)
async def analyze_message(request: MessageAnalysisRequest):
    """
    Comprehensively analyze a message for events, reminders, decisions, RSVP, priority, and conflicts.
    This is the core endpoint that powers all AI-powered messaging features.
    
    Story 5.2: Implements lightweight RAG for context-aware decision detection.
    """
    try:
        # Get services
        openai_service = get_openai_service()
        vector_store = get_vector_store()
        
        # Step 1: Retrieve conversation context for RAG (Story 5.2)
        # This enables context-aware decision detection
        conversation_context = []
        try:
            conversation_context = vector_store.search_similar_messages(
                query=request.text,
                k=5,
                filter_dict={"conversation_id": request.conversation_id}
            )
        except Exception as e:
            print(f"⚠️ Failed to retrieve context: {e}")
            # Continue without context - analysis will still work
        
        # Step 2: Pre-process text to expand time acronyms
        expanded_text = openai_service._expand_time_acronyms(request.text)
        
        # Step 3: Analyze message with GPT-4o-mini (with context if available)
        analysis = openai_service.analyze_message_comprehensive(
            text=expanded_text,  # Use expanded text for better AI understanding
            message_timestamp=request.timestamp,  # Pass message timestamp for date calculations
            user_calendar=request.user_calendar,
            conversation_context=conversation_context  # RAG context
        )
        
        # Generate embedding for the message
        embedding = openai_service.generate_embedding(request.text)
        
        # Store message embedding in vector store for future semantic search
        metadata = {
            "user_id": request.user_id,
            "conversation_id": request.conversation_id,
            "has_calendar": analysis["calendar"]["detected"],
            "has_reminder": analysis["reminder"]["detected"],
            "has_decision": analysis["decision"]["detected"]
        }
        
        vector_store.add_message(
            message_id=request.message_id,
            text=request.text,
            metadata=metadata
        )
        
        # Build response
        response = MessageAnalysisResponse(
            message_id=request.message_id,
            calendar=CalendarDetection(
                detected=analysis["calendar"]["detected"],
                title=analysis["calendar"]["title"],
                date=analysis["calendar"].get("date"),  # Use the parsed date
                startTime=analysis["calendar"].get("startTime"),
                endTime=analysis["calendar"].get("endTime"),
                duration=analysis["calendar"].get("duration"),
                location=analysis["calendar"]["location"],
                is_invitation=analysis["calendar"].get("is_invitation", False)
            ),
            reminder=ReminderDetection(
                detected=analysis["reminder"]["detected"],
                title=analysis["reminder"]["title"],
                due_date=analysis["reminder"].get("due_date")  # Use the parsed due_date
            ),
            decision=DecisionDetection(
                detected=analysis["decision"]["detected"],
                text=analysis["decision"]["text"]
            ),
            rsvp=RSVPDetection(
                detected=analysis["rsvp"]["detected"],
                status=analysis["rsvp"]["status"],
                event_reference=analysis["rsvp"]["event_reference"]
            ),
            priority=PriorityDetection(
                detected=analysis["priority"]["detected"],
                level=analysis["priority"]["level"],
                reason=analysis["priority"]["reason"]
            ),
            conflict=ConflictDetection(
                detected=analysis["conflict"]["detected"],
                conflicting_events=analysis["conflict"]["conflicting_events"]
            )
        )
        
        
        
        return response
        
    except Exception as e:
        print(f"Error analyzing message: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to analyze message: {str(e)}")


@router.post("/analyze/sentiment")
async def analyze_sentiment():
    """
    Analyze sentiment of a message or conversation
    TODO: Implement in future story
    """
    return {
        "status": "not_implemented",
        "message": "Sentiment analysis will be implemented in a future story"
    }


@router.post("/analyze/tone")
async def analyze_tone():
    """
    Detect tone of messages
    TODO: Implement in future story
    """
    return {
        "status": "not_implemented",
        "message": "Tone analysis will be implemented in a future story"
    }

