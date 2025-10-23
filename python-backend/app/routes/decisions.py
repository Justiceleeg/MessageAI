"""
Decisions Routes
Handles decision tracking from conversations
"""
from fastapi import APIRouter

router = APIRouter()


@router.post("/decisions/extract")
async def extract_decisions():
    """
    Extract decisions made in conversations
    TODO: Implement in Story 5.5
    """
    return {
        "status": "not_implemented",
        "message": "Decision extraction will be implemented in Story 5.5"
    }



