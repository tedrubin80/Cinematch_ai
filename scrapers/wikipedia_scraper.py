"""
Wikipedia Film Scraper for Cinematch
Scrapes film data from Wikipedia including lists, box office, awards, and festivals
"""

import re
import json
import logging
from typing import Dict, List, Any, Optional
from urllib.parse import urljoin, quote
from bs4 import BeautifulSoup
from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

class WikipediaScraper(BaseScraper):
    """Scraper for Wikipedia film-related content"""
    
    BASE_URL = "https://en.wikipedia.org"
    API_URL = "https://en.wikipedia.org/w/api.php"
    
    def __init__(self, target_id: int, db_config: Dict[str, str]):
        super().__init__(target_id, db_config)
        self.pages_scraped = 0
        self.records_extracted = 0
        
    def scrape(self) -> Dict[str, Any]:
        """
        Main scraping method for Wikipedia
        
        Returns:
            Dictionary containing scraping results
        """
        scraping_rules = self.target_config.get('scraping_rules', {})
        
        # Determine scraping strategy based on target name
        if 'Film Hub' in self.target_config['name']:
            return self._scrape_film_hub()
        elif 'Film Lists' in self.target_config['name']:
            return self._scrape_film_lists()
        elif 'Box Office' in self.target_config['name']:
            return self._scrape_box_office()
        elif 'Academy Awards' in self.target_config['name']:
            return self._scrape_academy_awards()
        elif 'Film Festivals' in self.target_config['name']:
            return self._scrape_film_festivals()
        else:
            return self._scrape_generic_page()
    
    def _scrape_film_hub(self) -> Dict[str, Any]:
        """Scrape the main Wikipedia Film portal"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Extract key sections about film
        film_data = {
            'data_type': 'film_overview',
            'title': 'Film Overview',
            'sections': {}
        }
        
        # Get the main content
        content = soup.find('div', {'id': 'mw-content-text'})
        if content:
            # Extract key sections
            for section in content.find_all(['h2', 'h3']):
                section_title = section.get_text(strip=True).replace('[edit]', '')
                section_content = []
                
                # Get content until next section
                for sibling in section.find_next_siblings():
                    if sibling.name in ['h2', 'h3']:
                        break
                    if sibling.name == 'p':
                        section_content.append(sibling.get_text(strip=True))
                
                if section_content:
                    film_data['sections'][section_title] = ' '.join(section_content)
            
            # Save the overview data
            self._save_to_database(film_data)
            self.records_extracted += 1
        
        # Extract links to film-related pages
        film_links = self._extract_film_links(soup)
        
        # Follow important links (limited to avoid overwhelming)
        for link in film_links[:10]:  # Limit to first 10 links
            try:
                self._scrape_film_page(link)
            except Exception as e:
                logger.warning(f"Failed to scrape {link}: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_film_lists(self) -> Dict[str, Any]:
        """Scrape Wikipedia's Lists of Films page"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Find all film list links
        content = soup.find('div', {'id': 'mw-content-text'})
        if content:
            list_links = content.find_all('a', href=re.compile(r'/wiki/List_of_'))
            
            for link in list_links[:20]:  # Limit to prevent overwhelming
                href = link.get('href')
                if href:
                    full_url = urljoin(self.BASE_URL, href)
                    list_title = link.get_text(strip=True)
                    
                    try:
                        self._scrape_film_list(full_url, list_title)
                    except Exception as e:
                        logger.warning(f"Failed to scrape list {list_title}: {e}")
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_box_office(self) -> Dict[str, Any]:
        """Scrape box office data from Wikipedia"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Find tables with box office data
        tables = soup.find_all('table', {'class': 'wikitable'})
        
        for table in tables:
            # Extract headers
            headers = []
            header_row = table.find('tr')
            if header_row:
                headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
            
            # Extract data rows
            for row in table.find_all('tr')[1:]:  # Skip header row
                cells = row.find_all(['td', 'th'])
                if len(cells) >= 2:
                    movie_data = {}
                    for i, cell in enumerate(cells):
                        if i < len(headers):
                            # Clean cell text and extract links
                            cell_text = cell.get_text(strip=True)
                            cell_link = cell.find('a')
                            
                            if cell_link and 'href' in cell_link.attrs:
                                movie_data[f"{headers[i]}_link"] = urljoin(self.BASE_URL, cell_link['href'])
                            
                            movie_data[headers[i]] = cell_text
                    
                    # Extract movie title and year
                    title = movie_data.get('Film', movie_data.get('Title', ''))
                    year_match = re.search(r'\b(19|20)\d{2}\b', str(movie_data))
                    year = int(year_match.group()) if year_match else None
                    
                    if title:
                        box_office_data = {
                            'data_type': 'box_office',
                            'title': title,
                            'year': year,
                            'box_office_data': movie_data
                        }
                        
                        self._save_to_database(box_office_data)
                        self.records_extracted += 1
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_academy_awards(self) -> Dict[str, Any]:
        """Scrape Academy Awards data"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Find award winner tables
        tables = soup.find_all('table', {'class': 'wikitable'})
        
        for table in tables:
            # Look for tables with year and film columns
            rows = table.find_all('tr')
            
            for row in rows[1:]:  # Skip header
                cells = row.find_all(['td', 'th'])
                if len(cells) >= 2:
                    # Extract year and film
                    year_cell = cells[0].get_text(strip=True)
                    film_cell = cells[1] if len(cells) > 1 else None
                    
                    # Extract year
                    year_match = re.search(r'\b(19|20)\d{2}\b', year_cell)
                    year = int(year_match.group()) if year_match else None
                    
                    if film_cell:
                        # Extract film title
                        film_link = film_cell.find('a')
                        if film_link:
                            title = film_link.get_text(strip=True)
                            wiki_link = urljoin(self.BASE_URL, film_link.get('href', ''))
                            
                            award_data = {
                                'data_type': 'award',
                                'title': title,
                                'year': year,
                                'award': 'Academy Award for Best Picture',
                                'category': 'Winner',
                                'wikipedia_link': wiki_link
                            }
                            
                            self._save_to_database(award_data)
                            self.records_extracted += 1
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_film_festivals(self) -> Dict[str, Any]:
        """Scrape film festival data"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Extract festival information
        festival_name = soup.find('h1', {'class': 'firstHeading'})
        festival_name = festival_name.get_text(strip=True) if festival_name else 'Unknown Festival'
        
        # Find award winner tables or lists
        content = soup.find('div', {'id': 'mw-content-text'})
        
        if content:
            # Look for Palme d'Or or other major award sections
            for section in content.find_all(['h2', 'h3']):
                section_title = section.get_text(strip=True)
                
                if any(award in section_title for award in ['Palme', 'Prize', 'Award', 'Winner']):
                    # Find the next table or list
                    next_element = section.find_next_sibling()
                    
                    while next_element and next_element.name not in ['h2', 'h3']:
                        if next_element.name == 'table':
                            self._extract_festival_table(next_element, festival_name, section_title)
                        elif next_element.name in ['ul', 'ol']:
                            self._extract_festival_list(next_element, festival_name, section_title)
                        
                        next_element = next_element.find_next_sibling()
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _scrape_film_page(self, url: str):
        """Scrape an individual film page"""
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Extract film title
        title_element = soup.find('h1', {'class': 'firstHeading'})
        if not title_element:
            return
        
        title = title_element.get_text(strip=True)
        
        # Extract infobox data
        infobox = soup.find('table', {'class': 'infobox'})
        film_data = {
            'data_type': 'film_details',
            'title': title,
            'url': url
        }
        
        if infobox:
            for row in infobox.find_all('tr'):
                header = row.find('th')
                value = row.find('td')
                
                if header and value:
                    key = header.get_text(strip=True)
                    val = value.get_text(strip=True)
                    
                    # Extract specific fields
                    if 'Direct' in key:
                        film_data['director'] = val
                    elif 'Produc' in key and 'company' not in key.lower():
                        film_data['producer'] = val
                    elif 'Writ' in key:
                        film_data['writer'] = val
                    elif 'Star' in key or 'Cast' in key:
                        film_data['cast'] = val
                    elif 'Release' in key:
                        film_data['release_date'] = val
                        # Try to extract year
                        year_match = re.search(r'\b(19|20)\d{2}\b', val)
                        if year_match:
                            film_data['year'] = int(year_match.group())
                    elif 'Box office' in key:
                        film_data['box_office'] = val
                    elif 'Budget' in key:
                        film_data['budget'] = val
                    elif 'Running time' in key:
                        film_data['runtime'] = val
                    elif 'Country' in key:
                        film_data['country'] = val
                    elif 'Language' in key:
                        film_data['language'] = val
        
        # Extract plot summary
        plot_section = soup.find('h2', string=re.compile('Plot'))
        if plot_section:
            plot_text = []
            for sibling in plot_section.find_next_siblings():
                if sibling.name == 'h2':
                    break
                if sibling.name == 'p':
                    plot_text.append(sibling.get_text(strip=True))
            
            if plot_text:
                film_data['plot'] = ' '.join(plot_text[:3])  # Limit to first 3 paragraphs
        
        self._save_to_database(film_data)
        self.records_extracted += 1
    
    def _scrape_film_list(self, url: str, list_title: str):
        """Scrape a film list page"""
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Extract films from the list
        content = soup.find('div', {'id': 'mw-content-text'})
        if not content:
            return
        
        # Look for film entries in lists or tables
        films_found = 0
        
        # Check for tables
        for table in content.find_all('table', {'class': 'wikitable'}):
            for row in table.find_all('tr')[1:]:  # Skip header
                cells = row.find_all(['td', 'th'])
                if cells:
                    # Look for film title (usually has a link)
                    for cell in cells:
                        film_link = cell.find('a')
                        if film_link and '/wiki/' in film_link.get('href', ''):
                            title = film_link.get_text(strip=True)
                            if title and not title.startswith('List'):
                                list_data = {
                                    'data_type': 'film_list_entry',
                                    'title': title,
                                    'list_name': list_title,
                                    'wikipedia_link': urljoin(self.BASE_URL, film_link['href'])
                                }
                                
                                # Extract year if present in row
                                row_text = row.get_text()
                                year_match = re.search(r'\b(19|20)\d{2}\b', row_text)
                                if year_match:
                                    list_data['year'] = int(year_match.group())
                                
                                self._save_to_database(list_data)
                                self.records_extracted += 1
                                films_found += 1
                                
                                if films_found >= 50:  # Limit per list
                                    return
    
    def _extract_festival_table(self, table, festival_name: str, award_name: str):
        """Extract festival award data from a table"""
        for row in table.find_all('tr')[1:]:  # Skip header
            cells = row.find_all(['td', 'th'])
            if len(cells) >= 2:
                # Extract year and film
                year_text = cells[0].get_text(strip=True)
                year_match = re.search(r'\b(19|20)\d{2}\b', year_text)
                year = int(year_match.group()) if year_match else None
                
                # Extract film title
                film_cell = cells[1] if len(cells) > 1 else cells[0]
                film_link = film_cell.find('a')
                
                if film_link:
                    title = film_link.get_text(strip=True)
                    
                    festival_data = {
                        'data_type': 'festival_award',
                        'title': title,
                        'year': year,
                        'festival': festival_name,
                        'award': award_name,
                        'wikipedia_link': urljoin(self.BASE_URL, film_link.get('href', ''))
                    }
                    
                    self._save_to_database(festival_data)
                    self.records_extracted += 1
    
    def _extract_festival_list(self, list_element, festival_name: str, award_name: str):
        """Extract festival award data from a list"""
        for item in list_element.find_all('li'):
            # Extract film and year
            text = item.get_text(strip=True)
            year_match = re.search(r'\b(19|20)\d{2}\b', text)
            year = int(year_match.group()) if year_match else None
            
            # Look for film link
            film_link = item.find('a')
            if film_link:
                title = film_link.get_text(strip=True)
                
                festival_data = {
                    'data_type': 'festival_award',
                    'title': title,
                    'year': year,
                    'festival': festival_name,
                    'award': award_name,
                    'wikipedia_link': urljoin(self.BASE_URL, film_link.get('href', ''))
                }
                
                self._save_to_database(festival_data)
                self.records_extracted += 1
    
    def _extract_film_links(self, soup: BeautifulSoup) -> List[str]:
        """Extract film-related links from a page"""
        film_links = []
        content = soup.find('div', {'id': 'mw-content-text'})
        
        if content:
            for link in content.find_all('a', href=True):
                href = link['href']
                if href.startswith('/wiki/') and not ':' in href:
                    # Filter for likely film pages
                    link_text = link.get_text(strip=True)
                    if any(word in link_text.lower() for word in ['film', 'movie', 'cinema']):
                        film_links.append(urljoin(self.BASE_URL, href))
        
        return film_links
    
    def _scrape_generic_page(self) -> Dict[str, Any]:
        """Generic scraping for unspecified Wikipedia pages"""
        url = self.target_config['base_url']
        soup = self._get_soup(url)
        self.pages_scraped += 1
        
        # Extract basic page content
        title = soup.find('h1', {'class': 'firstHeading'})
        title = title.get_text(strip=True) if title else 'Unknown'
        
        content = soup.find('div', {'id': 'mw-content-text'})
        if content:
            # Extract first few paragraphs
            paragraphs = content.find_all('p', limit=5)
            content_text = ' '.join([p.get_text(strip=True) for p in paragraphs])
            
            page_data = {
                'data_type': 'wikipedia_content',
                'title': title,
                'url': url,
                'content': content_text[:2000]  # Limit content size
            }
            
            self._save_to_database(page_data)
            self.records_extracted += 1
        
        return {
            'pages_scraped': self.pages_scraped,
            'records_extracted': self.records_extracted
        }
    
    def _process_data(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process raw Wikipedia data into structured format
        
        Args:
            raw_data: Raw scraped data
            
        Returns:
            Processed data dictionary
        """
        processed = raw_data.copy()
        
        # Clean and normalize text fields
        text_fields = ['plot', 'content', 'director', 'cast', 'producer', 'writer']
        for field in text_fields:
            if field in processed and processed[field]:
                # Remove extra whitespace and special characters
                processed[field] = re.sub(r'\s+', ' ', processed[field])
                processed[field] = processed[field].replace('\n', ' ').strip()
        
        # Parse monetary values
        money_fields = ['box_office', 'budget']
        for field in money_fields:
            if field in processed and processed[field]:
                value = processed[field]
                # Extract numeric value
                numbers = re.findall(r'[\d,]+\.?\d*', value)
                if numbers:
                    # Convert to float
                    num_str = numbers[0].replace(',', '')
                    try:
                        amount = float(num_str)
                        # Check for millions/billions
                        if 'million' in value.lower():
                            amount *= 1_000_000
                        elif 'billion' in value.lower():
                            amount *= 1_000_000_000
                        
                        processed[f"{field}_numeric"] = amount
                    except ValueError:
                        pass
        
        # Parse runtime
        if 'runtime' in processed and processed['runtime']:
            runtime = processed['runtime']
            # Extract minutes
            minutes_match = re.search(r'(\d+)\s*min', runtime)
            if minutes_match:
                processed['runtime_minutes'] = int(minutes_match.group(1))
        
        # Ensure year is integer
        if 'year' in processed and processed['year']:
            try:
                processed['year'] = int(processed['year'])
            except (ValueError, TypeError):
                pass
        
        return processed