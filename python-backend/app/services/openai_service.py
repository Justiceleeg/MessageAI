"""
OpenAI Service
Handles direct OpenAI API interactions for chat completions and embeddings
"""
from openai import OpenAI
import os
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class OpenAIService:
    """
    Service for interacting with OpenAI's API.
    Handles chat completions, embeddings, and AI-powered text generation.
    """
    
    def __init__(self):
        """Initialize OpenAI client"""
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.embedding_model = "text-embedding-3-small"
        self.chat_model = "gpt-3.5-turbo"
        
        # OpenAIService initialized successfully
    
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
        max_tokens: Optional[int] = None,
        functions: Optional[List[Dict]] = None,
        function_call: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Generate chat completion using GPT model
        
        Args:
            messages: List of message dicts with 'role' and 'content'
            system_prompt: Optional system prompt to prepend
            temperature: Sampling temperature (0-2)
            max_tokens: Maximum tokens to generate
            functions: Optional list of function definitions for function calling
            function_call: Optional function call specification
        
        Returns:
            Generated response (text or function call result)
        """
        # Prepend system prompt if provided
        if system_prompt:
            messages = [{"role": "system", "content": system_prompt}] + messages
        
        # Prepare request parameters
        request_params = {
            "model": self.chat_model,
            "messages": messages
        }
        
        # Add temperature only if the model supports it (not gpt-5-nano)
        if self.chat_model != "gpt-5-nano":
            request_params["temperature"] = temperature
        
        # Add optional parameters
        if max_tokens:
            request_params["max_tokens"] = max_tokens
        if functions:
            request_params["functions"] = functions
        if function_call:
            request_params["function_call"] = function_call
        
        response = self.client.chat.completions.create(**request_params)
        
        message = response.choices[0].message
        
        # Return structured response
        result = {
            "content": message.content,
            "function_call": message.function_call
        }
        
        return result
    
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
        message_timestamp: Optional[str] = None,
        user_calendar: Optional[List[Dict[str, Any]]] = None,
        conversation_context: Optional[List[Dict[str, Any]]] = None,
        user_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Comprehensive message analysis detecting events, reminders, decisions, RSVP, priority, and conflicts
        
        Args:
            text: Message text to analyze
            message_timestamp: Optional ISO 8601 timestamp of when the message was sent (for accurate date calculations)
            user_calendar: Optional list of user's existing calendar events for conflict detection
            conversation_context: Optional list of recent messages from conversation for RAG (Story 5.2)
            user_id: Optional user ID for conflict detection (Story 5.6)
        
        Returns:
            Dictionary with all detection results
        """
        import json
        from datetime import datetime, timedelta
        
        # QUICK FIX: Always use current server time for relative date parsing
        # This ensures "tomorrow" is calculated from the user's perspective
        # TODO: Replace with location-based timezone detection
        reference_time = datetime.now()
        message_timezone = None
        print(f"🌍 Using server time as reference: {reference_time.strftime('%Y-%m-%d %H:%M:%S')}")
        
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
                calendar_context += f"- {event.get('title', 'Untitled')} on {event.get('date', 'Unknown')} from {event.get('startTime', 'Unknown')} to {event.get('endTime', 'Unknown')}\n"
        
        system_prompt = f"""You are an AI assistant that analyzes messages for important information.

IMPORTANT DISTINCTIONS:
- **Events** are scheduled activities involving other people or social gatherings. Examples: "Dinner Friday at 7pm", "Meeting tomorrow at 2pm", "Party at my place Saturday", "Arcade tonight at 7pm", "Coffee today at 3pm"
- **Reminders** are personal tasks or commitments (even with specific times). Examples: "I'll finish the presentation by noon tomorrow", "Send docs by Friday", "Call mom at 3pm", "Submit report by EOD"

CALENDAR EVENT DETECTION RULES:
1. If message contains a TIME + LOCATION/ACTIVITY → ALWAYS detect as calendar event
2. If message contains "tonight", "today", "tomorrow" + activity → ALWAYS detect as calendar event  
3. If message contains "Let's", "We should", "Want to" + time → ALWAYS detect as calendar event
4. Examples that MUST be detected as calendar events:
   - "Let's go to the arcade tonight at 7pm" → CALENDAR EVENT
   - "Arcade today at 7pm" → CALENDAR EVENT  
   - "Coffee tomorrow morning" → CALENDAR EVENT
   - "Dinner Friday at 7pm" → CALENDAR EVENT
- **Decisions** are group agreements with NO time constraints. Example: "Let's go to Italian restaurant"

INVITATION LANGUAGE DETECTION:
An event contains "invitation language" if it:
- Uses inclusive language ("Let's", "We should", "Want to", "How about")
- Suggests participation ("Come to", "Join us", "Meet me", "Go to")
- Uses question format ("Want to grab coffee?", "Should we meet?")
- Contains social gathering language ("Party", "Dinner", "Meet up", "Hang out")

Examples of INVITATION language:
- "Let's go to the store tomorrow at 2pm" → is_invitation=true
- "Want to grab coffee tomorrow?" → is_invitation=true
- "Come to my party Friday night" → is_invitation=true
- "Should we meet for lunch?" → is_invitation=true

Examples of NON-invitation language:
- "I have a meeting tomorrow at 2pm" → is_invitation=false
- "The conference is next Tuesday" → is_invitation=false
- "Doctor appointment at 3pm" → is_invitation=false

{context_section if context_section else f'Analyze this message: "{text}"'}{calendar_context}

CRITICAL DATE/TIME PARSING RULES:
Current date context: {reference_time.strftime('%Y-%m-%d (%A)')}
Current time context: {reference_time.strftime('%H:%M')}

Your job is to EXTRACT temporal expressions, NOT calculate dates.
Examples:
- "Let's meet tomorrow at 7pm" → extract: date_expression="tomorrow", startTime="19:00", endTime=null
- "Dinner this Saturday" → extract: date_expression="this Saturday", startTime=null, endTime=null
- "Arcade tonight at 7pm" → extract: date_expression="today", startTime="19:00", endTime=null
- "Coffee in 3 days at 2pm" → extract: date_expression="3 days from now", startTime="14:00", endTime=null
- "Meeting next Monday morning" → extract: date_expression="next Monday", startTime="09:00", endTime=null
- "Meeting next Tuesday at 3pm" → extract: date_expression="next Tuesday", startTime="15:00", endTime=null
- "Conference call next week" → extract: date_expression="next week", startTime=null, endTime=null
- "Meeting 2pm to 4pm" → extract: startTime="14:00", endTime="16:00"
- "Lunch from 12:30 to 1:30" → extract: startTime="12:30", endTime="13:30"

RELATIVE DATE PARSING (be precise with these):
- "next Tuesday" → date_expression="next Tuesday" (NOT "this Tuesday")
- "this Tuesday" → date_expression="this Tuesday" (current week's Tuesday)
- "tonight" → date_expression="today" (same day, evening time)
- "this evening" → date_expression="today" (same day, evening time)
- "next week" → date_expression="next week"
- "this weekend" → date_expression="this weekend"
- "next weekend" → date_expression="next weekend"
- "in 2 weeks" → date_expression="in 2 weeks"
- "next month" → date_expression="next month"

CRITICAL TIME PARSING (these often fail - be precise):
- "at noon" → startTime="12:00"
- "7pm" → startTime="19:00"
- "4:44pm" → startTime="16:44"
- "midnight" → startTime="00:00"
- "in the morning" → startTime="09:00" (default morning time)
- "in the afternoon" → startTime="15:00" (default afternoon time)
- "in the evening" → startTime="19:00" (default evening time)

IMPORTANT: If endTime is NOT mentioned, leave it null. Backend will apply 1-hour default automatically.

COMMON TIME ACRONYMS (already expanded in input):
- EOD/end of day → 11:59 PM
- EOB/end of business → 5:00 PM
- ASAP/as soon as possible → 1 hour from now
- EOW/end of week → Friday 5:00 PM

TEMPORAL CONTEXT EXTRACTION:
- **Decisions**: Look for when decisions were made ("yesterday we decided", "earlier today")
- **RSVP**: Look for response timing ("I can't make tomorrow's meeting", "I'm in for Friday")
- **Priority**: Look for urgency deadlines ("need by EOD", "urgent, due tomorrow")
- **Conflicts**: Look for when conflicts occur ("conflicts with my 3pm meeting")
- **Calendar Conflicts**: If user_calendar is provided, check for time overlaps with existing events
- **Same Event Detection**: If event titles are similar (>70%) and times overlap, it's likely the same event
- **Alternative Suggestions**: If conflicts exist, suggest nearby available times

DO NOT calculate actual dates - just extract the expression and time!

Analyze the message and use the analyze_message function to return structured results."""

        # Define the function schema for structured output
        functions = [
            {
                "name": "analyze_message",
                "description": "Analyze a message for events, reminders, decisions, RSVP, priority, and conflicts",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "calendar": {
                            "type": "object",
                            "description": "Calendar event detection",
                            "properties": {
                                "detected": {"type": "boolean", "description": "Whether a calendar event was detected"},
                                "title": {"type": "string", "description": "Event title", "nullable": True},
                                "date_expression": {"type": "string", "description": "Temporal expression as-is from message", "nullable": True},
                                "startTime": {"type": "string", "description": "Start time in HH:MM format (24-hour). Examples: 'noon'->12:00, '7pm'->19:00, '4:44pm'->16:44", "nullable": True},
                                "endTime": {"type": "string", "description": "End time in HH:MM format (24-hour). If not specified, leave null to apply 1-hour default", "nullable": True},
                                "location": {"type": "string", "description": "Event location", "nullable": True},
                                "is_invitation": {"type": "boolean", "description": "Whether contains invitation language"}
                            },
                            "required": ["detected", "is_invitation"]
                        },
                        "reminder": {
                            "type": "object",
                            "description": "Reminder detection",
                            "properties": {
                                "detected": {"type": "boolean", "description": "Whether a reminder was detected"},
                                "title": {"type": "string", "description": "Reminder title", "nullable": True},
                                "date_expression": {"type": "string", "description": "Due date expression", "nullable": True}
                            },
                            "required": ["detected"]
                        },
                        "decision": {
                            "type": "object",
                            "description": "Decision detection",
                            "properties": {
                                "detected": {"type": "boolean", "description": "Whether a decision was detected"},
                                "text": {"type": "string", "description": "Complete decision statement", "nullable": True},
                                "temporal_context": {"type": "string", "description": "When the decision was made (e.g., 'yesterday', 'earlier today')", "nullable": True}
                            },
                            "required": ["detected"]
                        },
                        "rsvp": {
                            "type": "object",
                            "description": "RSVP detection",
                            "properties": {
                                "detected": {"type": "boolean", "description": "Whether an RSVP was detected"},
                                "status": {"type": "string", "description": "RSVP status (accepted/declined)", "nullable": True},
                                "event_reference": {"type": "string", "description": "Referenced event", "nullable": True},
                                "temporal_context": {"type": "string", "description": "When the RSVP was given (e.g., 'yesterday', 'just now')", "nullable": True}
                            },
                            "required": ["detected"]
                        },
                        "priority": {
                            "type": "object",
                            "description": "Priority detection",
                            "properties": {
                                "detected": {"type": "boolean", "description": "Whether priority was detected"},
                                "level": {"type": "string", "description": "Priority level (low/medium/high)", "nullable": True},
                                "reason": {"type": "string", "description": "Priority reason", "nullable": True},
                                "deadline_expression": {"type": "string", "description": "When the urgent task is due (e.g., 'by EOD', 'tomorrow')", "nullable": True}
                            },
                            "required": ["detected"]
                        },
                        "conflict": {
                            "type": "object",
                            "description": "Conflict detection with calendar analysis",
                            "properties": {
                                "detected": {"type": "boolean", "description": "Whether conflicts were detected"},
                                "conflicting_events": {"type": "array", "items": {"type": "string"}, "description": "List of conflicting event titles from message"},
                                "calendar_conflicts": {"type": "array", "items": {"type": "object"}, "description": "Conflicts with user's existing calendar events"},
                                "alternatives": {"type": "array", "items": {"type": "object"}, "description": "Suggested alternative times"},
                                "reasoning": {"type": "string", "description": "Brief explanation of conflicts and suggestions"}
                            },
                            "required": ["detected", "conflicting_events", "calendar_conflicts", "alternatives", "reasoning"]
                        }
                    },
                    "required": ["calendar", "reminder", "decision", "rsvp", "priority", "conflict"]
                }
            }
        ]
        
        messages = [{"role": "user", "content": text}]
        
        response = self.chat_completion(
            messages=messages,
            system_prompt=system_prompt,
            temperature=0.2,  # Low temperature for consistent structured output
            functions=functions,
            function_call={"name": "analyze_message"}  # Force function call
        )
        
        # Parse function call response
        try:
            function_call = response.get("function_call")
            if function_call and function_call.name == "analyze_message":
                result = json.loads(function_call.arguments)
                
                # Ensure all required fields are present with defaults
                result = self._ensure_complete_analysis(result)
                
                # POST-PROCESS: Parse date expressions using dateparser
                result = self._parse_date_expressions(result, reference_time, message_timezone)
                
                # CONFLICT DETECTION: Check for calendar conflicts using Pinecone
                if result["calendar"]["detected"]:
                    # Use provided user_id or extract from user_calendar, otherwise use a default
                    conflict_user_id = user_id or "test_user"  # Use provided user_id first
                    if not conflict_user_id and user_calendar and len(user_calendar) > 0:
                        conflict_user_id = user_calendar[0].get("user_id", "test_user")
                    
                    # Check if we have all required fields for conflict detection
                    if result["calendar"]["date"] and result["calendar"]["startTime"] and result["calendar"]["endTime"]:
                        # Check for conflicts using Pinecone
                        conflict_analysis = self._check_calendar_conflicts_pinecone(
                            {
                                "title": result["calendar"]["title"],
                                "date": result["calendar"]["date"],
                                "startTime": result["calendar"]["startTime"],
                                "endTime": result["calendar"]["endTime"],
                                "location": result["calendar"]["location"]
                            },
                            conflict_user_id
                        )
                        
                        # Update conflict section with Pinecone results
                        result["conflict"]["detected"] = conflict_analysis["has_conflicts"]
                        result["conflict"]["conflicting_events"] = conflict_analysis["conflicts"]
                        result["conflict"]["reasoning"] = conflict_analysis["reasoning"]
                        result["conflict"]["same_event_detected"] = conflict_analysis["same_event_detected"]
                        
                        # Update calendar section with similar events
                        result["calendar"]["similar_events"] = conflict_analysis.get("similar_events", [])
                
                return result
            else:
                print(f"Unexpected response format: {response}")
                return self._get_default_analysis()
        except (json.JSONDecodeError, KeyError, AttributeError) as e:
            print(f"Failed to parse function call response: {e}")
            print(f"Response was: {response}")
            return self._get_default_analysis()

    def _get_default_analysis(self) -> Dict[str, Any]:
        """Return default empty analysis structure"""
        return {
            "calendar": {"detected": False, "title": None, "date_expression": None, "startTime": None, "endTime": None, "duration": None, "location": None, "is_invitation": False},
            "reminder": {"detected": False, "title": None, "date_expression": None},
            "decision": {"detected": False, "text": None},
            "rsvp": {"detected": False, "status": None, "event_reference": None},
            "priority": {"detected": False, "level": None, "reason": None},
            "conflict": {
                "detected": False, 
                "conflicting_events": [],
                "calendar_conflicts": [],
                "alternatives": [],
                "reasoning": ""
            }
        }

    def _ensure_complete_analysis(self, result: Dict[str, Any]) -> Dict[str, Any]:
        """Ensure all required fields are present in the analysis result"""
        # Define complete field structure
        complete_structure = {
            "calendar": {
                "detected": False, "title": None, "date_expression": None, 
                "startTime": None, "endTime": None, "duration": None, "location": None, "is_invitation": False
            },
            "reminder": {
                "detected": False, "title": None, "date_expression": None
            },
            "decision": {
                "detected": False, "text": None, "temporal_context": None
            },
            "rsvp": {
                "detected": False, "status": None, "event_reference": None, "temporal_context": None
            },
            "priority": {
                "detected": False, "level": None, "reason": None, "deadline_expression": None
            },
            "conflict": {
                "detected": False, "conflicting_events": []
            }
        }
        
        # Merge result with complete structure, ensuring all fields exist
        for category, fields in complete_structure.items():
            if category not in result:
                result[category] = fields.copy()
            else:
                for field, default_value in fields.items():
                    if field not in result[category]:
                        result[category][field] = default_value
        
        return result

    def _expand_time_acronyms(self, text: str) -> str:
        """
        Expand common time-related acronyms to full phrases for better AI understanding
        
        Args:
            text: Input text that may contain time acronyms
            
        Returns:
            Text with acronyms expanded to full phrases
        """
        # Dictionary of acronyms and their expansions
        acronym_expansions = {
            # Business time acronyms
            'EOD': 'end of day',
            'EOB': 'end of business',
            'COB': 'close of business', 
            'EOW': 'end of week',
            'EOQ': 'end of quarter',
            'EOY': 'end of year',
            
            # Urgency acronyms
            'ASAP': 'as soon as possible',
            'URGENT': 'urgent',
            
            # Time-specific expansions (case-insensitive)
            'eod': 'end of day',
            'eob': 'end of business',
            'cob': 'close of business',
            'eow': 'end of week',
            'asap': 'as soon as possible',
        }
        
        # Apply expansions (case-insensitive)
        expanded_text = text
        for acronym, expansion in acronym_expansions.items():
            # Use word boundaries to avoid partial matches
            import re
            pattern = r'\b' + re.escape(acronym) + r'\b'
            expanded_text = re.sub(pattern, expansion, expanded_text, flags=re.IGNORECASE)
        
        return expanded_text

    def _parse_date_expressions(self, result: Dict[str, Any], reference_time, message_timezone=None) -> Dict[str, Any]:
        """
        Parse date expressions from AI response into actual ISO dates using dateparser
        Enhanced to handle all detection types with temporal elements
        
        Args:
            result: The AI analysis result with date_expression fields
            reference_time: The reference datetime for relative date parsing
            
        Returns:
            Updated result with parsed date fields for all relevant detection types
        """
        import dateparser
        from datetime import timedelta
        
        # Common dateparser settings with timezone awareness
        dateparser_settings = {
            'RELATIVE_BASE': reference_time,
            'PREFER_DATES_FROM': 'future',  # Always interpret as future dates
            'RETURN_AS_TIMEZONE_AWARE': False
        }
        
        # Add timezone context if available
        if message_timezone:
            # Convert timezone offset to a format dateparser understands
            try:
                # Parse timezone offset (e.g., "-07:00" -> -7 hours)
                if message_timezone.startswith('-'):
                    tz_hours = -int(message_timezone[1:3])
                    tz_mins = -int(message_timezone[4:6]) if len(message_timezone) > 4 else 0
                else:
                    tz_hours = int(message_timezone[:2])
                    tz_mins = int(message_timezone[3:5]) if len(message_timezone) > 3 else 0
                
                # Create timezone-aware reference time
                from datetime import timezone, timedelta
                tz_offset = timezone(timedelta(hours=tz_hours, minutes=tz_mins))
                reference_time_tz = reference_time.replace(tzinfo=tz_offset)
                
                # Update settings to use timezone-aware reference
                dateparser_settings['RELATIVE_BASE'] = reference_time_tz
                print(f"🌍 Using timezone-aware reference: {reference_time_tz}")
                
            except Exception as e:
                # Failed to parse timezone, use default reference
                pass
        
        # Parse calendar date expression with enhanced relative date handling
        if result["calendar"]["detected"] and result["calendar"]["date_expression"]:
            date_expr = result["calendar"]["date_expression"]
            
            # Manual mapping for common expressions that dateparser might not handle well
            manual_mappings = {
                "tonight": "today",
                "this evening": "today",
                "this afternoon": "today",
                "this morning": "today"
            }
            
            # Use manual mapping if available
            if date_expr.lower() in manual_mappings:
                date_expr = manual_mappings[date_expr.lower()]
            
            # Enhanced settings for better relative date parsing
            enhanced_settings = dateparser_settings.copy()
            enhanced_settings.update({
                'PREFER_DATES_FROM': 'future',
                'RELATIVE_BASE': reference_time,
                'RETURN_AS_TIMEZONE_AWARE': False,
                'PARSERS': ['relative-time', 'absolute-time', 'timestamp']
            })
            
            # Special handling for "next [day]" expressions
            if date_expr.lower().startswith('next '):
                # Try multiple parsing strategies for "next [day]"
                parsing_attempts = [
                    date_expr,  # Original: "next Tuesday"
                    f"next {date_expr.split(' ', 1)[1]}",  # Ensure "next" prefix
                    f"next {date_expr.split(' ', 1)[1]} from {reference_time.strftime('%Y-%m-%d')}",  # With explicit date
                ]
                
                # Add day-specific attempts
                day_name = date_expr.split(' ', 1)[1].lower() if ' ' in date_expr else ''
                if day_name in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']:
                    # Try different formats
                    parsing_attempts.extend([
                        f"next {day_name}",
                        f"next {day_name} from {reference_time.strftime('%Y-%m-%d')}",
                        f"next {day_name} at 12:00",  # Add time context
                    ])
                
                parsed_date = None
                for attempt in parsing_attempts:
                    try:
                        parsed_date = dateparser.parse(attempt, settings=enhanced_settings)
                        if parsed_date:
                            break
                    except Exception as e:
                        # Continue to next attempt
                        pass
                        continue
                
                # Final fallback: manual calculation for "next [day]"
                if not parsed_date and day_name in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']:
                    try:
                        from datetime import timedelta
                        import calendar
                        
                        # Get current weekday (0=Monday, 6=Sunday)
                        current_weekday = reference_time.weekday()
                        target_weekday = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].index(day_name)
                        
                        # Calculate days until next occurrence
                        days_ahead = target_weekday - current_weekday
                        if days_ahead <= 0:  # Target day is this week or past
                            days_ahead += 7  # Move to next week
                        
                        next_date = reference_time + timedelta(days=days_ahead)
                        parsed_date = next_date
                    except Exception as e:
                        # Manual fallback failed
                        pass
            else:
                parsed_date = dateparser.parse(date_expr, settings=enhanced_settings)
            
            result["calendar"]["date"] = parsed_date.strftime('%Y-%m-%d') if parsed_date else None
        else:
            result["calendar"]["date"] = None
        
        # CRITICAL: Apply 1-hour default duration if endTime not specified
        if result["calendar"]["detected"] and result["calendar"]["startTime"]:
            start_time = result["calendar"]["startTime"]
            end_time = result["calendar"]["endTime"]
            
            # Enhanced time parsing with dateparser for robustness
            start_time = self._parse_time_with_fallback(start_time, reference_time)
            result["calendar"]["startTime"] = start_time
            
            if not end_time:
                # Apply 1-hour default
                try:
                    start_hour, start_minute = map(int, start_time.split(':'))
                    end_hour = (start_hour + 1) % 24
                    end_time = f"{end_hour:02d}:{start_minute:02d}"
                    result["calendar"]["endTime"] = end_time
                except (ValueError, AttributeError) as e:
                    result["calendar"]["endTime"] = None
            else:
                # Parse end time with fallback
                end_time = self._parse_time_with_fallback(end_time, reference_time)
                result["calendar"]["endTime"] = end_time
            
            # Calculate duration in minutes
            if start_time and end_time:
                try:
                    start_hour, start_minute = map(int, start_time.split(':'))
                    end_hour, end_minute = map(int, end_time.split(':'))
                    start_minutes = start_hour * 60 + start_minute
                    end_minutes = end_hour * 60 + end_minute
                    
                    # Handle overnight events (end time is next day)
                    if end_minutes < start_minutes:
                        end_minutes += 24 * 60
                    
                    duration = end_minutes - start_minutes
                    result["calendar"]["duration"] = duration
                except (ValueError, AttributeError) as e:
                    result["calendar"]["duration"] = 60  # Default to 1 hour
        else:
            result["calendar"]["duration"] = None
        
        # Parse reminder date expression
        if result["reminder"]["detected"] and result["reminder"]["date_expression"]:
            date_expr = result["reminder"]["date_expression"]
            parsed_date = dateparser.parse(date_expr, settings=dateparser_settings)
            result["reminder"]["due_date"] = parsed_date.strftime('%Y-%m-%d') if parsed_date else None
        else:
            result["reminder"]["due_date"] = None
        
        # Parse decision timestamp (when the decision was made)
        if result["decision"]["detected"] and result["decision"]["text"]:
            # Use temporal_context if provided by AI, otherwise extract from decision text
            temporal_context = result["decision"].get("temporal_context")
            if temporal_context:
                parsed_date = dateparser.parse(temporal_context, settings=dateparser_settings)
                result["decision"]["timestamp"] = parsed_date.strftime('%Y-%m-%d %H:%M:%S') if parsed_date else reference_time.strftime('%Y-%m-%d %H:%M:%S')
            else:
                # Fallback: look for temporal indicators in decision text
                decision_text = result["decision"]["text"]
                temporal_indicators = ["yesterday", "today", "earlier", "just now", "recently", "earlier today"]
                for indicator in temporal_indicators:
                    if indicator in decision_text.lower():
                        parsed_date = dateparser.parse(indicator, settings=dateparser_settings)
                        if parsed_date:
                            result["decision"]["timestamp"] = parsed_date.strftime('%Y-%m-%d %H:%M:%S')
                            break
                else:
                    # Default to current time if no temporal context found
                    result["decision"]["timestamp"] = reference_time.strftime('%Y-%m-%d %H:%M:%S')
        else:
            result["decision"]["timestamp"] = None
        
        # Parse RSVP timestamp (when the response was given)
        if result["rsvp"]["detected"]:
            # Use temporal_context if provided by AI
            temporal_context = result["rsvp"].get("temporal_context")
            if temporal_context:
                parsed_date = dateparser.parse(temporal_context, settings=dateparser_settings)
                result["rsvp"]["timestamp"] = parsed_date.strftime('%Y-%m-%d %H:%M:%S') if parsed_date else reference_time.strftime('%Y-%m-%d %H:%M:%S')
            else:
                # Fallback: check for temporal context in status
                rsvp_text = result["rsvp"]["status"] or ""
                if any(word in rsvp_text.lower() for word in ["yesterday", "earlier", "just now"]):
                    parsed_date = dateparser.parse(rsvp_text, settings=dateparser_settings)
                    result["rsvp"]["timestamp"] = parsed_date.strftime('%Y-%m-%d %H:%M:%S') if parsed_date else reference_time.strftime('%Y-%m-%d %H:%M:%S')
                else:
                    result["rsvp"]["timestamp"] = reference_time.strftime('%Y-%m-%d %H:%M:%S')
        else:
            result["rsvp"]["timestamp"] = None
        
        # Parse priority deadline (when the urgent task is due)
        if result["priority"]["detected"] and result["priority"]["level"] in ["high", "medium"]:
            # Use deadline_expression if provided by AI
            deadline_expression = result["priority"].get("deadline_expression")
            if deadline_expression:
                parsed_date = dateparser.parse(deadline_expression, settings=dateparser_settings)
                result["priority"]["deadline"] = parsed_date.strftime('%Y-%m-%d %H:%M:%S') if parsed_date else None
            else:
                # Fallback: look for deadline indicators in reason
                priority_text = result["priority"]["reason"] or ""
                deadline_indicators = ["by", "before", "until", "deadline", "due"]
                for indicator in deadline_indicators:
                    if indicator in priority_text.lower():
                        # Try to extract and parse the deadline
                        import re
                        deadline_match = re.search(rf'{indicator}\s+([^,\.]+)', priority_text, re.IGNORECASE)
                        if deadline_match:
                            deadline_expr = deadline_match.group(1).strip()
                            parsed_date = dateparser.parse(deadline_expr, settings=dateparser_settings)
                            if parsed_date:
                                result["priority"]["deadline"] = parsed_date.strftime('%Y-%m-%d %H:%M:%S')
                                break
                else:
                    # Default deadline based on priority level
                    if result["priority"]["level"] == "high":
                        # High priority: 1 hour from now
                        deadline = reference_time + timedelta(hours=1)
                        result["priority"]["deadline"] = deadline.strftime('%Y-%m-%d %H:%M:%S')
                    elif result["priority"]["level"] == "medium":
                        # Medium priority: end of day
                        from datetime import datetime, time
                        eod = datetime.combine(reference_time.date(), time(23, 59, 59))
                        result["priority"]["deadline"] = eod.strftime('%Y-%m-%d %H:%M:%S')
                    else:
                        result["priority"]["deadline"] = None
        else:
            result["priority"]["deadline"] = None
        
        # Parse conflict timestamps (when conflicts occur)
        if result["conflict"]["detected"] and result["conflict"]["conflicting_events"]:
            # Conflicts are typically about future events, so use current time as reference
            result["conflict"]["detected_at"] = reference_time.strftime('%Y-%m-%d %H:%M:%S')
        else:
            result["conflict"]["detected_at"] = None
        
        return result
    
    def _parse_time_with_fallback(self, time_str: str, reference_time) -> str:
        """
        Parse time string with fallback using dateparser for robustness
        Handles problematic times like "noon", "7pm", "4:44pm"
        
        Args:
            time_str: Time string to parse
            reference_time: Reference datetime for context
            
        Returns:
            Time in HH:MM format (24-hour)
        """
        import dateparser
        
        # If already in HH:MM format, return as is
        if time_str and ':' in time_str and len(time_str.split(':')[0]) <= 2:
            try:
                parts = time_str.split(':')
                hour = int(parts[0])
                minute = int(parts[1])
                if 0 <= hour <= 23 and 0 <= minute <= 59:
                    return f"{hour:02d}:{minute:02d}"
            except (ValueError, IndexError):
                pass
        
        # Use dateparser for natural language times
        try:
            parsed = dateparser.parse(
                time_str,
                settings={
                    'RELATIVE_BASE': reference_time,
                    'PREFER_DATES_FROM': 'future',
                    'RETURN_AS_TIMEZONE_AWARE': False
                }
            )
            if parsed:
                return parsed.strftime('%H:%M')
        except Exception as e:
            # dateparser failed, continue with fallback
            pass
        
        # Fallback: Handle common vague time expressions
        if time_str:
            # Normalize the time string
            time_lower = time_str.lower().strip()
            
            # Handle compound expressions like "in the evening"
            if 'evening' in time_lower:
                return '19:00'  # 7pm
            elif 'morning' in time_lower:
                return '09:00'  # 9am
            elif 'afternoon' in time_lower:
                return '15:00'  # 3pm
            elif 'night' in time_lower:
                return '20:00'  # 8pm
            elif 'late' in time_lower:
                return '22:00'  # 10pm
            elif 'early' in time_lower:
                return '08:00'  # 8am
            elif 'noon' in time_lower:
                return '12:00'  # 12pm
            elif 'midnight' in time_lower:
                return '00:00'  # 12am
            
            # Simple mappings
            vague_times = {
                'evening': '19:00',
                'morning': '09:00',
                'afternoon': '15:00',
                'night': '20:00',
                'late': '22:00',
                'early': '08:00',
                'noon': '12:00',
                'midnight': '00:00'
            }
            return vague_times.get(time_lower, time_str)
        
        return None
    
    def _check_calendar_conflicts_pinecone(self, detected_event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
        """
        Check for calendar conflicts using Pinecone
        
        Args:
            detected_event: Event detected by AI analysis
            user_id: User ID to search within
            
        Returns:
            Dictionary with conflict analysis
        """
        try:
            from app.services.event_indexing_service import get_event_indexing_service
            
            event_service = get_event_indexing_service()
            result = event_service.search_conflicts(detected_event, user_id)
            return result
            
        except Exception as e:
            # Log error but don't print traceback in production
            return {
                "has_conflicts": False,
                "conflicts": [],
                "same_event_detected": False,
                "similar_events": [],
                "reasoning": f"Conflict detection unavailable: {str(e)}"
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



