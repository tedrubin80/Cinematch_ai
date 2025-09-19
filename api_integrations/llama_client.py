"""
Meta Llama API Client for advanced AI capabilities
"""

import os
import logging
import requests
from typing import Dict, Optional, Any, List
import json

logger = logging.getLogger(__name__)

class LlamaClient:
    """Meta Llama API client for AI-powered responses"""
    
    BASE_URL = "https://api.llama.com/v1"
    
    def __init__(self):
        """Initialize Llama client"""
        self.api_key = os.getenv('LLAMA_API_KEY', '').strip()
        self.enabled = bool(self.api_key)
        
        if self.enabled:
            logger.info("Llama API enabled with API key")
        else:
            logger.info("Llama API disabled - no key provided")
    
    def chat_completion(self, messages: List[Dict[str, str]], model: str = "Llama-4-Maverick-17B-128E-Instruct-FP8") -> Optional[Dict[str, Any]]:
        """
        Generate chat completion using Llama model
        
        Args:
            messages: List of message dictionaries with 'role' and 'content'
            model: Model to use (default: Llama-4-Maverick-17B-128E-Instruct-FP8)
            
        Returns:
            Chat completion response or None
        """
        if not self.enabled:
            return None
        
        try:
            url = f"{self.BASE_URL}/chat/completions"
            
            headers = {
                'Authorization': f'Bearer {self.api_key}',
                'Content-Type': 'application/json'
            }
            
            payload = {
                "model": model,
                "messages": messages
            }
            
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract the response content (Llama API format)
            completion_message = data.get('completion_message', {})
            if completion_message:
                content = completion_message.get('content', {})
                if isinstance(content, dict):
                    text = content.get('text', '')
                else:
                    text = str(content)
                
                return {
                    'source': 'Llama API',
                    'model': model,
                    'content': text,
                    'role': completion_message.get('role', 'assistant'),
                    'stop_reason': completion_message.get('stop_reason'),
                    'metrics': data.get('metrics', []),
                    'full_response': data
                }
            
            return None
            
        except Exception as e:
            logger.error(f"Llama API error: {e}")
            return None
    
    def analyze_movie_query(self, query: str, movie_data: Dict[str, Any]) -> Optional[str]:
        """
        Use Llama to analyze a movie query and provide intelligent response
        
        Args:
            query: User's movie query
            movie_data: Available movie data from APIs
            
        Returns:
            AI-generated response or None
        """
        if not self.enabled:
            return None
        
        # Create messages in the expected format
        messages = [
            {
                "role": "system",
                "content": "You are a knowledgeable and enthusiastic movie expert. Provide engaging, informative responses about movies using the provided data. Keep responses conversational and include specific details from the movie data."
            },
            {
                "role": "user",
                "content": f"""
User Query: "{query}"

Available Movie Data:
{json.dumps(movie_data, indent=2)}

Please provide a helpful, engaging response that directly answers the user's question using the movie data provided. Be specific and enthusiastic about the movie details.
"""
            }
        ]
        
        result = self.chat_completion(messages)
        return result.get('content') if result else None
    
    def create_movie_recommendation(self, user_preferences: str, movie_data: Dict[str, Any]) -> Optional[str]:
        """
        Generate a movie recommendation explanation using Llama
        
        Args:
            user_preferences: User's stated preferences or mood
            movie_data: Movie information from various APIs
            
        Returns:
            AI-generated recommendation
        """
        if not self.enabled:
            return None
        
        messages = [
            {
                "role": "system",
                "content": "You are an expert movie recommender. Create compelling recommendations that match user preferences with specific movie details. Be enthusiastic and persuasive while being informative."
            },
            {
                "role": "user",
                "content": f"""
User Preferences: "{user_preferences}"

Movie to Recommend:
{json.dumps(movie_data, indent=2)}

Please create a compelling recommendation that explains why this movie is perfect for someone with these preferences. Include specific details about cast, plot, ratings, and what makes it special.
"""
            }
        ]
        
        result = self.chat_completion(messages)
        return result.get('content') if result else None
    
    def generate_movie_summary(self, movie_data: Dict[str, Any]) -> Optional[str]:
        """
        Generate an engaging movie summary using Llama
        
        Args:
            movie_data: Movie information from various APIs
            
        Returns:
            AI-generated movie summary
        """
        if not self.enabled:
            return None
        
        messages = [
            {
                "role": "system",
                "content": "You are a film critic and entertainment writer. Create engaging, informative movie summaries that capture the essence of films. Include key details about cast, plot, critical reception, and cultural impact."
            },
            {
                "role": "user",
                "content": f"""
Create an engaging summary for this movie:

{json.dumps(movie_data, indent=2)}

Write a 2-3 paragraph summary that would help someone decide whether to watch this film. Include cast, director, plot overview, and what makes it noteworthy.
"""
            }
        ]
        
        result = self.chat_completion(messages)
        return result.get('content') if result else None
    
    def simple_query(self, prompt: str) -> Optional[str]:
        """
        Simple query to Llama API
        
        Args:
            prompt: Simple text prompt
            
        Returns:
            AI response or None
        """
        if not self.enabled:
            return None
        
        messages = [
            {
                "role": "system",
                "content": "You are a helpful and friendly assistant."
            },
            {
                "role": "user",
                "content": prompt
            }
        ]
        
        result = self.chat_completion(messages)
        return result.get('content') if result else None
    
    def is_available(self) -> bool:
        """Check if Llama API is available"""
        return self.enabled
    
    def get_data_source(self) -> str:
        """Get current data source being used"""
        return "Meta Llama API" if self.enabled else "Not available"