"""
Response Models
Pydantic models for API responses
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime


class SentimentAnalysisResponse(BaseModel):
    """Response for sentiment analysis"""
    message_id: str
    sentiment: str = Field(..., description="positive, negative, or neutral")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence score")
    emotions: List[str] = Field(default_factory=list, description="Detected emotions")
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "sentiment": "positive",
                "confidence": 0.92,
                "emotions": ["joy", "excitement"]
            }
        }


class ToneAnalysisResponse(BaseModel):
    """Response for tone analysis"""
    message_id: str
    tone: str = Field(..., description="Detected tone")
    intensity: float = Field(..., ge=0.0, le=1.0)
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "tone": "friendly",
                "intensity": 0.85
            }
        }


class ConversationSummaryResponse(BaseModel):
    """Response for conversation summarization"""
    conversation_id: str
    summary: str = Field(..., description="Generated summary")
    key_points: List[str] = Field(default_factory=list)
    message_count: int = Field(..., description="Number of messages summarized")
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "summary": "Discussion about project timeline and deliverables",
                "key_points": ["Timeline set to 2 weeks", "User A will handle design"],
                "message_count": 15
            }
        }


class Event(BaseModel):
    """Detected event model"""
    event_type: str = Field(..., description="Type of event (meeting, deadline, etc.)")
    title: str = Field(..., description="Event title")
    datetime: Optional[str] = Field(None, description="Event date/time if detected")
    description: Optional[str] = Field(None, description="Event description")
    participants: List[str] = Field(default_factory=list)


class EventDetectionResponse(BaseModel):
    """Response for event detection"""
    conversation_id: str
    events: List[Event] = Field(default_factory=list)
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "events": [
                    {
                        "event_type": "meeting",
                        "title": "Project sync",
                        "datetime": "2024-01-20T15:00:00Z",
                        "description": "Discuss project progress",
                        "participants": ["user_1", "user_2"]
                    }
                ]
            }
        }


class Reminder(BaseModel):
    """Suggested reminder model"""
    title: str
    description: str
    suggested_time: Optional[str] = Field(None, description="Suggested reminder time")
    priority: str = Field(default="medium", description="low, medium, or high")


class ReminderSuggestionResponse(BaseModel):
    """Response for reminder suggestions"""
    message_id: str
    reminders: List[Reminder] = Field(default_factory=list)
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "reminders": [
                    {
                        "title": "Send report",
                        "description": "Complete and send the weekly report",
                        "suggested_time": "2024-01-19T09:00:00Z",
                        "priority": "high"
                    }
                ]
            }
        }


class Decision(BaseModel):
    """Extracted decision model"""
    decision_text: str = Field(..., description="The decision that was made")
    context: str = Field(..., description="Context around the decision")
    participants: List[str] = Field(default_factory=list)
    timestamp: Optional[str] = None


class DecisionExtractionResponse(BaseModel):
    """Response for decision extraction"""
    conversation_id: str
    decisions: List[Decision] = Field(default_factory=list)
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "decisions": [
                    {
                        "decision_text": "Use React for frontend",
                        "context": "After discussing options, team agreed on React",
                        "participants": ["user_1", "user_2"],
                        "timestamp": "2024-01-15T14:30:00Z"
                    }
                ]
            }
        }


class AgentQueryResponse(BaseModel):
    """Response for agent queries"""
    conversation_id: str
    query: str
    answer: str = Field(..., description="Agent's answer to the query")
    sources: List[str] = Field(default_factory=list, description="Message IDs used as sources")
    confidence: float = Field(..., ge=0.0, le=1.0)
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "query": "What was decided about the timeline?",
                "answer": "The team decided to complete the project in 2 weeks",
                "sources": ["msg_123", "msg_124"],
                "confidence": 0.89
            }
        }


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str = "messageai-backend"


class CalendarDetection(BaseModel):
    """Calendar event detection result"""
    detected: bool = Field(..., description="Whether a calendar event was detected")
    title: Optional[str] = Field(None, description="Event title")
    date: Optional[str] = Field(None, description="Event date (ISO 8601)")
    time: Optional[str] = Field(None, description="Event time (HH:MM)")
    location: Optional[str] = Field(None, description="Event location")


class ReminderDetection(BaseModel):
    """Reminder detection result"""
    detected: bool = Field(..., description="Whether a reminder was detected")
    title: Optional[str] = Field(None, description="Reminder title")
    due_date: Optional[str] = Field(None, description="Due date (ISO 8601)")


class DecisionDetection(BaseModel):
    """Decision detection result"""
    detected: bool = Field(..., description="Whether a decision was detected")
    text: Optional[str] = Field(None, description="Decision text")


class RSVPDetection(BaseModel):
    """RSVP detection result"""
    detected: bool = Field(..., description="Whether an RSVP was detected")
    status: Optional[str] = Field(None, description="RSVP status (accepted, declined)")
    event_reference: Optional[str] = Field(None, description="Referenced event title/date")


class PriorityDetection(BaseModel):
    """Priority/urgency detection result"""
    detected: bool = Field(..., description="Whether priority was detected")
    level: Optional[str] = Field(None, description="Priority level (low, medium, high)")


class ConflictDetection(BaseModel):
    """Schedule conflict detection result"""
    detected: bool = Field(..., description="Whether a conflict was detected")
    conflicting_events: List[str] = Field(default_factory=list, description="List of conflicting event IDs")


class MessageAnalysisResponse(BaseModel):
    """Response for comprehensive message analysis"""
    message_id: str
    calendar: CalendarDetection
    reminder: ReminderDetection
    decision: DecisionDetection
    rsvp: RSVPDetection
    priority: PriorityDetection
    conflict: ConflictDetection
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "calendar": {
                    "detected": True,
                    "title": "Coffee meeting",
                    "date": "2025-10-27",
                    "time": "15:00",
                    "location": "Starbucks"
                },
                "reminder": {"detected": False},
                "decision": {"detected": False},
                "rsvp": {"detected": False},
                "priority": {"detected": False},
                "conflict": {"detected": False, "conflicting_events": []}
            }
        }


class EventCreateResponse(BaseModel):
    """Response for event creation"""
    success: bool
    event_id: Optional[str] = None
    suggest_link: bool = Field(default=False, description="Whether to suggest linking to existing event")
    similar_event: Optional[Dict[str, Any]] = Field(None, description="Similar event if found")
    message: str = Field(..., description="Status message")
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "event_id": "evt_123",
                "suggest_link": False,
                "similar_event": None,
                "message": "Event created successfully"
            }
        }


class EventSearchResult(BaseModel):
    """Single event search result"""
    event_id: str
    title: str
    date: str
    similarity: float = Field(..., ge=0.0, le=1.0, description="Similarity score")


class EventSearchResponse(BaseModel):
    """Response for event search"""
    results: List[EventSearchResult] = Field(default_factory=list)
    
    class Config:
        json_schema_extra = {
            "example": {
                "results": [
                    {
                        "event_id": "evt_123",
                        "title": "Coffee meeting",
                        "date": "2025-10-27",
                        "similarity": 0.92
                    }
                ]
            }
        }


class DecisionCreateResponse(BaseModel):
    """Response for decision vector storage (Story 5.2)"""
    success: bool
    decisionId: Optional[str] = None
    message: str = Field(..., description="Status message")
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "decisionId": "dec_123",
                "message": "Decision vector stored successfully"
            }
        }


class DecisionSearchResult(BaseModel):
    """Single decision search result (Story 5.2)"""
    decisionId: str
    text: str
    conversationId: str
    messageId: str
    timestamp: str
    similarity: float = Field(..., ge=0.0, le=1.0, description="Similarity score")


class DecisionSearchResponse(BaseModel):
    """Response for decision search (Story 5.2)"""
    results: List[DecisionSearchResult] = Field(default_factory=list)
    
    class Config:
        json_schema_extra = {
            "example": {
                "results": [
                    {
                        "decisionId": "dec_123",
                        "text": "Going to Luigi's Italian restaurant",
                        "conversationId": "conv_456",
                        "messageId": "msg_789",
                        "timestamp": "2025-10-24T15:30:00Z",
                        "similarity": 0.94
                    }
                ]
            }
        }


