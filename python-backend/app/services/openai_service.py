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
    
    def analyze_message_comprehensive(
        self, 
        text: str,
        user_calendar: Optional[List[Dict[str, Any]]] = None,
        conversation_context: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """
        Comprehensive message analysis detecting events, reminders, decisions, RSVP, priority, and conflicts
        
        Args:
            text: Message text to analyze
            user_calendar: Optional list of user's existing calendar events for conflict detection
            conversation_context: Optional list of recent messages from conversation for RAG (Story 5.2)
        
        Returns:
            Dictionary with all detection results
        """
        import json
        from datetime import datetime
        
        # Build conversation context if provided (Story 5.2 - Lightweight RAG)
        context_section = ""
        if conversation_context and len(conversation_context) > 0:
            context_section = "\n\nRECENT CONVERSATION CONTEXT:\n"
            for msg in conversation_context:
                sender = msg.get('metadata', {}).get('sender', 'User')
                content = msg.get('content', '')
                context_section += f"{sender}: {content}\n"
            context_section += f"\nCurrent message: {text}\n"
        
        # Build calendar context if provided
        calendar_context = ""
        if user_calendar:
            calendar_context = "\n\nUser's existing calendar events:\n"
            for event in user_calendar[:10]:  # Limit to 10 most recent
                calendar_context += f"- {event.get('title', 'Untitled')} on {event.get('date', 'Unknown')}\n"
        
        system_prompt = f"""You are an AI assistant that analyzes messages for important information.

IMPORTANT DISTINCTIONS:
- **Events** are social gatherings with BOTH specific date AND time, involving multiple people. Example: "Dinner Friday at 7pm"
- **Reminders** are personal tasks with deadlines but NO specific time. Example: "Send docs by Friday"  
- **Decisions** are group agreements with NO time constraints. Example: "Let's go to Italian restaurant"

{context_section if context_section else f'Analyze this message: "{text}"'}{calendar_context}

Detect ALL of the following (return JSON):
1. **calendar**: Detect calendar events (date + time + multiple people)
   - detected: true/false
   - title: brief event name (null if not detected)
   - date: ISO 8601 (YYYY-MM-DD, null if not detected)
   - time: HH:MM 24-hour format (null if no specific time)
   - location: place name (null if not mentioned)

2. **reminder**: Detect reminders (tasks with deadlines, NO specific time)
   - detected: true/false
   - title: task description (null if not detected)
   - due_date: ISO 8601 (YYYY-MM-DD, null if not detected)

3. **decision**: Detect decisions/agreements (Story 5.2 - Context-Aware Detection)
   - detected: true/false
   - text: COMPLETE decision statement using conversation context if provided (null if not detected)
   - CRITICAL: Agreement phrases like "sounds good", "yeah", "okay", "let's do it", "I'm in" ARE decisions when context is provided
   - ALWAYS use conversation context to create a complete, clear decision statement
   - Examples:
     * "Yeah, sounds good" + context "Italian restaurant on Main St" → detected=true, text="Going to Italian restaurant on Main Street"
     * "Okay" + context "meeting at 3pm Friday" → detected=true, text="Meeting at 3pm on Friday"
     * "Let's do it" + context "Luigi's for dinner" → detected=true, text="Going to Luigi's for dinner"
     * "I'm in" + context "coffee at Starbucks" → detected=true, text="Meeting at Starbucks for coffee"

4. **rsvp**: Detect RSVP responses
   - detected: true/false
   - status: "accepted" or "declined" (null if not detected)
   - event_reference: what event they're responding to (null if not clear)

5. **priority**: Detect urgency/priority
   - detected: true/false
   - level: "low", "medium", or "high" (null if not detected)

6. **conflict**: Detect schedule conflicts (check against user_calendar)
   - detected: true/false
   - conflicting_events: [] (list of event titles that conflict)

Current date context: {datetime.now().strftime('%Y-%m-%d')}

Return ONLY valid JSON in this exact structure:
{{
  "calendar": {{"detected": false, "title": null, "date": null, "time": null, "location": null}},
  "reminder": {{"detected": false, "title": null, "due_date": null}},
  "decision": {{"detected": false, "text": null}},
  "rsvp": {{"detected": false, "status": null, "event_reference": null}},
  "priority": {{"detected": false, "level": null}},
  "conflict": {{"detected": false, "conflicting_events": []}}
}}"""
        
        messages = [{"role": "user", "content": text}]
        
        response = self.chat_completion(
            messages=messages,
            system_prompt=system_prompt,
            temperature=0.2  # Low temperature for consistent structured output
        )
        
        # Parse JSON response
        try:
            result = json.loads(response)
            # Ensure all required fields are present with defaults
            defaults = {
                "calendar": {"detected": False, "title": None, "date": None, "time": None, "location": None},
                "reminder": {"detected": False, "title": None, "due_date": None},
                "decision": {"detected": False, "text": None},
                "rsvp": {"detected": False, "status": None, "event_reference": None},
                "priority": {"detected": False, "level": None},
                "conflict": {"detected": False, "conflicting_events": []}
            }
            # Merge defaults with result
            for key in defaults:
                if key not in result:
                    result[key] = defaults[key]
                else:
                    for subkey in defaults[key]:
                        if subkey not in result[key]:
                            result[key][subkey] = defaults[key][subkey]
            return result
        except json.JSONDecodeError as e:
            print(f"Failed to parse GPT response: {e}")
            print(f"Response was: {response}")
            # Return empty detections on error
            return {
                "calendar": {"detected": False, "title": None, "date": None, "time": None, "location": None},
                "reminder": {"detected": False, "title": None, "due_date": None},
                "decision": {"detected": False, "text": None},
                "rsvp": {"detected": False, "status": None, "event_reference": None},
                "priority": {"detected": False, "level": None},
                "conflict": {"detected": False, "conflicting_events": []}
            }


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



