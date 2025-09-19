"""
YouTube API Client for movie trailers and related content
"""

import os
import logging
import requests
from typing import Dict, Optional, Any, List
import psycopg2
from psycopg2.extras import RealDictCursor
import json

logger = logging.getLogger(__name__)

class YouTubeClient:
    """Optional YouTube API client for movie trailers"""
    
    BASE_URL = "https://www.googleapis.com/youtube/v3"
    
    def __init__(self, db_config: Optional[Dict[str, str]] = None):
        """
        Initialize YouTube client
        
        Args:
            db_config: Database configuration for fallback
        """
        self.api_key = os.getenv('YOUTUBE_API_KEY', '').strip()
        self.enabled = bool(self.api_key)
        self.db_config = db_config
        
        if self.enabled:
            logger.info("YouTube API enabled with API key")
        else:
            logger.info("YouTube API disabled - will use scraped trailer links")
    
    def search_movie_trailer(self, movie_title: str, year: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """
        Search for movie trailer
        
        Args:
            movie_title: Movie title
            year: Optional release year
            
        Returns:
            Trailer information or None
        """
        if self.enabled:
            try:
                query = f"{movie_title} {year if year else ''} official trailer"
                
                params = {
                    'key': self.api_key,
                    'q': query,
                    'part': 'snippet',
                    'type': 'video',
                    'maxResults': 5,
                    'videoCategoryId': '1'  # Film & Animation
                }
                
                response = requests.get(f"{self.BASE_URL}/search", params=params, timeout=5)
                response.raise_for_status()
                
                data = response.json()
                items = data.get('items', [])
                
                # Find the most relevant trailer
                for item in items:
                    snippet = item.get('snippet', {})
                    title = snippet.get('title', '').lower()
                    
                    # Check if it's likely a trailer
                    if 'trailer' in title and ('official' in title or 'hd' in title):
                        return {
                            'source': 'YouTube API',
                            'video_id': item.get('id', {}).get('videoId'),
                            'title': snippet.get('title'),
                            'description': snippet.get('description'),
                            'channel': snippet.get('channelTitle'),
                            'published_at': snippet.get('publishedAt'),
                            'thumbnail': snippet.get('thumbnails', {}).get('high', {}).get('url'),
                            'url': f"https://www.youtube.com/watch?v={item.get('id', {}).get('videoId')}"
                        }
                
                # Return first result if no "official" trailer found
                if items:
                    item = items[0]
                    snippet = item.get('snippet', {})
                    return {
                        'source': 'YouTube API',
                        'video_id': item.get('id', {}).get('videoId'),
                        'title': snippet.get('title'),
                        'description': snippet.get('description'),
                        'channel': snippet.get('channelTitle'),
                        'published_at': snippet.get('publishedAt'),
                        'thumbnail': snippet.get('thumbnails', {}).get('high', {}).get('url'),
                        'url': f"https://www.youtube.com/watch?v={item.get('id', {}).get('videoId')}"
                    }
                    
            except Exception as e:
                logger.warning(f"YouTube API error searching trailer for '{movie_title}': {e}")
        
        # Fall back to scraped trailer links
        return self._get_scraped_trailer(movie_title, year)
    
    def get_movie_clips(self, movie_title: str, year: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Get movie clips and related videos
        
        Args:
            movie_title: Movie title
            year: Optional release year
            
        Returns:
            List of video clips
        """
        if self.enabled:
            try:
                query = f"{movie_title} {year if year else ''} movie clips scenes"
                
                params = {
                    'key': self.api_key,
                    'q': query,
                    'part': 'snippet',
                    'type': 'video',
                    'maxResults': 10,
                    'videoCategoryId': '1'
                }
                
                response = requests.get(f"{self.BASE_URL}/search", params=params, timeout=5)
                response.raise_for_status()
                
                data = response.json()
                clips = []
                
                for item in data.get('items', []):
                    snippet = item.get('snippet', {})
                    clips.append({
                        'source': 'YouTube API',
                        'video_id': item.get('id', {}).get('videoId'),
                        'title': snippet.get('title'),
                        'description': snippet.get('description'),
                        'channel': snippet.get('channelTitle'),
                        'published_at': snippet.get('publishedAt'),
                        'thumbnail': snippet.get('thumbnails', {}).get('medium', {}).get('url'),
                        'url': f"https://www.youtube.com/watch?v={item.get('id', {}).get('videoId')}"
                    })
                
                return clips
                
            except Exception as e:
                logger.warning(f"YouTube API error getting clips for '{movie_title}': {e}")
        
        return []
    
    def get_video_details(self, video_id: str) -> Optional[Dict[str, Any]]:
        """
        Get detailed information about a YouTube video
        
        Args:
            video_id: YouTube video ID
            
        Returns:
            Video details or None
        """
        if self.enabled:
            try:
                params = {
                    'key': self.api_key,
                    'id': video_id,
                    'part': 'snippet,contentDetails,statistics'
                }
                
                response = requests.get(f"{self.BASE_URL}/videos", params=params, timeout=5)
                response.raise_for_status()
                
                data = response.json()
                items = data.get('items', [])
                
                if items:
                    item = items[0]
                    snippet = item.get('snippet', {})
                    stats = item.get('statistics', {})
                    content = item.get('contentDetails', {})
                    
                    return {
                        'source': 'YouTube API',
                        'video_id': video_id,
                        'title': snippet.get('title'),
                        'description': snippet.get('description'),
                        'channel': snippet.get('channelTitle'),
                        'published_at': snippet.get('publishedAt'),
                        'thumbnail': snippet.get('thumbnails', {}).get('high', {}).get('url'),
                        'duration': content.get('duration'),
                        'view_count': stats.get('viewCount'),
                        'like_count': stats.get('likeCount'),
                        'comment_count': stats.get('commentCount'),
                        'url': f"https://www.youtube.com/watch?v={video_id}"
                    }
                    
            except Exception as e:
                logger.warning(f"YouTube API error getting video details for '{video_id}': {e}")
        
        return None
    
    def _get_scraped_trailer(self, movie_title: str, year: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Get trailer information from scraped data"""
        if not self.db_config:
            return None
        
        try:
            conn = psycopg2.connect(**self.db_config)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Look for trailer links in scraped data
                if year:
                    cur.execute("""
                        SELECT * FROM scraped_movie_data 
                        WHERE LOWER(movie_title) = LOWER(%s)
                        AND year = %s
                        AND (processed_data::text LIKE '%youtube%' 
                             OR processed_data::text LIKE '%trailer%')
                        ORDER BY scraped_at DESC
                        LIMIT 1
                    """, (movie_title, year))
                else:
                    cur.execute("""
                        SELECT * FROM scraped_movie_data 
                        WHERE LOWER(movie_title) = LOWER(%s)
                        AND (processed_data::text LIKE '%youtube%' 
                             OR processed_data::text LIKE '%trailer%')
                        ORDER BY scraped_at DESC
                        LIMIT 1
                    """, (movie_title,))
                
                result = cur.fetchone()
                if result:
                    processed = result.get('processed_data', {})
                    if isinstance(processed, str):
                        processed = json.loads(processed)
                    
                    # Extract YouTube link if present
                    import re
                    youtube_pattern = r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'
                    
                    text_to_search = str(processed)
                    match = re.search(youtube_pattern, text_to_search)
                    
                    if match:
                        video_id = match.group(1)
                        return {
                            'source': f"Scraped from {result.get('source_site', 'Unknown')}",
                            'video_id': video_id,
                            'title': f"{movie_title} - Trailer",
                            'url': f"https://www.youtube.com/watch?v={video_id}",
                            'scraped_at': result.get('scraped_at').isoformat() if result.get('scraped_at') else None
                        }
                
        except Exception as e:
            logger.error(f"Error getting scraped trailer for '{movie_title}': {e}")
        
        return None
    
    def is_available(self) -> bool:
        """Check if YouTube API is available"""
        return self.enabled
    
    def get_data_source(self) -> str:
        """Get current data source being used"""
        return "YouTube API" if self.enabled else "Scraped Trailer Links"