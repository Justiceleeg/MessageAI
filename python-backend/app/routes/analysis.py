"""
Analysis Routes
Handles comprehensive message analysis including event detection, reminders, decisions, etc.
"""
from fastapi import APIRouter, HTTPException
from app.models.requests import MessageAnalysisRequest
from app.models.responses import MessageAnalysisResponse
from app.services.openai_service import get_openai_service
from app.services.vector_store import get_vector_store

router = APIRouter()


@router.post("/analyze-message", response_model=MessageAnalysisResponse)
async def analyze_message(request: MessageAnalysisRequest):
    """
    Comprehensively analyze a message for events, reminders, decisions, RSVP, priority, and conflicts.
    This is the core endpoint that powers all AI-powered messaging features.
    """
    try:
        # Get services
        openai_service = get_openai_service()
        vector_store = get_vector_store()
        
        # Analyze message with GPT-4o-mini
        analysis = openai_service.analyze_message_comprehensive(
            text=request.text,
            user_calendar=request.user_calendar
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
        return MessageAnalysisResponse(
            message_id=request.message_id,
            calendar=analysis["calendar"],
            reminder=analysis["reminder"],
            decision=analysis["decision"],
            rsvp=analysis["rsvp"],
            priority=analysis["priority"],
            conflict=analysis["conflict"]
        )
        
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

