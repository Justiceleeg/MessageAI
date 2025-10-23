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
    
    class Config:
        json_schema_extra = {
            "example": {
                "message_id": "msg_123",
                "text": "I'm really excited about the project!",
                "user_id": "user_456",
                "conversation_id": "conv_789"
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

