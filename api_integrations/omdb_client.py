"""
OMDB API Client with graceful fallback to scraped data
"""

import os
import logging
import requests
from typing import Dict, Optional, Any
import psycopg2
from psycopg2.extras import RealDictCursor
import json

logger = logging.getLogger(__name__)

class OMDBClient:
    """Optional OMDB API client with fallback to scraped data"""
    
    BASE_URL = "http://www.omdbapi.com/"
    POSTER_URL = "http://img.omdbapi.com/"
    
    def __init__(self, db_config: Optional[Dict[str, str]] = None):
        """
        Initialize OMDB client
        
        Args:
            db_config: Database configuration for fallback to scraped data
        """
        self.api_key = os.getenv('OMDB_API_KEY', '').strip()
        self.enabled = bool(self.api_key)
        self.db_config = db_config
        
        if self.enabled:
            logger.info("OMDB API enabled with API key")
        else:
            logger.info("OMDB API disabled - will use scraped data")
    
    def search_movie(self, title: str, year: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """
        Search for a movie by title
        
        Args:
            title: Movie title to search for
            year: Optional year to narrow search
            
        Returns:
            Movie data dictionary or None if not found
        """
        # Try API first if enabled
        if self.enabled:
            try:
                params = {
                    'apikey': self.api_key,
                    't': title,
                    'type': 'movie',
                    'plot': 'full'
                }
                
                if year:
                    params['y'] = str(year)
                
                response = requests.get(self.BASE_URL, params=params, timeout=5)
                response.raise_for_status()
                
                data = response.json()
                if data.get('Response') == 'True':
                    return self._format_api_response(data)
                    
            except Exception as e:
                logger.warning(f"OMDB API error for '{title}': {e}")
        
        # Fall back to scraped data
        return self._get_from_scraped_data(title, year)
    
    def get_movie_by_imdb_id(self, imdb_id: str) -> Optional[Dict[str, Any]]:
        """
        Get movie by IMDB ID
        
        Args:
            imdb_id: IMDB ID of the movie
            
        Returns:
            Movie data dictionary or None if not found
        """
        if self.enabled:
            try:
                params = {
                    'apikey': self.api_key,
                    'i': imdb_id,
                    'plot': 'full'
                }
                
                response = requests.get(self.BASE_URL, params=params, timeout=5)
                response.raise_for_status()
                
                data = response.json()
                if data.get('Response') == 'True':
                    return self._format_api_response(data)
                    
            except Exception as e:
                logger.warning(f"OMDB API error for IMDB ID '{imdb_id}': {e}")
        
        # Fall back to scraped data (search by title from IMDB ID if possible)
        return None
    
    def get_poster(self, imdb_id: str, height: int = 600) -> Optional[str]:
        """
        Get high-resolution movie poster URL
        
        Args:
            imdb_id: IMDB ID of the movie
            height: Desired poster height (default 600px)
            
        Returns:
            Poster URL or None if not available
        """
        if self.enabled:
            try:
                params = {
                    'apikey': self.api_key,
                    'i': imdb_id,
                    'h': height
                }
                
                # Build poster URL
                poster_url = f"{self.POSTER_URL}?i={imdb_id}&h={height}&apikey={self.api_key}"
                
                # Verify poster exists with a HEAD request
                response = requests.head(poster_url, timeout=5)
                if response.status_code == 200:
                    return poster_url
                    
            except Exception as e:
                logger.warning(f"OMDB Poster API error for '{imdb_id}': {e}")
        
        return None
    
    def _format_api_response(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Format OMDB API response to standard format"""
        return {
            'source': 'OMDB API',
            'title': data.get('Title'),
            'year': int(data.get('Year', '0')[:4]) if data.get('Year') else None,
            'rated': data.get('Rated'),
            'released': data.get('Released'),
            'runtime': data.get('Runtime'),
            'genre': data.get('Genre'),
            'director': data.get('Director'),
            'writer': data.get('Writer'),
            'actors': data.get('Actors'),
            'plot': data.get('Plot'),
            'language': data.get('Language'),
            'country': data.get('Country'),
            'awards': data.get('Awards'),
            'poster': data.get('Poster'),
            'ratings': {
                'imdb': data.get('imdbRating'),
                'metascore': data.get('Metascore'),
                'imdb_votes': data.get('imdbVotes')
            },
            'box_office': data.get('BoxOffice'),
            'production': data.get('Production'),
            'imdb_id': data.get('imdbID')
        }
    
    def _get_from_scraped_data(self, title: str, year: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """
        Get movie data from scraped database
        
        Args:
            title: Movie title to search for
            year: Optional year to narrow search
            
        Returns:
            Movie data from scraped sources or None
        """
        if not self.db_config:
            return None
        
        try:
            conn = psycopg2.connect(**self.db_config)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Search for movie in scraped data
                if year:
                    cur.execute("""
                        SELECT * FROM scraped_movie_data 
                        WHERE LOWER(movie_title) = LOWER(%s) 
                        AND year = %s
                        AND data_type IN ('film_details', 'box_office', 'award')
                        ORDER BY scraped_at DESC
                        LIMIT 1
                    """, (title, year))
                else:
                    cur.execute("""
                        SELECT * FROM scraped_movie_data 
                        WHERE LOWER(movie_title) = LOWER(%s)
                        AND data_type IN ('film_details', 'box_office', 'award')
                        ORDER BY scraped_at DESC
                        LIMIT 1
                    """, (title,))
                
                result = cur.fetchone()
                if result:
                    # Format scraped data to match expected structure
                    processed = result.get('processed_data', {})
                    if isinstance(processed, str):
                        processed = json.loads(processed)
                    
                    return {
                        'source': f"Scraped from {result.get('source_site', 'Unknown')}",
                        'title': result.get('movie_title'),
                        'year': result.get('year'),
                        **processed,
                        'scraped_at': result.get('scraped_at').isoformat() if result.get('scraped_at') else None
                    }
                    
        except Exception as e:
            logger.error(f"Error fetching scraped data for '{title}': {e}")
        
        return None
    
    def is_available(self) -> bool:
        """Check if OMDB API is available"""
        return self.enabled
    
    def get_data_source(self) -> str:
        """Get current data source being used"""
        return "OMDB API" if self.enabled else "Scraped Wikipedia/Web Data"