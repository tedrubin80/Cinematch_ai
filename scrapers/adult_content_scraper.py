"""
Adult Content Scraper for 18+ Movie Sites
Specialized scraper for adult film distributors and collectors
"""

import re
import json
import logging
from typing import Dict, List, Any, Optional
from urllib.parse import urljoin, quote
from bs4 import BeautifulSoup
from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

class AdultContentScraper(BaseScraper):
    """Specialized scraper for 18+ adult content sites"""
    
    def __init__(self, target_id: int, db_config: Dict[str, str]):
        super().__init__(target_id, db_config)
        self.pages_scraped = 0
        self.records_extracted = 0
        
        # Age verification - ensure this scraper only handles 18+ content
        scraping_rules = self.target_config.get('scraping_rules', {})
        if scraping_rules.get('age_restriction') != '18+':
            raise ValueError("Adult content scraper can only handle 18+ restricted content")
    
    def scrape(self) -> Dict[str, Any]:
        """
        Main scraping method for adult content sites
        
        Returns:
            Dictionary containing scraping results
        """
        site_name = self.target_config['name'].lower()
        
        if 'something weird' in site_name:
            return self._scrape_something_weird()
        elif 'vinegar syndrome' in site_name:
            return self._scrape_vinegar_syndrome()
        elif 'kimchi dvd' in site_name:
            return self._scrape_kimchi_dvd()
        elif 'movie room' in site_name:
            return self._scrape_movie_room()
        else:
            return self._scrape_generic_adult_site()
    
    def _scrape_something_weird(self) -> Dict[str, Any]:
        """Scrape Something Weird Video site"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Look for product listings
        products = soup.find_all(['div', 'article'], class_=re.compile(r'product|item'))
        
        for product in products:
            try:
                # Extract basic product info
                title_elem = product.find(['h1', 'h2', 'h3', 'a'], class_=re.compile(r'title|name|product'))
                if not title_elem:
                    continue
                
                title = title_elem.get_text(strip=True)
                
                # Skip if title is too generic
                if len(title) < 3 or title.lower() in ['more', 'view', 'buy']:
                    continue
                
                # Extract additional details
                product_data = {
                    'data_type': 'adult_content',
                    'title': title,
                    'source_site': 'Something Weird Video',
                    'age_restriction': '18+',
                    'url': url
                }
                
                # Try to extract price
                price_elem = product.find(class_=re.compile(r'price|cost'))
                if price_elem:
                    product_data['price'] = price_elem.get_text(strip=True)
                
                # Try to extract description
                desc_elem = product.find(class_=re.compile(r'description|summary'))
                if desc_elem:
                    product_data['description'] = desc_elem.get_text(strip=True)[:500]
                
                # Try to extract year
                year_match = re.search(r'\b(19|20)\d{2}\b', title + ' ' + product.get_text())
                if year_match:
                    product_data['year'] = int(year_match.group())
                
                # Try to extract image
                img_elem = product.find('img')
                if img_elem and img_elem.get('src'):
                    product_data['image_url'] = urljoin(url, img_elem['src'])
                
                self._save_to_database(product_data)
                self.records_extracted += 1
                
            except Exception as e:
                logger.warning(f"Error extracting Something Weird product: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_vinegar_syndrome(self) -> Dict[str, Any]:
        """Scrape Vinegar Syndrome site"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Look for product grids and featured items
        selectors = [
            '.product-item',
            '.product-card', 
            '.featured-product',
            '.collection-item',
            '[class*="product"]'
        ]
        
        products = []
        for selector in selectors:
            products.extend(soup.select(selector))
        
        for product in products[:50]:  # Limit to prevent overwhelming
            try:
                # Extract title
                title_elem = product.find(['h2', 'h3', 'h4', 'a'], class_=re.compile(r'title|name'))
                if not title_elem:
                    # Try alternative selectors
                    title_elem = product.find('a') or product.find(string=re.compile(r'\w{3,}'))
                
                if not title_elem:
                    continue
                
                if hasattr(title_elem, 'get_text'):
                    title = title_elem.get_text(strip=True)
                else:
                    title = str(title_elem).strip()
                
                if len(title) < 3:
                    continue
                
                product_data = {
                    'data_type': 'adult_content',
                    'title': title,
                    'source_site': 'Vinegar Syndrome',
                    'age_restriction': '18+',
                    'url': url
                }
                
                # Extract format info (Blu-ray, DVD, etc.)
                format_elem = product.find(string=re.compile(r'blu-?ray|dvd|4k', re.I))
                if format_elem:
                    product_data['format'] = str(format_elem).strip()
                
                # Extract director if available
                director_elem = product.find(class_=re.compile(r'director'))
                if director_elem:
                    product_data['director'] = director_elem.get_text(strip=True)
                
                # Extract year from title or text
                year_match = re.search(r'\b(19|20)\d{2}\b', title + ' ' + product.get_text())
                if year_match:
                    product_data['year'] = int(year_match.group())
                
                self._save_to_database(product_data)
                self.records_extracted += 1
                
            except Exception as e:
                logger.warning(f"Error extracting Vinegar Syndrome product: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_kimchi_dvd(self) -> Dict[str, Any]:
        """Scrape Kimchi DVD site"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Look for movie items - Korean/Asian cinema focus
        items = soup.find_all(['div', 'li', 'article'], class_=re.compile(r'movie|film|product|item'))
        
        for item in items:
            try:
                # Extract movie title
                title_elem = item.find(['h1', 'h2', 'h3'], class_=re.compile(r'title|name'))
                if not title_elem:
                    title_elem = item.find('a')
                
                if not title_elem:
                    continue
                
                title = title_elem.get_text(strip=True)
                
                if len(title) < 2:
                    continue
                
                movie_data = {
                    'data_type': 'adult_content',
                    'title': title,
                    'source_site': 'Kimchi DVD',
                    'age_restriction': '18+',
                    'region': 'Asia',
                    'url': url
                }
                
                # Extract country/origin
                country_elem = item.find(class_=re.compile(r'country|origin|region'))
                if country_elem:
                    movie_data['country'] = country_elem.get_text(strip=True)
                
                # Extract director
                director_elem = item.find(class_=re.compile(r'director'))
                if director_elem:
                    movie_data['director'] = director_elem.get_text(strip=True)
                
                # Extract year
                year_match = re.search(r'\b(19|20)\d{2}\b', item.get_text())
                if year_match:
                    movie_data['year'] = int(year_match.group())
                
                self._save_to_database(movie_data)
                self.records_extracted += 1
                
            except Exception as e:
                logger.warning(f"Error extracting Kimchi DVD item: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_movie_room(self) -> Dict[str, Any]:
        """Scrape The Movie Room site"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Look for curated picks and collections
        collections = soup.find_all(['div', 'article'], class_=re.compile(r'collection|product|pick'))
        
        for collection in collections:
            try:
                # Extract title
                title_elem = collection.find(['h2', 'h3', 'h4'])
                if not title_elem:
                    title_elem = collection.find('a')
                
                if not title_elem:
                    continue
                
                title = title_elem.get_text(strip=True)
                
                if len(title) < 3:
                    continue
                
                collection_data = {
                    'data_type': 'adult_content',
                    'title': title,
                    'source_site': 'The Movie Room',
                    'age_restriction': '18+',
                    'url': url
                }
                
                # Extract curator note/recommendation
                note_elem = collection.find(class_=re.compile(r'note|comment|recommendation'))
                if note_elem:
                    collection_data['curator_note'] = note_elem.get_text(strip=True)[:300]
                
                # Extract genre
                genre_elem = collection.find(class_=re.compile(r'genre|category'))
                if genre_elem:
                    collection_data['genre'] = genre_elem.get_text(strip=True)
                
                # Extract rating if available
                rating_elem = collection.find(class_=re.compile(r'rating|score'))
                if rating_elem:
                    collection_data['staff_rating'] = rating_elem.get_text(strip=True)
                
                self._save_to_database(collection_data)
                self.records_extracted += 1
                
            except Exception as e:
                logger.warning(f"Error extracting Movie Room collection: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_generic_adult_site(self) -> Dict[str, Any]:
        """Generic scraping for unspecified adult content sites"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Look for any product/movie-like content
        items = soup.find_all(['div', 'article', 'li'], 
                             class_=re.compile(r'product|movie|film|item|card'))
        
        for item in items[:20]:  # Limit to prevent overwhelming
            try:
                # Extract any text that looks like a title
                title_candidates = [
                    item.find(['h1', 'h2', 'h3', 'h4']),
                    item.find('a'),
                    item.find(class_=re.compile(r'title|name'))
                ]
                
                title = None
                for candidate in title_candidates:
                    if candidate:
                        title = candidate.get_text(strip=True)
                        if len(title) >= 3:
                            break
                
                if not title or len(title) < 3:
                    continue
                
                generic_data = {
                    'data_type': 'adult_content',
                    'title': title,
                    'source_site': self.target_config['name'],
                    'age_restriction': '18+',
                    'url': url
                }
                
                self._save_to_database(generic_data)
                self.records_extracted += 1
                
            except Exception as e:
                logger.warning(f"Error extracting generic adult content: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _process_data(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process raw adult content data into structured format
        
        Args:
            raw_data: Raw scraped data
            
        Returns:
            Processed data dictionary
        """
        processed = raw_data.copy()
        
        # Ensure age restriction is set
        processed['age_restriction'] = '18+'
        
        # Clean and normalize title
        if 'title' in processed:
            title = processed['title']
            # Remove excessive whitespace
            title = re.sub(r'\s+', ' ', title).strip()
            # Remove common suffixes
            title = re.sub(r'\s*-\s*(DVD|Blu-ray|4K).*$', '', title)
            processed['title'] = title
        
        # Parse price if present
        if 'price' in processed and processed['price']:
            price = processed['price']
            # Extract numeric price
            price_match = re.search(r'[\$£€¥]?(\d+\.?\d*)', price)
            if price_match:
                processed['price_numeric'] = float(price_match.group(1))
        
        # Ensure year is integer if present
        if 'year' in processed and processed['year']:
            try:
                processed['year'] = int(processed['year'])
            except (ValueError, TypeError):
                pass
        
        # Add content warnings
        processed['content_warning'] = 'Adult content - 18+ only'
        
        return processed