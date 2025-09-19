"""
Wikipedia API Client - Always available, no API key required
"""

import logging
import requests
from typing import Dict, Optional, Any, List
import json
import re

logger = logging.getLogger(__name__)

class WikipediaAPI:
    """Wikipedia API client - always available"""
    
    BASE_URL = "https://en.wikipedia.org/w/api.php"
    
    def __init__(self):
        """Initialize Wikipedia API client"""
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Cinematch/1.0 (Movie Research Bot; https://cinematch.online)'
        })
        logger.info("Wikipedia API initialized - no key required")
    
    def search_movies(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Search for movie-related Wikipedia pages
        
        Args:
            query: Search query
            limit: Maximum number of results
            
        Returns:
            List of search results
        """
        try:
            params = {
                'action': 'query',
                'format': 'json',
                'list': 'search',
                'srsearch': f"{query} film movie",
                'srlimit': limit,
                'srprop': 'snippet|titlesnippet|size|wordcount'
            }
            
            response = self.session.get(self.BASE_URL, params=params, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            results = []
            
            for item in data.get('query', {}).get('search', []):
                results.append({
                    'source': 'Wikipedia API',
                    'title': item.get('title'),
                    'page_id': item.get('pageid'),
                    'snippet': self._clean_snippet(item.get('snippet', '')),
                    'size': item.get('size'),
                    'word_count': item.get('wordcount'),
                    'url': f"https://en.wikipedia.org/?curid={item.get('pageid')}"
                })
            
            return results
            
        except Exception as e:
            logger.error(f"Wikipedia API search error for '{query}': {e}")
            return []
    
    def get_page_content(self, title: str) -> Optional[Dict[str, Any]]:
        """
        Get full page content
        
        Args:
            title: Wikipedia page title
            
        Returns:
            Page content dictionary
        """
        try:
            # Get page extract
            params = {
                'action': 'query',
                'format': 'json',
                'prop': 'extracts|pageimages|info',
                'titles': title,
                'exintro': True,
                'explaintext': True,
                'inprop': 'url',
                'piprop': 'original'
            }
            
            response = self.session.get(self.BASE_URL, params=params, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            pages = data.get('query', {}).get('pages', {})
            
            for page_id, page_data in pages.items():
                if page_id != '-1':  # Page exists
                    return {
                        'source': 'Wikipedia API',
                        'title': page_data.get('title'),
                        'page_id': page_id,
                        'extract': page_data.get('extract'),
                        'url': page_data.get('fullurl'),
                        'image': page_data.get('original', {}).get('source')
                    }
                    
        except Exception as e:
            logger.error(f"Wikipedia API page content error for '{title}': {e}")
        
        return None
    
    def get_movie_infobox(self, title: str) -> Optional[Dict[str, Any]]:
        """
        Extract movie infobox data from Wikipedia page
        
        Args:
            title: Movie title or Wikipedia page title
            
        Returns:
            Infobox data dictionary
        """
        try:
            # Get page wikitext
            params = {
                'action': 'query',
                'format': 'json',
                'prop': 'revisions',
                'titles': title,
                'rvprop': 'content',
                'rvslots': 'main'
            }
            
            response = self.session.get(self.BASE_URL, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            pages = data.get('query', {}).get('pages', {})
            
            for page_id, page_data in pages.items():
                if page_id != '-1':
                    revisions = page_data.get('revisions', [])
                    if revisions:
                        content = revisions[0].get('slots', {}).get('main', {}).get('*', '')
                        return self._parse_infobox(content, page_data.get('title'))
                        
        except Exception as e:
            logger.error(f"Wikipedia API infobox error for '{title}': {e}")
        
        return None
    
    def get_film_by_year(self, year: int) -> List[Dict[str, Any]]:
        """
        Get films released in a specific year
        
        Args:
            year: Release year
            
        Returns:
            List of films from that year
        """
        try:
            # Search for year in film pages
            params = {
                'action': 'query',
                'format': 'json',
                'list': 'search',
                'srsearch': f"{year} film -list",
                'srlimit': 50,
                'srprop': 'snippet|titlesnippet'
            }
            
            response = self.session.get(self.BASE_URL, params=params, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            results = []
            
            for item in data.get('query', {}).get('search', []):
                # Filter to likely film pages
                title = item.get('title', '')
                snippet = item.get('snippet', '')
                
                # Check if it's likely a film page
                if ('film' in title.lower() or 'film' in snippet.lower()) and year in snippet:
                    results.append({
                        'source': 'Wikipedia API',
                        'title': title,
                        'year': year,
                        'page_id': item.get('pageid'),
                        'snippet': self._clean_snippet(snippet),
                        'url': f"https://en.wikipedia.org/?curid={item.get('pageid')}"
                    })
            
            return results
            
        except Exception as e:
            logger.error(f"Wikipedia API year search error for {year}: {e}")
            return []
    
    def get_category_members(self, category: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Get members of a Wikipedia category
        
        Args:
            category: Category name (e.g., "Academy Award for Best Picture")
            limit: Maximum number of results
            
        Returns:
            List of category members
        """
        try:
            params = {
                'action': 'query',
                'format': 'json',
                'list': 'categorymembers',
                'cmtitle': f"Category:{category}",
                'cmlimit': limit,
                'cmprop': 'ids|title|type'
            }
            
            response = self.session.get(self.BASE_URL, params=params, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            results = []
            
            for item in data.get('query', {}).get('categorymembers', []):
                if item.get('type') == 'page':  # Skip subcategories
                    results.append({
                        'source': 'Wikipedia API',
                        'title': item.get('title'),
                        'page_id': item.get('pageid'),
                        'category': category,
                        'url': f"https://en.wikipedia.org/?curid={item.get('pageid')}"
                    })
            
            return results
            
        except Exception as e:
            logger.error(f"Wikipedia API category error for '{category}': {e}")
            return []
    
    def _parse_infobox(self, wikitext: str, title: str) -> Dict[str, Any]:
        """Parse infobox from wikitext"""
        infobox_data = {
            'source': 'Wikipedia API',
            'title': title
        }
        
        # Extract infobox content
        infobox_match = re.search(r'\{\{Infobox film(.*?)\}\}', wikitext, re.DOTALL | re.IGNORECASE)
        if not infobox_match:
            return infobox_data
        
        infobox_text = infobox_match.group(1)
        
        # Parse common fields
        patterns = {
            'director': r'\|\s*director\s*=\s*([^\n|]+)',
            'producer': r'\|\s*producer\s*=\s*([^\n|]+)',
            'writer': r'\|\s*writer\s*=\s*([^\n|]+)',
            'screenplay': r'\|\s*screenplay\s*=\s*([^\n|]+)',
            'starring': r'\|\s*starring\s*=\s*([^\n|]+)',
            'music': r'\|\s*music\s*=\s*([^\n|]+)',
            'cinematography': r'\|\s*cinematography\s*=\s*([^\n|]+)',
            'editing': r'\|\s*editing\s*=\s*([^\n|]+)',
            'studio': r'\|\s*studio\s*=\s*([^\n|]+)',
            'distributor': r'\|\s*distributor\s*=\s*([^\n|]+)',
            'released': r'\|\s*released\s*=\s*([^\n|]+)',
            'runtime': r'\|\s*runtime\s*=\s*([^\n|]+)',
            'country': r'\|\s*country\s*=\s*([^\n|]+)',
            'language': r'\|\s*language\s*=\s*([^\n|]+)',
            'budget': r'\|\s*budget\s*=\s*([^\n|]+)',
            'gross': r'\|\s*gross\s*=\s*([^\n|]+)'
        }
        
        for field, pattern in patterns.items():
            match = re.search(pattern, infobox_text, re.IGNORECASE)
            if match:
                value = match.group(1).strip()
                # Clean wiki markup
                value = re.sub(r'\[\[([^|\]]+)\|([^\]]+)\]\]', r'\2', value)  # [[link|text]] -> text
                value = re.sub(r'\[\[([^\]]+)\]\]', r'\1', value)  # [[link]] -> link
                value = re.sub(r"'''?", '', value)  # Remove bold/italic
                value = re.sub(r'<[^>]+>', '', value)  # Remove HTML tags
                value = re.sub(r'\{\{[^}]+\}\}', '', value)  # Remove templates
                
                infobox_data[field] = value.strip()
        
        # Extract year from released date
        if 'released' in infobox_data:
            year_match = re.search(r'\b(19|20)\d{2}\b', infobox_data['released'])
            if year_match:
                infobox_data['year'] = int(year_match.group())
        
        return infobox_data
    
    def _clean_snippet(self, snippet: str) -> str:
        """Clean HTML from search snippet"""
        # Remove HTML tags
        snippet = re.sub(r'<[^>]+>', '', snippet)
        # Remove multiple spaces
        snippet = re.sub(r'\s+', ' ', snippet)
        return snippet.strip()
    
    def is_available(self) -> bool:
        """Wikipedia API is always available"""
        return True
    
    def get_data_source(self) -> str:
        """Get data source name"""
        return "Wikipedia API (Free)"