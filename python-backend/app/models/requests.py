"""
Request Models
Pydantic models for API request validation
"""
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class MessageAnalysisRequest(BaseModel):
    """Request for analyzing a single message"""
    message_id: str = Field(..., description="Unique message identifier")
    text: str = Field(..., description="Message text content")
    user_id: str = Field(..., description="User who sent the message")
    conversation_id: str = Field(..., description="Conversation identifier")
    user_calendar: Optional[List[dict]] = Field(default=None, description="User's existing calendar events")
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "text": "Let's meet Friday at 3pm for coffee",
                "user_id": "user_456",
                "conversation_id": "conv_789",
                "user_calendar": []
            }
        }


class ConversationSummarizationRequest(BaseModel):
    """Request for summarizing a conversation"""
    conversation_id: str = Field(..., description="Conversation identifier")
    messages: List[dict] = Field(..., description="List of messages to summarize")
    max_length: Optional[int] = Field(100, description="Maximum summary length in words")
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "messages": [
                    {"text": "Hi there!", "user_id": "user_1"},
                    {"text": "Hello! How are you?", "user_id": "user_2"}
                ],
                "max_length": 50
            }
        }


class EventDetectionRequest(BaseModel):
    """Request for detecting events in messages"""
    conversation_id: str = Field(..., description="Conversation identifier")
    messages: List[dict] = Field(..., description="Messages to analyze for events")
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "messages": [
                    {"text": "Let's meet tomorrow at 3pm", "timestamp": "2024-01-15T10:00:00Z"}
                ]
            }
        }


class ReminderSuggestionRequest(BaseModel):
    """Request for suggesting reminders"""
    message_id: str = Field(..., description="Message identifier")
    text: str = Field(..., description="Message text")
    conversation_id: str = Field(..., description="Conversation identifier")
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "text": "Don't forget to send the report by Friday",
                "conversation_id": "conv_789"
            }
        }


class DecisionExtractionRequest(BaseModel):
    """Request for extracting decisions from conversations"""
    conversation_id: str = Field(..., description="Conversation identifier")
    messages: List[dict] = Field(..., description="Messages to analyze")
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "messages": [
                    {"text": "We've decided to go with option A", "user_id": "user_1"}
                ]
            }
        }


class AgentQueryRequest(BaseModel):
    """Request for querying the intelligent agent"""
    conversation_id: str = Field(..., description="Conversation context")
    query: str = Field(..., description="Question to ask about the conversation")
    
    class Config:
        json_schema_extra = {
            "example": {
                "conversation_id": "conv_789",
                "query": "What was decided about the project timeline?"
            }
        }


class EventCreateRequest(BaseModel):
    """Request for creating an event with deduplication check"""
    title: str = Field(..., description="Event title")
    date: str = Field(..., description="Event date (ISO 8601)")
    time: Optional[str] = Field(None, description="Event time (HH:MM format)")
    location: Optional[str] = Field(None, description="Event location")
    user_id: str = Field(..., description="User creating the event")
    conversation_id: str = Field(..., description="Conversation where event was created")
    message_id: str = Field(..., description="Message that created this event")
    
    class Config:
        json_schema_extra = {
            "example": {
                "title": "Coffee meeting",
                "date": "2025-10-27",
                "time": "15:00",
                "location": "Starbucks",
                "user_id": "user_123",
                "conversation_id": "conv_456",
                "message_id": "msg_789"
            }
        }


class EventSearchRequest(BaseModel):
    """Request for searching similar events"""
    user_id: str = Field(..., description="User ID for filtering results")
    query: str = Field(..., description="Search query (event title + date)")
    k: int = Field(default=3, description="Number of results to return")
    
    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "user_123",
                "query": "Coffee meeting 2025-10-27",
                "k": 3
            }
        }

