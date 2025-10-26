"""
Event Routes
Handles event creation, indexing and conflict detection
"""
from fastapi import APIRouter, HTTPException
from typing import Dict, Any
from app.services.event_indexing_service import get_event_indexing_service
from app.models.requests import EventCreateRequest
from app.models.responses import EventCreateResponse

router = APIRouter()


@router.post("/events/create", response_model=EventCreateResponse)
async def create_event(request: EventCreateRequest):
    """
    Create a new event with deduplication check using vector similarity.
    
    Before creating, checks if similar event exists (similarity > 0.75).
    If found, suggests linking to existing event.
    Otherwise, creates new event and stores embedding for future deduplication.
    """
    import time
    route_start = time.time()
    
    try:
        # Get services
        import uuid
        event_service = get_event_indexing_service()
        
        # Create search query for deduplication (title + date)
        query = f"{request.title} {request.date}"
        
        # Create event data first - ensure no null values
        event_id = f"evt_{uuid.uuid4().hex[:12]}"
        event_data = {
            "id": event_id,
            "user_id": request.user_id or "",
            "title": request.title or "",
            "date": request.date or "",
            "startTime": request.startTime or "",
            "endTime": request.endTime or "",
            "duration": request.duration or 0,
            "location": request.location or "",
            "conversation_id": request.conversation_id or "",
            "message_id": request.message_id or ""
        }
        
        # Check for duplicates and index in one operation
        duplicate_check = event_service.check_duplicates_and_index(event_data, query)
        
        if duplicate_check["is_duplicate"]:
            # Found potential duplicate - suggest linking to existing event
            return EventCreateResponse(
                success=False,
                event_id=None,
                suggest_link=True,
                similar_event={
                    "event_id": duplicate_check["similar_event"]["event_id"],
                    "title": duplicate_check["similar_event"]["title"],
                    "date": duplicate_check["similar_event"]["date"],
                    "similarity": duplicate_check["similar_event"]["similarity_score"]
                },
                message="Similar event found. Link to existing event?"
            )
        
        # Event was indexed successfully
        if not duplicate_check["indexed"]:
            raise HTTPException(status_code=500, detail="Failed to index event")
        
        total_route_time = time.time() - route_start
        print(f"🚀 Total route time: {total_route_time:.3f}s")
        
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


@router.post("/events/index")
async def index_event(event: Dict[str, Any]):
    """
    Index an event in Pinecone for conflict detection
    
    Args:
        event: Event dictionary with id, title, date, startTime, endTime, etc.
        
    Returns:
        Success status
    """
    try:
        event_service = get_event_indexing_service()
        success = event_service.index_event(event)
        
        if success:
            return {"status": "success", "message": "Event indexed successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to index event")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to index event: {str(e)}")


@router.put("/events/{event_id}/index")
async def update_event(event_id: str, event: Dict[str, Any]):
    """
    Update an indexed event in Pinecone
    
    Args:
        event_id: ID of event to update
        event: Updated event dictionary
        
    Returns:
        Success status
    """
    try:
        # Ensure event has the correct ID
        event["id"] = event_id
        
        event_service = get_event_indexing_service()
        success = event_service.update_event(event)
        
        if success:
            return {"status": "success", "message": "Event updated successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to update event")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update event: {str(e)}")


@router.delete("/events/{event_id}/index")
async def delete_event(event_id: str):
    """
    Delete an event from Pinecone index
    
    Args:
        event_id: ID of event to delete
        
    Returns:
        Success status
    """
    try:
        event_service = get_event_indexing_service()
        success = event_service.delete_event(event_id)
        
        if success:
            return {"status": "success", "message": "Event deleted successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to delete event")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete event: {str(e)}")


@router.post("/events/search-conflicts")
async def search_conflicts(request: Dict[str, Any]):
    """
    Search for conflicts with a detected event
    
    Args:
        request: Dictionary with detected_event and user_id
        
    Returns:
        Conflict analysis results
    """
    try:
        detected_event = request.get("detected_event")
        user_id = request.get("user_id")
        
        if not detected_event or not user_id:
            raise HTTPException(status_code=400, detail="detected_event and user_id are required")
        
        event_service = get_event_indexing_service()
        results = event_service.search_conflicts(detected_event, user_id)
        
        return results
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search conflicts: {str(e)}")


@router.post("/events/search-similar")
async def search_similar_events(request: Dict[str, Any]):
    """
    Search for similar events
    
    Args:
        request: Dictionary with event and user_id
        
    Returns:
        List of similar events
    """
    try:
        event = request.get("event")
        user_id = request.get("user_id")
        limit = request.get("limit", 5)
        
        if not event or not user_id:
            raise HTTPException(status_code=400, detail="event and user_id are required")
        
        event_service = get_event_indexing_service()
        similar_events = event_service.search_similar_events(event, user_id, limit)
        
        return {"similar_events": similar_events}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search similar events: {str(e)}")