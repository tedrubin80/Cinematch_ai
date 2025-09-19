"""
Base Scraper Class for Cinematch Web Scraping System
Provides common functionality for all scrapers
"""

import time
import hashlib
import json
import logging
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Dict, List, Optional, Any
import requests
from bs4 import BeautifulSoup
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from urllib.parse import urljoin, urlparse

logger = logging.getLogger(__name__)

class BaseScraper(ABC):
    """Base class for all web scrapers"""
    
    def __init__(self, target_id: int, db_config: Dict[str, str]):
        """
        Initialize the base scraper
        
        Args:
            target_id: ID of the scraping target from database
            db_config: Database connection configuration
        """
        self.target_id = target_id
        self.db_config = db_config
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': os.getenv('SCRAPING_USER_AGENT', 'Cinematch/1.0 (Movie Research Bot)')
        })
        
        # Rate limiting configuration
        self.min_delay = float(os.getenv('SCRAPING_DELAY_MIN', '2'))
        self.max_delay = float(os.getenv('SCRAPING_DELAY_MAX', '5'))
        
        # Load target configuration from database
        self.target_config = self._load_target_config()
        
    def _load_target_config(self) -> Dict[str, Any]:
        """Load scraping target configuration from database"""
        conn = psycopg2.connect(**self.db_config)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT * FROM scraping_targets WHERE id = %s
                """, (self.target_id,))
                config = cur.fetchone()
                if not config:
                    raise ValueError(f"Scraping target {self.target_id} not found")
                return dict(config)
        finally:
            conn.close()
    
    def _get_soup(self, url: str) -> BeautifulSoup:
        """
        Fetch a URL and return BeautifulSoup object
        
        Args:
            url: URL to fetch
            
        Returns:
            BeautifulSoup object of the page
        """
        # Rate limiting
        delay = time.uniform(self.min_delay, self.max_delay)
        time.sleep(delay)
        
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            return BeautifulSoup(response.content, 'html.parser')
        except requests.RequestException as e:
            logger.error(f"Error fetching {url}: {e}")
            raise
    
    def _save_to_database(self, data: Dict[str, Any]) -> bool:
        """
        Save scraped data to database
        
        Args:
            data: Dictionary containing the scraped data
            
        Returns:
            True if saved successfully, False otherwise
        """
        # Generate hash for deduplication
        data_str = json.dumps(data, sort_keys=True)
        data_hash = hashlib.sha256(data_str.encode()).hexdigest()
        
        conn = psycopg2.connect(**self.db_config)
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO scraped_movie_data 
                    (source_site, movie_title, year, data_type, raw_data, processed_data, data_hash)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (source_site, movie_title, data_type, data_hash) 
                    DO UPDATE SET scraped_at = CURRENT_TIMESTAMP
                    RETURNING id
                """, (
                    self.target_config['name'],
                    data.get('title', 'Unknown'),
                    data.get('year'),
                    data.get('data_type', 'general'),
                    json.dumps(data),
                    json.dumps(self._process_data(data)),
                    data_hash
                ))
                conn.commit()
                return cur.fetchone() is not None
        except Exception as e:
            logger.error(f"Error saving to database: {e}")
            conn.rollback()
            return False
        finally:
            conn.close()
    
    def _process_data(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process raw scraped data into structured format
        Override in subclasses for specific processing
        
        Args:
            raw_data: Raw scraped data
            
        Returns:
            Processed data dictionary
        """
        return raw_data
    
    def _log_scraping_activity(self, status: str, pages_scraped: int = 0, 
                               records_extracted: int = 0, errors: Optional[List[str]] = None):
        """Log scraping activity to database"""
        conn = psycopg2.connect(**self.db_config)
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO scraping_logs 
                    (target_id, status, pages_scraped, records_extracted, errors, started_at, completed_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    self.target_id,
                    status,
                    pages_scraped,
                    records_extracted,
                    json.dumps(errors) if errors else None,
                    self.start_time,
                    datetime.now()
                ))
                conn.commit()
        finally:
            conn.close()
    
    def _update_last_scraped(self):
        """Update the last_scraped timestamp for the target"""
        conn = psycopg2.connect(**self.db_config)
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE scraping_targets 
                    SET last_scraped = CURRENT_TIMESTAMP 
                    WHERE id = %s
                """, (self.target_id,))
                conn.commit()
        finally:
            conn.close()
    
    @abstractmethod
    def scrape(self) -> Dict[str, Any]:
        """
        Main scraping method to be implemented by subclasses
        
        Returns:
            Dictionary containing scraping results
        """
        pass
    
    def run(self) -> Dict[str, Any]:
        """
        Run the scraper with error handling and logging
        
        Returns:
            Dictionary containing scraping results and metadata
        """
        self.start_time = datetime.now()
        pages_scraped = 0
        records_extracted = 0
        errors = []
        status = 'success'
        
        try:
            logger.info(f"Starting scrape for {self.target_config['name']}")
            result = self.scrape()
            pages_scraped = result.get('pages_scraped', 0)
            records_extracted = result.get('records_extracted', 0)
            
            # Update last scraped timestamp
            self._update_last_scraped()
            
        except Exception as e:
            logger.error(f"Scraping failed for {self.target_config['name']}: {e}")
            errors.append(str(e))
            status = 'failed'
            result = {'error': str(e)}
        
        finally:
            # Log the scraping activity
            self._log_scraping_activity(status, pages_scraped, records_extracted, errors)
        
        return {
            'target': self.target_config['name'],
            'status': status,
            'pages_scraped': pages_scraped,
            'records_extracted': records_extracted,
            'errors': errors,
            'duration': (datetime.now() - self.start_time).total_seconds()
        }