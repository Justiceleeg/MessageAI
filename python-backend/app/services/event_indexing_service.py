"""
Event Indexing Service
Handles indexing events in Pinecone for conflict detection and similarity search
"""
from typing import List, Dict, Any, Optional
from datetime import datetime
import os
from langchain_openai import OpenAIEmbeddings
from langchain_pinecone import PineconeVectorStore
from pinecone import Pinecone
import logging

logger = logging.getLogger(__name__)


class EventIndexingService:
    """Service for indexing events in Pinecone for conflict detection"""
    
    def __init__(self):
        """Initialize Pinecone connection and embedding model"""
        # Initialize Pinecone client
        self.pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))
        
        # Connect to the events index
        self.index_name = "events"
        self.index = self.pc.Index(self.index_name)
        
        # Initialize OpenAI embeddings
        self.embeddings = OpenAIEmbeddings(
            model="text-embedding-3-small",
            openai_api_key=os.getenv("OPENAI_API_KEY")
        )
        
        # Create events vector store
        self.events_store = PineconeVectorStore.from_existing_index(
            index_name=self.index_name,
            embedding=self.embeddings
        )
    
    def index_event(self, event: Dict[str, Any]) -> bool:
        """
        Index an event in Pinecone for conflict detection
        
        Args:
            event: Event dictionary with id, title, date, startTime, endTime, etc.
            
        Returns:
            bool: True if successful, False otherwise
        """
        import time
        start_time = time.time()
        
        try:
            # Create embedding from event details
            text_start = time.time()
            event_text = self._create_event_text(event)
            text_time = time.time() - text_start
            logger.info(f"📝 Event text creation took: {text_time:.3f}s")
            
            # Generate embedding
            embedding_start = time.time()
            embedding = self.embeddings.embed_query(event_text)
            embedding_time = time.time() - embedding_start
            logger.info(f"🧠 OpenAI embedding generation took: {embedding_time:.3f}s")
            
            # Prepare metadata - ensure no null values for Pinecone
            metadata_start = time.time()
            metadata = {
                "user_id": event.get("user_id") or "",
                "event_id": event.get("id") or "",
                "title": event.get("title") or "",
                "date": event.get("date") or "",
                "startTime": event.get("startTime") or "",
                "endTime": event.get("endTime") or "",
                "location": event.get("location") or "",
                "conversation_id": event.get("conversation_id") or "",
                "created_at": event.get("created_at") or datetime.now().isoformat()
            }
            metadata_time = time.time() - metadata_start
            logger.info(f"📋 Metadata preparation took: {metadata_time:.3f}s")
            
            # Upsert to Pinecone
            pinecone_start = time.time()
            self.events_store.add_texts(
                texts=[event_text],
                metadatas=[metadata],
                ids=[event.get("id")]
            )
            pinecone_time = time.time() - pinecone_start
            logger.info(f"🌲 Pinecone upsert took: {pinecone_time:.3f}s")
            
            total_time = time.time() - start_time
            logger.info(f"Successfully indexed event '{event.get('title')}' in {total_time:.3f}s")
            return True
            
        except Exception as e:
            total_time = time.time() - start_time
            logger.error(f"❌ Failed to index event after {total_time:.3f}s: {e}")
            return False
    
    def update_event(self, event: Dict[str, Any]) -> bool:
        """
        Update an existing event in Pinecone
        
        Args:
            event: Updated event dictionary
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Delete old version and add new one
            self.delete_event(event.get("id"))
            return self.index_event(event)
            
        except Exception as e:
            logger.error(f"❌ Failed to update event: {e}")
            return False
    
    def delete_event(self, event_id: str) -> bool:
        """
        Delete an event from Pinecone
        
        Args:
            event_id: ID of event to delete
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            self.events_store.delete(ids=[event_id])
            logger.info(f"Successfully deleted event: {event_id}")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to delete event: {e}")
            return False
    
    def search_conflicts(self, detected_event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
        """
        Search for conflicts with a detected event
        
        Args:
            detected_event: Event detected by AI analysis
            user_id: User ID to search within
            
        Returns:
            Dictionary with conflict analysis
        """
        try:
            # STEP 1: Search for ALL events at the same time (time-based conflict detection)
            time_conflicts = self._search_time_conflicts(detected_event, user_id)
            
            # STEP 2: For each time conflict, check semantic similarity
            conflicts = []
            similar_events = []
            same_event_detected = False
            
            for event_data in time_conflicts:
                event_id = event_data["event_id"]
                title = event_data["title"]
                
                # Calculate semantic similarity between detected event and existing event
                detected_text = self._create_event_text(detected_event)
                existing_text = self._create_event_text(event_data)
                
                # Create embeddings for both events
                detected_embedding = self.embeddings.embed_query(detected_text)
                existing_embedding = self.embeddings.embed_query(existing_text)
                
                # Calculate cosine similarity
                similarity = self._calculate_cosine_similarity(detected_embedding, existing_embedding)
                
                if similarity > 0.7:  # High threshold for same event (70%+ similarity)
                    same_event_detected = True
                    similar_events.append(event_id)
                else:
                    # Different event = conflict
                    conflict = {
                        "id": event_id,
                        "title": title,
                        "date": event_data.get("date"),
                        "startTime": event_data.get("startTime"),
                        "endTime": event_data.get("endTime"),
                        "location": event_data.get("location"),
                        "similarity_score": similarity
                    }
                    conflicts.append(conflict)
            
            # STEP 3: Also search for semantically similar events (for non-time conflicts)
            semantic_similar = self._search_semantic_similar(detected_event, user_id)
            
            # Add non-time-conflicting similar events
            for event_data in semantic_similar:
                event_id = event_data["event_id"]
                if not any(c["id"] == event_id for c in conflicts):  # Not already in conflicts
                    similar_events.append(event_id)
            
            return {
                "has_conflicts": len(conflicts) > 0,
                "conflicts": conflicts,
                "same_event_detected": same_event_detected,
                "similar_events": similar_events,
                "reasoning": self._generate_reasoning(conflicts, same_event_detected)
            }
            
        except Exception as e:
            logger.error(f"❌ Conflict search failed: {e}")
            return {
                "has_conflicts": False,
                "conflicts": [],
                "same_event_detected": False,
                "similar_events": [],
                "reasoning": f"Error searching conflicts: {str(e)}"
            }
    
    def search_similar_events(self, event: Dict[str, Any], user_id: str, limit: int = 5) -> List[Dict[str, Any]]:
        """
        Search for similar events (for deduplication)
        
        Args:
            event: Event to find similar ones for
            user_id: User ID to search within
            limit: Maximum number of results
            
        Returns:
            List of similar events
        """
        try:
            event_text = self._create_event_text(event)
            results = self.events_store.similarity_search_with_score(
                query=event_text,
                k=limit,
                filter={"user_id": user_id}
            )
            
            similar_events = []
            for doc, score in results:
                if score > 0.5:  # Semantic similarity threshold (lowered for better recall)
                    similar_events.append({
                        "id": doc.metadata.get("event_id"),
                        "title": doc.metadata.get("title"),
                        "date": doc.metadata.get("date"),
                        "startTime": doc.metadata.get("startTime"),
                        "endTime": doc.metadata.get("endTime"),
                        "similarity_score": score
                    })
            
            return similar_events
            
        except Exception as e:
            logger.error(f"❌ Similar events search failed: {e}")
            return []
    
    def search_similar_events_by_query(self, query: str, user_id: str, k: int = 5) -> List[Dict[str, Any]]:
        """
        Search for similar events by query string (optimized for deduplication)
        
        Args:
            query: Search query string
            user_id: User ID to search within
            k: Maximum number of results
            
        Returns:
            List of similar events
        """
        try:
            # Use the query directly without re-embedding
            results = self.events_store.similarity_search_with_score(
                query=query,
                k=k,
                filter={"user_id": user_id}
            )
            
            similar_events = []
            for doc, score in results:
                if score > 0.5:  # Semantic similarity threshold
                    similar_events.append({
                        "event_id": doc.metadata.get("event_id"),
                        "title": doc.metadata.get("title"),
                        "date": doc.metadata.get("date"),
                        "startTime": doc.metadata.get("startTime"),
                        "endTime": doc.metadata.get("endTime"),
                        "similarity_score": score
                    })
            
            return similar_events
            
        except Exception as e:
            logger.error(f"❌ Similar events search by query failed: {e}")
            return []
    
    def check_duplicates_and_index(self, event: Dict[str, Any], query: str) -> Dict[str, Any]:
        """
        Check for duplicates and index event in one optimized operation
        
        Args:
            event: Event data to check and index
            query: Search query for duplicate detection
            
        Returns:
            Dictionary with duplicate check results and indexing status
        """
        import time
        import asyncio
        start_time = time.time()
        
        try:
            user_id = event.get("user_id")
            
            # Optimization 1: Quick check if user has any events
            user_event_count = self._get_user_event_count(user_id)
            logger.info(f"👤 User {user_id} has {user_event_count} existing events")
            
            if user_event_count == 0:
                # New user - skip duplicate check and index directly
                logger.info(f"🚀 New user detected, skipping duplicate check")
                index_start = time.time()
                success = self.index_event(event)
                index_time = time.time() - index_start
                total_time = time.time() - start_time
                logger.info(f"📝 Event indexing took: {index_time:.3f}s, total: {total_time:.3f}s")
                
                return {
                    "is_duplicate": False,
                    "similar_event": None,
                    "indexed": success
                }
            
            # Existing user - check for duplicates
            search_start = time.time()
            similar_events = self.search_similar_events_by_query(query, user_id, k=3)
            search_time = time.time() - search_start
            logger.info(f"Duplicate search took: {search_time:.3f}s")
            
            # Check for high similarity (multi-chat linking threshold)
            SIMILARITY_THRESHOLD = 0.75
            for similar_event in similar_events:
                similarity = similar_event.get("similarity_score", 0.0)
                if similarity >= SIMILARITY_THRESHOLD:
                    # Found duplicate - don't index
                    total_time = time.time() - start_time
                    logger.info(f"Duplicate found, total time: {total_time:.3f}s")
                    return {
                        "is_duplicate": True,
                        "similar_event": similar_event,
                        "indexed": False
                    }
            
            # No duplicates found - index the event
            index_start = time.time()
            success = self.index_event(event)
            index_time = time.time() - index_start
            logger.info(f"📝 Event indexing took: {index_time:.3f}s")
            
            total_time = time.time() - start_time
            logger.info(f"Total operation time: {total_time:.3f}s")
            
            return {
                "is_duplicate": False,
                "similar_event": None,
                "indexed": success
            }
            
        except Exception as e:
            total_time = time.time() - start_time
            logger.error(f"❌ Duplicate check and indexing failed after {total_time:.3f}s: {e}")
            return {
                "is_duplicate": False,
                "similar_event": None,
                "indexed": False
            }
    
    def _get_user_event_count(self, user_id: str) -> int:
        """
        Get the count of events for a user (optimized check)
        
        Args:
            user_id: User ID to check
            
        Returns:
            Number of events for the user
        """
        try:
            # Use a simple count query instead of full search
            results = self.events_store.similarity_search_with_score(
                query="",  # Empty query to get all results
                k=1,  # We only need to know if any exist
                filter={"user_id": user_id}
            )
            return len(results)
        except Exception as e:
            logger.warning(f"⚠️ Could not get user event count: {e}")
            return 0  # Assume no events if we can't check
    
    def _create_event_text(self, event: Dict[str, Any]) -> str:
        """Create text representation of event for embedding"""
        parts = []
        
        if event.get("title"):
            parts.append(event["title"])
        
        if event.get("date"):
            parts.append(f"on {event['date']}")
        
        if event.get("startTime") and event.get("endTime"):
            parts.append(f"from {event['startTime']} to {event['endTime']}")
        elif event.get("startTime"):
            parts.append(f"at {event['startTime']}")
        
        if event.get("location"):
            parts.append(f"at {event['location']}")
        
        return " ".join(parts)
    
    def _times_overlap(self, date1: str, start1: str, end1: str, date2: str, start2: str, end2: str) -> bool:
        """
        Check if two time intervals overlap
        
        Args:
            date1: Date of first event (YYYY-MM-DD format)
            start1: Start time of first event (HH:MM format)
            end1: End time of first event (HH:MM format)
            date2: Date of second event (YYYY-MM-DD format)
            start2: Start time of second event (HH:MM format)
            end2: End time of second event (HH:MM format)
            
        Returns:
            True if events overlap in both date AND time
        """
        try:
            if not all([date1, start1, end1, date2, start2, end2]):
                return False
            
            # CRITICAL FIX: Dates must match for time overlap to matter
            if date1 != date2:
                return False
            
            # Convert to datetime objects for comparison WITH actual dates
            dt1_start = datetime.fromisoformat(f"{date1}T{start1}:00")
            dt1_end = datetime.fromisoformat(f"{date1}T{end1}:00")
            dt2_start = datetime.fromisoformat(f"{date2}T{start2}:00")
            dt2_end = datetime.fromisoformat(f"{date2}T{end2}:00")
            
            # Check if time intervals overlap
            return dt1_start < dt2_end and dt2_start < dt1_end
            
        except ValueError as e:
            logger.warning(f"Failed to parse datetime for overlap check: {e}")
            return False
    
    def _search_time_conflicts(self, detected_event: Dict[str, Any], user_id: str) -> List[Dict[str, Any]]:
        """
        Search for events that overlap in time with the detected event
        This is independent of semantic similarity - purely time-based
        """
        try:
            detected_date = detected_event.get("date")
            detected_start = detected_event.get("startTime")
            detected_end = detected_event.get("endTime")
            
            if not all([detected_date, detected_start, detected_end]):
                logger.warning("Missing time information for conflict detection")
                return []
            
            # Search for events on the same date
            # Note: This is a simplified approach - in production you'd want more sophisticated time filtering
            results = self.events_store.similarity_search_with_score(
                query=f"date {detected_date}",  # Search by date
                k=20,  # Get more results to filter by time
                filter={"user_id": user_id}  # Filter by user
            )
            
            time_conflicts = []
            for doc, score in results:
                metadata = doc.metadata
                event_date = metadata.get("date", "")
                
                # CRITICAL FIX: Only check time overlap if dates match
                if event_date == detected_date:
                    # Check if times overlap
                    if self._times_overlap(
                        detected_date, detected_start, detected_end,
                        event_date, metadata.get("startTime", ""), metadata.get("endTime", "")
                    ):
                        time_conflicts.append({
                            "event_id": metadata.get("event_id"),
                            "title": metadata.get("title"),
                            "date": metadata.get("date"),
                            "startTime": metadata.get("startTime"),
                            "endTime": metadata.get("endTime"),
                            "location": metadata.get("location")
                        })
            
            return time_conflicts
            
        except Exception as e:
            logger.error(f"❌ Time conflict search failed: {e}")
            return []
    
    def _search_semantic_similar(self, detected_event: Dict[str, Any], user_id: str) -> List[Dict[str, Any]]:
        """
        Search for semantically similar events (for non-time conflicts)
        """
        try:
            event_text = self._create_event_text(detected_event)
            
            results = self.events_store.similarity_search_with_score(
                query=event_text,
                k=10,
                filter={"user_id": user_id}
            )
            
            similar_events = []
            for doc, score in results:
                metadata = doc.metadata
                
                # Only include if similarity is high enough
                if score > 0.6:  # 60% similarity threshold
                    similar_events.append({
                        "event_id": metadata.get("event_id"),
                        "title": metadata.get("title"),
                        "date": metadata.get("date"),
                        "startTime": metadata.get("startTime"),
                        "endTime": metadata.get("endTime"),
                        "location": metadata.get("location")
                    })
            
            return similar_events
            
        except Exception as e:
            logger.error(f"❌ Semantic similarity search failed: {e}")
            return []
    
    def _calculate_cosine_similarity(self, embedding1: List[float], embedding2: List[float]) -> float:
        """
        Calculate cosine similarity between two embeddings
        """
        try:
            import numpy as np
            
            # Convert to numpy arrays
            vec1 = np.array(embedding1)
            vec2 = np.array(embedding2)
            
            # Calculate cosine similarity
            dot_product = np.dot(vec1, vec2)
            norm1 = np.linalg.norm(vec1)
            norm2 = np.linalg.norm(vec2)
            
            if norm1 == 0 or norm2 == 0:
                return 0.0
            
            similarity = dot_product / (norm1 * norm2)
            return float(similarity)
            
        except Exception as e:
            logger.error(f"❌ Cosine similarity calculation failed: {e}")
            return 0.0

    def _generate_reasoning(self, conflicts: List[Dict], same_event_detected: bool) -> str:
        """Generate reasoning for the conflict analysis"""
        if same_event_detected:
            return "This appears to be the same event being discussed (high semantic similarity detected)"
        
        if not conflicts:
            return "No scheduling conflicts detected"
        
        if len(conflicts) == 1:
            conflict = conflicts[0]
            similarity = conflict.get('similarity_score', 0)
            return f"This conflicts with your existing '{conflict['title']}' from {conflict['startTime']} to {conflict['endTime']} (similarity: {similarity:.1%})"
        else:
            return f"This conflicts with {len(conflicts)} existing events"


# Singleton instance
_event_indexing_service = None

def get_event_indexing_service() -> EventIndexingService:
    """Get singleton instance of the event indexing service"""
    global _event_indexing_service
    if _event_indexing_service is None:
        _event_indexing_service = EventIndexingService()
    return _event_indexing_service
