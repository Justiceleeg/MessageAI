"""
Summarization Routes
Handles conversation summarization
"""
from fastapi import APIRouter

router = APIRouter()


@router.post("/summarize/conversation")
async def summarize_conversation():
    """
    Generate summary of a conversation
    TODO: Implement in Story 5.2
    """
    return {
        "status": "not_implemented",
        "message": "Conversation summarization will be implemented in Story 5.2"
    }



