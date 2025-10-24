"""
Decisions Routes
Handles decision vector storage and semantic search (Story 5.2)

NOTE: Firestore storage happens on iOS client (DecisionService).
Backend only handles Pinecone vector embeddings for semantic search.
"""
from fastapi import APIRouter, HTTPException
from app.models.requests import DecisionCreateRequest, DecisionSearchRequest
from app.models.responses import (
    DecisionCreateResponse,
    DecisionSearchResponse,
    DecisionSearchResult
)
from app.services.vector_store import get_vector_store

router = APIRouter()


@router.post("/decisions/vector", response_model=DecisionCreateResponse)
async def store_decision_vector(request: DecisionCreateRequest):
    """
    Store decision embedding in Pinecone for semantic search (Story 5.2)
    
    NOTE: Firestore storage happens on iOS client.
    This endpoint only stores the vector embedding for search.
    """
    try:
        vector_store = get_vector_store()
        
        # Store in Pinecone for semantic search
        vector_store.add_decision(
            decision_id=request.decisionId,
            text=request.text,
            metadata={
                'decision_id': request.decisionId,
                'user_id': request.userId,
                'conversation_id': request.conversationId,
                'message_id': request.messageId,
                'timestamp': request.timestamp
            }
        )
        
        return DecisionCreateResponse(
            success=True,
            decisionId=request.decisionId,
            message="Decision vector stored successfully"
        )
        
    except Exception as e:
        print(f"❌ Error storing decision vector: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/decisions/search", response_model=DecisionSearchResponse)
async def search_decisions(
    user_id: str,
    query: str,
    conversation_id: str = None,
    k: int = 10
):
    """
    Search decisions semantically using Pinecone (Story 5.2)
    """
    try:
        vector_store = get_vector_store()
        
        # Build filter
        filter_dict = {'user_id': user_id}
        if conversation_id:
            filter_dict['conversation_id'] = conversation_id
        
        # Search using Pinecone
        results = vector_store.search_similar_decisions(
            query=query,
            k=k,
            filter_dict=filter_dict
        )
        
        # Convert to response format
        search_results = []
        for result in results:
            metadata = result['metadata']
            search_results.append(DecisionSearchResult(
                decisionId=metadata['decision_id'],
                text=result['content'],
                conversationId=metadata['conversation_id'],
                messageId=metadata['message_id'],
                timestamp=metadata['timestamp'],
                similarity=result['similarity']
            ))
        
        return DecisionSearchResponse(results=search_results)
        
    except Exception as e:
        print(f"❌ Error searching decisions: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/decisions/vector/{decision_id}")
async def delete_decision_vector(decision_id: str):
    """
    Delete decision vector from Pinecone (Story 5.2)
    
    NOTE: Firestore deletion happens on iOS client.
    This endpoint only removes the vector embedding.
    """
    try:
        vector_store = get_vector_store()
        vector_store.delete_decision(decision_id)
        
        return {"success": True, "message": "Decision vector deleted successfully"}
        
    except Exception as e:
        print(f"❌ Error deleting decision vector: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/decisions/extract")
async def extract_decisions():
    """
    Extract decisions made in conversations
    TODO: Implement in Story 5.5 (batch processing)
    """
    return {
        "status": "not_implemented",
        "message": "Batch decision extraction will be implemented in Story 5.5"
    }



