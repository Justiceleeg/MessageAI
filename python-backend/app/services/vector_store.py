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
        
        # Create LangChain vector store instance
        self.messages_store = PineconeVectorStore(
            index=self.index,
            embedding=self.embeddings,
            namespace="messages"
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
        results = self.messages_store.similarity_search(
            query=query,
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



