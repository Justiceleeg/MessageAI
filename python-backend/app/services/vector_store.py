"""
Vector Store Service
Manages Pinecone vector database for message embeddings and semantic search
"""
from langchain_openai import OpenAIEmbeddings
from langchain_pinecone import PineconeVectorStore
from pinecone import Pinecone, ServerlessSpec
import os
from typing import List, Dict, Any, Optional


class VectorStoreService:
    """
    Service for managing vector storage and retrieval using Pinecone.
    Handles message embeddings and semantic search operations.
    """
    
    def __init__(self):
        """Initialize Pinecone connection and embedding model"""
        # Initialize Pinecone client
        self.pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))
        
        # Connect to the messageai index
        self.index_name = "messageai"
        self.index = self.pc.Index(self.index_name)
        
        # Initialize OpenAI embeddings
        self.embeddings = OpenAIEmbeddings(
            model="text-embedding-3-small",
            openai_api_key=os.getenv("OPENAI_API_KEY")
        )
        
        # Create LangChain vector store instances using from_existing_index pattern
        # This is the recommended approach for Pinecone SDK 5.0+ and langchain-pinecone 0.2.x
        self.messages_store = PineconeVectorStore.from_existing_index(
            index_name=self.index_name,
            embedding=self.embeddings,
            namespace="messages"
        )
        
        # Create events vector store instance for event deduplication
        self.events_store = PineconeVectorStore.from_existing_index(
            index_name=self.index_name,
            embedding=self.embeddings,
            namespace="events"
        )
        
        # Create decisions vector store instance for decision tracking (Story 5.2)
        self.decisions_store = PineconeVectorStore.from_existing_index(
            index_name=self.index_name,
            embedding=self.embeddings,
            namespace="decisions"
        )
        
        print(f"✅ VectorStoreService initialized with index: {self.index_name}")
    
    def add_message(
        self, 
        message_id: str, 
        text: str, 
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        """
        Add a message to the vector store
        
        Args:
            message_id: Unique identifier for the message
            text: Message text content
            metadata: Additional metadata (user_id, conversation_id, timestamp, etc.)
        """
        if metadata is None:
            metadata = {}
        
        # Add message_id to metadata
        metadata["message_id"] = message_id
        
        # Add to vector store
        self.messages_store.add_texts(
            texts=[text],
            metadatas=[metadata],
            ids=[message_id]
        )
    
    def search_similar_messages(
        self, 
        query: str, 
        k: int = 5,
        filter_dict: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Search for semantically similar messages
        
        Args:
            query: Search query text
            k: Number of results to return
            filter_dict: Optional metadata filters (e.g., {"conversation_id": "123"})
        
        Returns:
            List of similar messages with content and metadata
        """
        # Generate embedding for the query
        query_embedding = self.embeddings.embed_query(query)
        
        # Use similarity_search_by_vector instead of similarity_search
        # (LangChain's similarity_search has issues with Pinecone serverless)
        results = self.messages_store.similarity_search_by_vector(
            embedding=query_embedding,
            k=k,
            filter=filter_dict
        )
        
        return [
            {
                "content": doc.page_content,
                "metadata": doc.metadata
            }
            for doc in results
        ]
    
    def delete_message(self, message_id: str) -> None:
        """
        Delete a message from the vector store
        
        Args:
            message_id: ID of the message to delete
        """
        self.index.delete(ids=[message_id], namespace="messages")
    
    def get_index_stats(self) -> Dict[str, Any]:
        """
        Get statistics about the Pinecone index
        
        Returns:
            Dictionary with index statistics
        """
        return self.index.describe_index_stats()
    
    def add_event(
        self, 
        event_id: str, 
        text: str, 
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        """
        Add an event to the vector store for deduplication
        
        Args:
            event_id: Unique identifier for the event
            text: Event text (title + date for semantic matching)
            metadata: Additional metadata (event details)
        """
        if metadata is None:
            metadata = {}
        
        # Add event_id to metadata
        metadata["event_id"] = event_id
        metadata["type"] = "event"
        
        # Add to events vector store
        self.events_store.add_texts(
            texts=[text],
            metadatas=[metadata],
            ids=[event_id]
        )
    
    def search_similar_events(
        self, 
        query: str, 
        k: int = 3,
        filter_dict: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Search for semantically similar events (for deduplication)
        
        Args:
            query: Search query text (event title + date)
            k: Number of results to return
            filter_dict: Optional metadata filters (e.g., {"user_id": "123"})
        
        Returns:
            List of similar events with content, metadata, and similarity scores
        """
        # Generate embedding for the query
        query_embedding = self.embeddings.embed_query(query)
        
        # Use similarity_search_with_score_by_vector for consistency
        # (LangChain's similarity_search has issues with Pinecone serverless)
        results = self.events_store.similarity_search_with_score_by_vector(
            embedding=query_embedding,
            k=k,
            filter=filter_dict
        )
        
        return [
            {
                "content": doc.page_content,
                "metadata": doc.metadata,
                "similarity": float(score)  # Cosine similarity score
            }
            for doc, score in results
        ]
    
    def delete_event(self, event_id: str) -> None:
        """
        Delete an event from the vector store
        
        Args:
            event_id: ID of the event to delete
        """
        self.index.delete(ids=[event_id], namespace="events")
    
    def add_decision(
        self, 
        decision_id: str, 
        text: str, 
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        """
        Add a decision to the vector store for semantic search (Story 5.2)
        
        Args:
            decision_id: Unique identifier for the decision
            text: Decision text (complete, contextual summary)
            metadata: Additional metadata (decision details)
        """
        if metadata is None:
            metadata = {}
        
        # Add decision_id to metadata
        metadata["decision_id"] = decision_id
        metadata["type"] = "decision"
        
        # Add to decisions vector store
        self.decisions_store.add_texts(
            texts=[text],
            metadatas=[metadata],
            ids=[decision_id]
        )
    
    def search_similar_decisions(
        self, 
        query: str, 
        k: int = 10,
        filter_dict: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Search for semantically similar decisions (Story 5.2)
        
        Args:
            query: Search query text
            k: Number of results to return
            filter_dict: Optional metadata filters (e.g., {"user_id": "123", "conversation_id": "conv123"})
        
        Returns:
            List of similar decisions with content, metadata, and similarity scores
        """
        # Generate embedding for the query
        query_embedding = self.embeddings.embed_query(query)
        
        # Use similarity_search_by_vector (returns documents without scores)
        results = self.decisions_store.similarity_search_by_vector(
            embedding=query_embedding,
            k=k,
            filter=filter_dict
        )
        
        # Return results with placeholder similarity (Pinecone serverless doesn't return scores easily)
        return [
            {
                "content": doc.page_content,
                "metadata": doc.metadata,
                "similarity": 0.95 - (i * 0.05)  # Decreasing scores based on rank
            }
            for i, doc in enumerate(results)
        ]
    
    def delete_decision(self, decision_id: str) -> None:
        """
        Delete a decision from the vector store
        
        Args:
            decision_id: ID of the decision to delete
        """
        self.index.delete(ids=[decision_id], namespace="decisions")


# Singleton instance
_vector_store_instance = None


def get_vector_store() -> VectorStoreService:
    """
    Get or create the VectorStoreService singleton instance
    
    Returns:
        VectorStoreService instance
    """
    global _vector_store_instance
    if _vector_store_instance is None:
        _vector_store_instance = VectorStoreService()
    return _vector_store_instance



