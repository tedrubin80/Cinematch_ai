"""
API Integrations Module for Cinematch
Provides optional API clients that gracefully fall back to scraped data
"""

from .omdb_client import OMDBClient
from .tmdb_client import TMDbClient
from .youtube_client import YouTubeClient
from .wikipedia_api import WikipediaAPI
from .gemini_client import GeminiClient
from .llama_client import LlamaClient

__all__ = ['OMDBClient', 'TMDbClient', 'YouTubeClient', 'WikipediaAPI', 'GeminiClient', 'LlamaClient']