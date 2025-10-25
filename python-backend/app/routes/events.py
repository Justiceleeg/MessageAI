"""
Events Routes
Handles event creation, search, and deduplication
"""
from fastapi import APIRouter, HTTPException
from app.models.requests import EventCreateRequest, EventSearchRequest
from app.models.responses import EventCreateResponse, EventSearchResponse, EventSearchResult
from app.services.openai_service import get_openai_service
from app.services.vector_store import get_vector_store
import uuid

router = APIRouter()


@router.post("/events/create", response_model=EventCreateResponse)
async def create_event(request: EventCreateRequest):
    """
    Create a new event with deduplication check using vector similarity.
    
    Before creating, checks if similar event exists (similarity > 0.85).
    If found, suggests linking to existing event.
    Otherwise, creates new event and stores embedding for future deduplication.
    """
    try:
        # Get services
        openai_service = get_openai_service()
        vector_store = get_vector_store()
        
        # Create search query for deduplication (title + date)
        query = f"{request.title} {request.date}"
        
        # Search for similar events using vector similarity
        # Check for similar events by the same creator (for multi-chat linking)
        similar_events = vector_store.search_similar_events(
            query=query,
            k=3,
            filter_dict={"user_id": request.user_id}  # Only same creator's events
        )
        
        # Check for high similarity (multi-chat linking threshold)
        # Lower threshold for multi-chat linking since events might be worded differently
        SIMILARITY_THRESHOLD = 0.75
        for event in similar_events:
            similarity = event.get("similarity", 0.0)
            # Note: Pinecone similarity_search_with_score returns values where higher is MORE similar
            # We need to check if it's above threshold
            if similarity >= SIMILARITY_THRESHOLD:
                # Found potential duplicate - suggest linking to existing event
                return EventCreateResponse(
                    success=False,
                    event_id=None,
                    suggest_link=True,
                    similar_event={
                        "event_id": event["metadata"].get("event_id"),
                        "title": event["metadata"].get("title"),
                        "date": event["metadata"].get("date"),
                        "similarity": similarity
                    },
                    message="Similar event found. Link to existing event?"
                )
        
        # No duplicates found - create new event
        event_id = f"evt_{uuid.uuid4().hex[:12]}"
        
        # Store event embedding in vector store
        event_metadata = {
            "event_id": event_id,
            "title": request.title,
            "date": request.date,
            "user_id": request.user_id,
            "conversation_id": request.conversation_id,
            "message_id": request.message_id
        }
        
        # Only add optional fields if they have values
        if request.time is not None:
            event_metadata["time"] = request.time
        if request.location is not None:
            event_metadata["location"] = request.location
        
        vector_store.add_event(
            event_id=event_id,
            text=query,
            metadata=event_metadata
        )
        
        # Note: Message metadata update is handled by the iOS client
        # The client will update the message with invitation metadata after event creation
        
        return EventCreateResponse(
            success=True,
            event_id=event_id,
            suggest_link=False,
            similar_event=None,
            message="Event created successfully"
        )
        
    except Exception as e:
        print(f"Error creating event: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to create event: {str(e)}")


@router.post("/events/search", response_model=EventSearchResponse)
async def search_events(request: EventSearchRequest):
    """
    Search for similar events using semantic search.
    Used for deduplication and event discovery.
    """
    try:
        vector_store = get_vector_store()
        
        # Search for similar events
        similar_events = vector_store.search_similar_events(
            query=request.query,
            k=request.k,
            filter_dict={"user_id": request.user_id}
        )
        
        # Build response
        results = [
            EventSearchResult(
                event_id=event["metadata"].get("event_id", ""),
                title=event["metadata"].get("title", ""),
                date=event["metadata"].get("date", ""),
                similarity=event.get("similarity", 0.0)
            )
            for event in similar_events
        ]
        
        return EventSearchResponse(results=results)
        
    except Exception as e:
        print(f"Error searching events: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to search events: {str(e)}")


@router.post("/events/link")
async def link_event_to_chat(event_id: str, conversation_id: str, user_id: str):
    """
    Link an existing event to a new chat conversation.
    Used for multi-chat event linking (Story 5.4).
    """
    try:
        # This endpoint would typically update Firestore to add the conversation
        # to the event's invitations map, but since this is a backend-only service,
        # the actual Firestore update will be handled by the iOS client.
        
        # For now, return success - the iOS client will handle the Firestore update
        return {
            "success": True,
            "event_id": event_id,
            "conversation_id": conversation_id,
            "message": "Event linking request processed. iOS client will update Firestore."
        }
        
    except Exception as e:
        print(f"Error linking event: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to link event: {str(e)}")


@router.post("/events/detect")
async def detect_events():
    """
    Legacy endpoint - now replaced by /analyze-message
    """
    return {
        "status": "deprecated",
        "message": "Use /analyze-message endpoint instead for event detection"
    }

