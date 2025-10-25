"""
Reminders Routes
Handles reminder vector storage and semantic search
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.services.openai_service import get_openai_service
from app.services.vector_store import get_vector_store

router = APIRouter()


class ReminderVectorRequest(BaseModel):
    """Request model for storing reminder vector"""
    reminder_id: str = Field(..., description="Unique reminder identifier")
    title: str = Field(..., description="Reminder title")
    user_id: str = Field(..., description="User ID")
    conversation_id: str = Field(..., description="Conversation ID")
    source_message_id: str = Field(..., description="Source message ID")
    due_date: str = Field(..., description="Due date in ISO 8601 format")
    timestamp: str = Field(..., description="Creation timestamp in ISO 8601 format")


class ReminderVectorResponse(BaseModel):
    """Response model for reminder vector operations"""
    success: bool = Field(..., description="Operation success status")
    reminder_id: Optional[str] = Field(None, description="Reminder ID")
    message: str = Field(..., description="Status message")


class ReminderSearchRequest(BaseModel):
    """Request model for reminder search"""
    query: str = Field(..., description="Search query")
    user_id: str = Field(..., description="User ID")
    limit: int = Field(default=10, description="Maximum number of results")


class ReminderSearchResult(BaseModel):
    """Single reminder search result"""
    reminder_id: str = Field(..., description="Reminder ID")
    title: str = Field(..., description="Reminder title")
    due_date: str = Field(..., description="Due date")
    conversation_id: str = Field(..., description="Conversation ID")
    source_message_id: str = Field(..., description="Source message ID")
    similarity: float = Field(..., ge=0.0, le=1.0, description="Similarity score")


class ReminderSearchResponse(BaseModel):
    """Response model for reminder search"""
    results: list[ReminderSearchResult] = Field(default_factory=list)


@router.post("/reminders/vector", response_model=ReminderVectorResponse)
async def store_reminder_vector(request: ReminderVectorRequest):
    """
    Store reminder vector embedding in Pinecone for semantic search
    
    Story 5.5: Implements vector storage for reminders following Events/Decisions pattern
    """
    try:
        # Get services
        openai_service = get_openai_service()
        vector_store = get_vector_store()
        
        # Generate embedding for reminder title
        embedding = openai_service.generate_embedding(request.title)
        
        # Store in Pinecone with metadata
        metadata = {
            "reminder_id": request.reminder_id,
            "user_id": request.user_id,
            "conversation_id": request.conversation_id,
            "source_message_id": request.source_message_id,
            "due_date": request.due_date,
            "timestamp": request.timestamp,
            "type": "reminder"
        }
        
        vector_store.add_vector(
            vector_id=request.reminder_id,
            embedding=embedding,
            metadata=metadata,
            namespace="reminders"
        )
        
        return ReminderVectorResponse(
            success=True,
            reminder_id=request.reminder_id,
            message="Reminder vector stored successfully"
        )
        
    except Exception as e:
        print(f"Error storing reminder vector: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to store reminder vector: {str(e)}")


@router.get("/reminders/search", response_model=ReminderSearchResponse)
async def search_reminders(query: str, user_id: str, limit: int = 10):
    """
    Search reminders using semantic vector search
    
    Story 5.5: Implements semantic reminder search across all conversations
    """
    try:
        # Get services
        openai_service = get_openai_service()
        vector_store = get_vector_store()
        
        # Generate embedding for search query
        query_embedding = openai_service.generate_embedding(query)
        
        # Search in Pinecone
        search_results = vector_store.search_vectors(
            query_embedding=query_embedding,
            namespace="reminders",
            filter_dict={"user_id": user_id},
            top_k=limit
        )
        
        # Convert results to response format
        results = []
        for result in search_results:
            results.append(ReminderSearchResult(
                reminder_id=result.metadata["reminder_id"],
                title=result.metadata.get("title", ""),
                due_date=result.metadata["due_date"],
                conversation_id=result.metadata["conversation_id"],
                source_message_id=result.metadata["source_message_id"],
                similarity=result.score
            ))
        
        return ReminderSearchResponse(results=results)
        
    except Exception as e:
        print(f"Error searching reminders: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to search reminders: {str(e)}")


@router.delete("/reminders/vector/{reminder_id}")
async def delete_reminder_vector(reminder_id: str):
    """
    Delete reminder vector from Pinecone
    
    Story 5.5: Implements reminder vector deletion
    """
    try:
        # Get vector store
        vector_store = get_vector_store()
        
        # Delete from Pinecone
        vector_store.delete_vector(
            vector_id=reminder_id,
            namespace="reminders"
        )
        
        return ReminderVectorResponse(
            success=True,
            reminder_id=reminder_id,
            message="Reminder vector deleted successfully"
        )
        
    except Exception as e:
        print(f"Error deleting reminder vector: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete reminder vector: {str(e)}")


@router.post("/reminders/suggest")
async def suggest_reminders():
    """
    Suggest reminders based on message content
    TODO: Implement in Story 5.4
    """
    return {
        "status": "not_implemented",
        "message": "Reminder suggestions will be implemented in Story 5.4"
    }



