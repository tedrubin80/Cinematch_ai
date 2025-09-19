"""
TMDb (The Movie Database) API Client with graceful fallback
"""

import os
import logging
import requests
from typing import Dict, Optional, Any, List
import psycopg2
from psycopg2.extras import RealDictCursor
import json
from datetime import datetime

logger = logging.getLogger(__name__)

class TMDbClient:
    """Optional TMDb API client with fallback to scraped data"""
    
    BASE_URL = "https://api.themoviedb.org/3"
    IMAGE_BASE_URL = "https://image.tmdb.org/t/p/w500"
    
    def __init__(self, db_config: Optional[Dict[str, str]] = None):
        """
        Initialize TMDb client
        
        Args:
            db_config: Database configuration for fallback to scraped data
        """
        self.api_key = os.getenv('TMDB_API_KEY', '').strip()
        self.read_access_token = os.getenv('TMDB_READ_ACCESS_TOKEN', '').strip()
        self.enabled = bool(self.api_key) or bool(self.read_access_token)
        self.db_config = db_config
        
        # Set up headers for bearer token auth
        self.headers = {}
        if self.read_access_token:
            self.headers['Authorization'] = f'Bearer {self.read_access_token}'
        
        if self.enabled:
            auth_method = "Bearer token" if self.read_access_token else "API key"
            logger.info(f"TMDb API enabled with {auth_method}")
        else:
            logger.info("TMDb API disabled - will use scraped data")
    
    def search_movies(self, query: str, year: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Search for movies
        
        Args:
            query: Search query
            year: Optional year filter
            
        Returns:
            List of movie results
        """
        if self.enabled:
            try:
                params = {
                    'query': query,
                    'include_adult': False
                }
                
                # Use API key if no bearer token
                if not self.read_access_token and self.api_key:
                    params['api_key'] = self.api_key
                
                if year:
                    params['year'] = year
                
                response = requests.get(f"{self.BASE_URL}/search/movie", params=params, headers=self.headers, timeout=5)
                response.raise_for_status()
                
                data = response.json()
                return [self._format_movie_result(movie) for movie in data.get('results', [])]
                
            except Exception as e:
                logger.warning(f"TMDb API search error for '{query}': {e}")
        
        # Fall back to scraped data
        return self._search_scraped_data(query, year)
    
    def get_movie_details(self, movie_id: int) -> Optional[Dict[str, Any]]:
        """
        Get detailed movie information
        
        Args:
            movie_id: TMDb movie ID
            
        Returns:
            Detailed movie information
        """
        if self.enabled:
            try:
                params = {
                    'append_to_response': 'credits,videos,similar'
                }
                
                # Use API key if no bearer token
                if not self.read_access_token and self.api_key:
                    params['api_key'] = self.api_key
                
                response = requests.get(f"{self.BASE_URL}/movie/{movie_id}", params=params, headers=self.headers, timeout=5)
                response.raise_for_status()
                
                return self._format_movie_details(response.json())
                
            except Exception as e:
                logger.warning(f"TMDb API detail error for movie ID {movie_id}: {e}")
        
        return None
    
    def get_trending_movies(self, time_window: str = "week") -> List[Dict[str, Any]]:
        """
        Get trending movies
        
        Args:
            time_window: 'day' or 'week'
            
        Returns:
            List of trending movies
        """
        if self.enabled:
            try:
                params = {}
                
                # Use API key if no bearer token
                if not self.read_access_token and self.api_key:
                    params['api_key'] = self.api_key
                
                response = requests.get(
                    f"{self.BASE_URL}/trending/movie/{time_window}", 
                    params=params,
                    headers=self.headers,
                    timeout=5
                )
                response.raise_for_status()
                
                data = response.json()
                return [self._format_movie_result(movie) for movie in data.get('results', [])]
                
            except Exception as e:
                logger.warning(f"TMDb API trending error: {e}")
        
        # Fall back to recent popular movies from scraped data
        return self._get_recent_popular_from_scraped()
    
    def get_recommendations(self, movie_id: int) -> List[Dict[str, Any]]:
        """
        Get movie recommendations based on a movie
        
        Args:
            movie_id: TMDb movie ID
            
        Returns:
            List of recommended movies
        """
        if self.enabled:
            try:
                params = {}
                
                # Use API key if no bearer token
                if not self.read_access_token and self.api_key:
                    params['api_key'] = self.api_key
                
                response = requests.get(
                    f"{self.BASE_URL}/movie/{movie_id}/recommendations", 
                    params=params,
                    headers=self.headers,
                    timeout=5
                )
                response.raise_for_status()
                
                data = response.json()
                return [self._format_movie_result(movie) for movie in data.get('results', [])]
                
            except Exception as e:
                logger.warning(f"TMDb API recommendations error for movie {movie_id}: {e}")
        
        return []
    
    def _format_movie_result(self, movie: Dict[str, Any]) -> Dict[str, Any]:
        """Format TMDb search result to standard format"""
        return {
            'source': 'TMDb API',
            'tmdb_id': movie.get('id'),
            'title': movie.get('title'),
            'original_title': movie.get('original_title'),
            'year': int(movie.get('release_date', '')[:4]) if movie.get('release_date') else None,
            'overview': movie.get('overview'),
            'poster_path': f"{self.IMAGE_BASE_URL}{movie.get('poster_path')}" if movie.get('poster_path') else None,
            'backdrop_path': f"{self.IMAGE_BASE_URL}{movie.get('backdrop_path')}" if movie.get('backdrop_path') else None,
            'popularity': movie.get('popularity'),
            'vote_average': movie.get('vote_average'),
            'vote_count': movie.get('vote_count'),
            'adult': movie.get('adult', False)
        }
    
    def _format_movie_details(self, movie: Dict[str, Any]) -> Dict[str, Any]:
        """Format TMDb movie details to standard format"""
        # Extract director and cast
        credits = movie.get('credits', {})
        crew = credits.get('crew', [])
        cast = credits.get('cast', [])
        
        directors = [person['name'] for person in crew if person.get('job') == 'Director']
        actors = [person['name'] for person in cast[:5]]  # Top 5 actors
        
        # Extract trailer
        videos = movie.get('videos', {}).get('results', [])
        trailer = next((v for v in videos if v.get('type') == 'Trailer' and v.get('site') == 'YouTube'), None)
        
        return {
            'source': 'TMDb API',
            'tmdb_id': movie.get('id'),
            'imdb_id': movie.get('imdb_id'),
            'title': movie.get('title'),
            'original_title': movie.get('original_title'),
            'year': int(movie.get('release_date', '')[:4]) if movie.get('release_date') else None,
            'release_date': movie.get('release_date'),
            'runtime': movie.get('runtime'),
            'genres': [g['name'] for g in movie.get('genres', [])],
            'overview': movie.get('overview'),
            'tagline': movie.get('tagline'),
            'directors': directors,
            'cast': actors,
            'budget': movie.get('budget'),
            'revenue': movie.get('revenue'),
            'poster_path': f"{self.IMAGE_BASE_URL}{movie.get('poster_path')}" if movie.get('poster_path') else None,
            'backdrop_path': f"{self.IMAGE_BASE_URL}{movie.get('backdrop_path')}" if movie.get('backdrop_path') else None,
            'popularity': movie.get('popularity'),
            'vote_average': movie.get('vote_average'),
            'vote_count': movie.get('vote_count'),
            'trailer_youtube_key': trailer.get('key') if trailer else None,
            'production_companies': [c['name'] for c in movie.get('production_companies', [])],
            'production_countries': [c['name'] for c in movie.get('production_countries', [])],
            'spoken_languages': [l['english_name'] for l in movie.get('spoken_languages', [])]
        }
    
    def _search_scraped_data(self, query: str, year: Optional[int] = None) -> List[Dict[str, Any]]:
        """Search scraped data for movies"""
        if not self.db_config:
            return []
        
        try:
            conn = psycopg2.connect(**self.db_config)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Search with flexible matching
                if year:
                    cur.execute("""
                        SELECT DISTINCT ON (movie_title) * FROM scraped_movie_data 
                        WHERE movie_title ILIKE %s 
                        AND year = %s
                        ORDER BY movie_title, scraped_at DESC
                        LIMIT 20
                    """, (f"%{query}%", year))
                else:
                    cur.execute("""
                        SELECT DISTINCT ON (movie_title) * FROM scraped_movie_data 
                        WHERE movie_title ILIKE %s
                        ORDER BY movie_title, scraped_at DESC
                        LIMIT 20
                    """, (f"%{query}%",))
                
                results = cur.fetchall()
                return [self._format_scraped_result(r) for r in results]
                
        except Exception as e:
            logger.error(f"Error searching scraped data: {e}")
        
        return []
    
    def _get_recent_popular_from_scraped(self) -> List[Dict[str, Any]]:
        """Get recent popular movies from scraped data"""
        if not self.db_config:
            return []
        
        try:
            conn = psycopg2.connect(**self.db_config)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get recent box office or award winners
                cur.execute("""
                    SELECT DISTINCT ON (movie_title) * FROM scraped_movie_data 
                    WHERE data_type IN ('box_office', 'award', 'festival_award')
                    AND year >= EXTRACT(YEAR FROM CURRENT_DATE) - 2
                    ORDER BY movie_title, scraped_at DESC
                    LIMIT 20
                """)
                
                results = cur.fetchall()
                return [self._format_scraped_result(r) for r in results]
                
        except Exception as e:
            logger.error(f"Error getting recent popular from scraped: {e}")
        
        return []
    
    def _format_scraped_result(self, result: Dict[str, Any]) -> Dict[str, Any]:
        """Format scraped data result"""
        processed = result.get('processed_data', {})
        if isinstance(processed, str):
            processed = json.loads(processed)
        
        return {
            'source': f"Scraped from {result.get('source_site', 'Unknown')}",
            'title': result.get('movie_title'),
            'year': result.get('year'),
            **processed
        }
    
    def is_available(self) -> bool:
        """Check if TMDb API is available"""
        return self.enabled
    
    def get_data_source(self) -> str:
        """Get current data source being used"""
        return "TMDb API" if self.enabled else "Scraped Wikipedia/Web Data"