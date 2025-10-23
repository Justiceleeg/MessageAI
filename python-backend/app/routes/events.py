"""
Events Routes
Handles event detection from messages
"""
from fastapi import APIRouter

router = APIRouter()


@router.post("/events/detect")
async def detect_events():
    """
    Detect events mentioned in messages
    TODO: Implement in Story 5.3
    """
    return {
        "status": "not_implemented",
        "message": "Event detection will be implemented in Story 5.3"
    }



