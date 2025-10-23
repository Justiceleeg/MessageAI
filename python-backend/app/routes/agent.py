"""
Agent Routes
Handles intelligent agent Q&A about conversations
"""
from fastapi import APIRouter

router = APIRouter()


@router.post("/agent/ask")
async def ask_agent():
    """
    Ask questions about conversation history
    TODO: Implement in Story 5.6
    """
    return {
        "status": "not_implemented",
        "message": "Intelligent agent will be implemented in Story 5.6"
    }



