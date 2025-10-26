"""
Agent Routes
Handles intelligent agent Q&A about conversations and proactive conflict detection
"""
from fastapi import APIRouter, HTTPException

router = APIRouter()


@router.post("/agent/ask")
async def ask_agent():
    """
    Ask questions about conversation history
    TODO: Implement in future story
    """
    return {
        "status": "not_implemented",
        "message": "Intelligent agent will be implemented in a future story"
    }


@router.post("/proactive-assist")
async def proactive_assist():
    """
    Proactive conflict detection and assistance
    NOTE: Conflict detection is now integrated into the analyze_message endpoint
    """
    return {
        "status": "moved",
        "message": "Conflict detection is now integrated into /api/v1/analyze-message endpoint"
    }