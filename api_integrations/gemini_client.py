"""
Google Gemini API Client for advanced AI capabilities
"""

import os
import logging
import requests
from typing import Dict, Optional, Any, List
import json

logger = logging.getLogger(__name__)

class GeminiClient:
    """Google Gemini API client for AI-powered responses"""
    
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    
    def __init__(self):
        """Initialize Gemini client"""
        self.api_key = os.getenv('GEMINI_API_KEY', '').strip()
        self.enabled = bool(self.api_key)
        
        if self.enabled:
            logger.info("Gemini API enabled with API key")
        else:
            logger.info("Gemini API disabled - no key provided")
    
    def generate_content(self, prompt: str, model: str = "gemini-2.0-flash") -> Optional[Dict[str, Any]]:
        """
        Generate content using Gemini model
        
        Args:
            prompt: Text prompt for generation
            model: Model to use (default: gemini-2.0-flash)
            
        Returns:
            Generated content dictionary or None
        """
        if not self.enabled:
            return None
        
        try:
            url = f"{self.BASE_URL}/models/{model}:generateContent"
            
            headers = {
                'Content-Type': 'application/json',
                'X-goog-api-key': self.api_key
            }
            
            payload = {
                "contents": [
                    {
                        "parts": [
                            {
                                "text": prompt
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract the generated text
            candidates = data.get('candidates', [])
            if candidates:
                content = candidates[0].get('content', {})
                parts = content.get('parts', [])
                if parts:
                    return {
                        'source': 'Gemini API',
                        'model': model,
                        'text': parts[0].get('text', ''),
                        'full_response': data
                    }
            
            return None
            
        except Exception as e:
            logger.error(f"Gemini API error: {e}")
            return None
    
    def analyze_movie_query(self, query: str, movie_data: Dict[str, Any]) -> Optional[str]:
        """
        Use Gemini to analyze a movie query and provide intelligent response
        
        Args:
            query: User's movie query
            movie_data: Available movie data from APIs
            
        Returns:
            AI-generated response or None
        """
        if not self.enabled:
            return None
        
        # Create a comprehensive prompt
        prompt = f"""
        As a knowledgeable movie expert, please analyze this user query and provide a helpful response using the available movie data.

        User Query: "{query}"

        Available Movie Data:
        {json.dumps(movie_data, indent=2)}

        Please provide a conversational, engaging response that:
        1. Directly answers the user's question
        2. Uses specific details from the movie data
        3. Adds interesting insights or context
        4. Maintains a friendly, enthusiastic tone
        5. Keeps the response concise but informative

        Response:
        """
        
        result = self.generate_content(prompt)
        return result.get('text') if result else None
    
    def create_movie_summary(self, movie_data: Dict[str, Any]) -> Optional[str]:
        """
        Generate an engaging movie summary using Gemini
        
        Args:
            movie_data: Movie information from various APIs
            
        Returns:
            AI-generated movie summary
        """
        if not self.enabled:
            return None
        
        prompt = f"""
        Create an engaging, informative movie summary based on this data:

        {json.dumps(movie_data, indent=2)}

        Please write a compelling summary that:
        1. Captures the essence of the film
        2. Highlights key cast and crew
        3. Mentions critical reception and box office performance
        4. Includes interesting trivia or context
        5. Uses an enthusiastic but professional tone
        6. Is 2-3 paragraphs long

        Movie Summary:
        """
        
        result = self.generate_content(prompt)
        return result.get('text') if result else None
    
    def get_recommendation_rationale(self, user_preferences: str, recommended_movie: Dict[str, Any]) -> Optional[str]:
        """
        Generate explanation for why a movie is recommended
        
        Args:
            user_preferences: User's stated preferences or mood
            recommended_movie: Movie being recommended
            
        Returns:
            AI-generated recommendation explanation
        """
        if not self.enabled:
            return None
        
        prompt = f"""
        A user has expressed these preferences: "{user_preferences}"

        We're recommending this movie:
        {json.dumps(recommended_movie, indent=2)}

        Please explain in 2-3 sentences why this movie is a perfect match for their preferences. 
        Be specific about elements that align with what they're looking for.
        Use an enthusiastic, personalized tone.

        Recommendation Rationale:
        """
        
        result = self.generate_content(prompt)
        return result.get('text') if result else None
    
    def is_available(self) -> bool:
        """Check if Gemini API is available"""
        return self.enabled
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get information about available models"""
        if not self.enabled:
            return {}
        
        try:
            url = f"{self.BASE_URL}/models"
            headers = {'X-goog-api-key': self.api_key}
            
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            logger.error(f"Error getting Gemini model info: {e}")
            return {}
    
    def get_data_source(self) -> str:
        """Get current data source being used"""
        return "Google Gemini API" if self.enabled else "Not available"