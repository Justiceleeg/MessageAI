"""
OpenAI Service
Handles direct OpenAI API interactions for chat completions and embeddings
"""
from openai import OpenAI
import os
from typing import List, Dict, Any, Optional


class OpenAIService:
    """
    Service for interacting with OpenAI's API.
    Handles chat completions, embeddings, and AI-powered text generation.
    """
    
    def __init__(self):
        """Initialize OpenAI client"""
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.embedding_model = "text-embedding-3-small"
        self.chat_model = "gpt-4o-mini"
        
        print(f"✅ OpenAIService initialized with model: {self.chat_model}")
    
    def generate_embedding(self, text: str) -> List[float]:
        """
        Generate embedding vector for text
        
        Args:
            text: Text to embed
        
        Returns:
            List of floats representing the embedding vector
        """
        response = self.client.embeddings.create(
            model=self.embedding_model,
            input=text
        )
        return response.data[0].embedding
    
    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        """
        Generate chat completion using GPT model
        
        Args:
            messages: List of message dicts with 'role' and 'content'
            system_prompt: Optional system prompt to prepend
            temperature: Sampling temperature (0-2)
            max_tokens: Maximum tokens to generate
        
        Returns:
            Generated response text
        """
        # Prepend system prompt if provided
        if system_prompt:
            messages = [{"role": "system", "content": system_prompt}] + messages
        
        response = self.client.chat.completions.create(
            model=self.chat_model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        return response.choices[0].message.content
    
    def analyze_sentiment(self, text: str) -> Dict[str, Any]:
        """
        Analyze sentiment of text
        
        Args:
            text: Text to analyze
        
        Returns:
            Dictionary with sentiment analysis results
        """
        system_prompt = """You are a sentiment analysis expert. Analyze the sentiment of the given text.
Respond with ONLY a JSON object in this exact format:
{
    "sentiment": "positive|negative|neutral",
    "confidence": 0.0-1.0,
    "emotions": ["emotion1", "emotion2"]
}"""
        
        messages = [{"role": "user", "content": text}]
        
        response = self.chat_completion(
            messages=messages,
            system_prompt=system_prompt,
            temperature=0.3
        )
        
        # Parse JSON response
        import json
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            return {
                "sentiment": "neutral",
                "confidence": 0.5,
                "emotions": [],
                "error": "Failed to parse response"
            }
    
    def summarize_text(self, text: str, max_length: int = 100) -> str:
        """
        Generate a summary of the text
        
        Args:
            text: Text to summarize
            max_length: Maximum length of summary in words
        
        Returns:
            Summary text
        """
        system_prompt = f"Summarize the following text in no more than {max_length} words. Be concise and capture the key points."
        
        messages = [{"role": "user", "content": text}]
        
        return self.chat_completion(
            messages=messages,
            system_prompt=system_prompt,
            temperature=0.5
        )
    
    def extract_key_points(self, text: str) -> List[str]:
        """
        Extract key points from text
        
        Args:
            text: Text to analyze
        
        Returns:
            List of key points
        """
        system_prompt = """Extract the key points from the text as a JSON array of strings.
Respond with ONLY a JSON array like: ["point1", "point2", "point3"]"""
        
        messages = [{"role": "user", "content": text}]
        
        response = self.chat_completion(
            messages=messages,
            system_prompt=system_prompt,
            temperature=0.3
        )
        
        # Parse JSON response
        import json
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            return []


# Singleton instance
_openai_service_instance = None


def get_openai_service() -> OpenAIService:
    """
    Get or create the OpenAIService singleton instance
    
    Returns:
        OpenAIService instance
    """
    global _openai_service_instance
    if _openai_service_instance is None:
        _openai_service_instance = OpenAIService()
    return _openai_service_instance



