"""
Database Models
Internal data models for database operations
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


class StoredMessage(BaseModel):
    """Message stored in vector database"""
    message_id: str
    text: str
    user_id: str
    conversation_id: str
    timestamp: datetime
    metadata: Optional[Dict[str, Any]] = None


class ConversationMetadata(BaseModel):
    """Metadata about a conversation"""
    conversation_id: str
    participant_ids: List[str]
    message_count: int
    start_time: datetime
    last_activity: datetime
    topics: Optional[List[str]] = None


class AnalysisCache(BaseModel):
    """Cached analysis results"""
    cache_key: str
    analysis_type: str
    result: Dict[str, Any]
    timestamp: datetime
    expires_at: Optional[datetime] = None

