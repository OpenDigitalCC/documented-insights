#!/usr/bin/env python3
"""
LLM Position Extractor for EU Consultation Analysis
Phase 2: Extract stakeholder positions from domain-relevant text

Usage:
    # Test mode (5 responses)
    python 10_llm_extract_positions.py --domain taxation --test
    
    # Process specific number
    python 10_llm_extract_positions.py --domain taxation --limit 20
    
    # Process all unprocessed responses for domain
    python 10_llm_extract_positions.py --domain taxation
"""

import os
import sys
import json
import re
import argparse
from typing import Dict, List, Optional, Tuple
import psycopg2
import psycopg2.extras
import requests
from datetime import datetime

# ============================================================================
# Configuration
# ============================================================================

DB_CONFIG = {
    'host': os.getenv('POSTGRES_HOST', 'postgres'),
    'database': os.getenv('POSTGRES_DB', 'documented_insights'),
    'user': os.getenv('POSTGRES_USER', 'sysadmin'),
    'password': os.getenv('POSTGRES_PASSWORD', 'changeme')
}

OLLAMA_URL = os.getenv('OLLAMA_HOST', 'http://ollama:11434')
OLLAMA_MODEL = 'llama3.1:8b'

# Valid values for constraint validation
VALID_POSITION_TYPES = ['support', 'oppose', 'neutral', 'mixed']
VALID_STRENGTHS = ['strong', 'moderate', 'weak']

# ============================================================================
# Database Functions
# ============================================================================

def get_db_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"ERROR: Database connection failed: {e}", file=sys.stderr)
        sys.exit(1)

def load_domain_config(conn, domain: str) -> Dict:
    """Load domain configuration from domain config file via database query"""
    # For now, we'll pass domain keywords as parameters
    # This matches the DomainQuery approach
    domain_configs = {
        'taxation': {
            'keywords': ['tax', 'levy', 'taxation', 'fiscal', 'revenue', 'vat', 'excise'],
            'keyphrases': ['tax incentive', 'fiscal policy', 'vat exemption', 
                          'digital services tax', 'corporate tax', 'state aid',
                          'public funding', 'fiscal measure']
        },
        'procurement': {
            'keywords': ['procurement', 'tender', 'contract', 'vendor', 'supplier'],
            'keyphrases': ['public procurement', 'procurement process', 'vendor selection',
                          'procurement criteria', 'tender process', 'contract award']
        },
        'sovereignty': {
            'keywords': ['sovereignty', 'independence', 'autonomy', 'control'],
            'keyphrases': ['digital sovereignty', 'technological independence',
                          'strategic autonomy', 'data sovereignty']
        },
        'vendor-lock': {
            'keywords': ['lock', 'lockin', 'switching', 'proprietary', 'dependent'],
            'keyphrases': ['vendor lock', 'vendor lockin', 'switching cost',
                          'lock-in', 'proprietary software', 'dependency']
        },
        'security': {
            'keywords': ['security', 'vulnerability', 'breach', 'cyber', 'threat'],
            'keyphrases': ['cybersecurity', 'security audit', 'vulnerability assessment',
                          'security risk', 'cyber threat', 'security measure']
        }
    }
    
    if domain not in domain_configs:
        raise ValueError(f"Unknown domain: {domain}")
    
    return domain_configs[domain]

def get_unprocessed_responses(conn, domain: str, limit: Optional[int] = None, retry_failed: bool = False) -> List[Dict]:
    """Get responses that haven't been processed for LLM extraction"""
    domain_config = load_domain_config(conn, domain)
    
    # Build search pattern from keywords and keyphrases
    keywords = domain_config['keywords']
    keyphrases = domain_config['keyphrases']
    
    # Create pattern for full-text search
    search_terms = keywords + [phrase.replace(' ', ' & ') for phrase in keyphrases]
    tsquery = ' | '.join(search_terms)
    
    # Build WHERE clause based on retry flag
    if retry_failed:
        # Include both unprocessed AND failed
        where_clause = """
          AND (r.llm_extracted = FALSE OR r.llm_extraction_failed = TRUE)
        """
    else:
        # Only unprocessed (exclude failed)
        where_clause = """
          AND r.llm_extracted = FALSE
          AND r.llm_extraction_failed = FALSE
        """
    
    query = f"""
        SELECT 
            r.id,
            r.full_text,
            r.country,
            r.user_type,
            r.organization,
            r.llm_extraction_failed,
            r.llm_extraction_error
        FROM responses r
        WHERE r.full_text IS NOT NULL
          AND r.full_text != ''
          AND (
              r.fts_vector @@ to_tsquery('english', %s)
              OR lower(r.full_text) ~ %s
          )
          {where_clause}
        ORDER BY r.id
    """
    
    # Build regex pattern for domain matching
    regex_pattern = '|'.join([re.escape(kw) for kw in keywords + keyphrases])
    
    params = [tsquery, regex_pattern]
    
    if limit:
        query += " LIMIT %s"
        params.append(limit)
    
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(query, params)
        return cur.fetchall()

def extract_domain_text(full_text: str, domain_config: Dict, max_chars: int = 2500) -> str:
    """Extract domain-relevant paragraphs from full text"""
    if not full_text:
        return ""
    
    keywords = domain_config['keywords']
    keyphrases = domain_config['keyphrases']
    all_terms = keywords + keyphrases
    
    # Split into paragraphs
    paragraphs = re.split(r'\n\s*\n', full_text)
    
    # Score each paragraph by term occurrence
    scored_paragraphs = []
    for para in paragraphs:
        para_lower = para.lower()
        score = sum(1 for term in all_terms if term.lower() in para_lower)
        if score > 0:
            scored_paragraphs.append((score, para))
    
    # Sort by relevance
    scored_paragraphs.sort(reverse=True, key=lambda x: x[0])
    
    # Concatenate paragraphs until we hit max_chars
    extracted = []
    total_chars = 0
    for score, para in scored_paragraphs:
        if total_chars + len(para) > max_chars:
            break
        extracted.append(para)
        total_chars += len(para)
    
    return '\n\n'.join(extracted) if extracted else full_text[:max_chars]

def insert_position(conn, position_data: Dict) -> bool:
    """Insert extracted position into database"""
    query = """
        INSERT INTO position_analysis (
            response_id,
            domain,
            position_type,
            position_category,
            strength,
            argument_summary,
            evidence_cited,
            specific_proposal
        ) VALUES (
            %(response_id)s,
            %(domain)s,
            %(position_type)s,
            %(position_category)s,
            %(strength)s,
            %(argument_summary)s,
            %(evidence_cited)s,
            %(specific_proposal)s
        )
    """
    
    try:
        with conn.cursor() as cur:
            cur.execute(query, position_data)
        return True
    except Exception as e:
        print(f"ERROR: Failed to insert position: {e}", file=sys.stderr)
        return False

def mark_response_processed(conn, response_id: int, success: bool, error_msg: str = None):
    """Update response processing flags"""
    if success:
        query = "SELECT mark_extraction_success(%s)"
        params = [response_id]
    else:
        query = "SELECT mark_extraction_failed(%s, %s)"
        params = [response_id, error_msg or 'Unknown error']
    
    with conn.cursor() as cur:
        cur.execute(query, params)

# ============================================================================
# LLM Functions
# ============================================================================

def build_extraction_prompt(domain: str, text: str, response_id: int) -> str:
    """Build structured prompt for LLM position extraction"""
    
    prompt = f"""You are analyzing consultation responses about EU open digital ecosystems policy.

TASK: Extract stakeholder positions from the following response text about {domain}.

RESPONSE TEXT (ID: {response_id}):
{text}

---

Extract the following information and respond ONLY with valid JSON (no markdown, no explanation):

{{
  "positions": [
    {{
      "position_type": "support|oppose|neutral|mixed",
      "position_category": "brief category name (e.g., public_funding, tax_incentive, procurement_preference)",
      "strength": "strong|moderate|weak",
      "argument_summary": "1-2 sentence summary of core argument",
      "evidence_cited": ["citation 1", "citation 2"],
      "specific_proposal": "concrete policy ask if mentioned, otherwise empty string"
    }}
  ]
}}

RULES:
1. position_type must be exactly one of: support, oppose, neutral, mixed
2. strength must be exactly one of: strong, moderate, weak
3. A response may contain multiple positions (different categories)
4. If no clear position on {domain}, return {{"positions": []}}
5. position_category should be a short, specific identifier (underscore_separated)
6. evidence_cited is an array of strings (can be empty)
7. specific_proposal is a string (can be empty)
8. Respond with ONLY valid JSON, no markdown formatting

EXAMPLE POSITION CATEGORIES for {domain}:
- public_funding (government investment in OSS)
- tax_incentive (tax breaks for OSS adoption/development)
- vat_exemption (VAT waiver for OSS)
- digital_services_tax (tax on proprietary vendors)
- state_aid (public subsidies for OSS projects)
- procurement_preference (favorable treatment in public procurement)
(Choose specific categories like these, not generic ones)

STRENGTH DEFINITIONS:
- strong: Uses mandatory language ("must", "require", "essential", "critical")
- moderate: Uses prescriptive language ("should", "recommend", "important")
- weak: Uses suggestive language ("could", "might", "consider")

Extract positions now (JSON only):"""
    
    return prompt

def call_ollama(prompt: str) -> Optional[str]:
    """Call Ollama API with prompt and return response"""
    url = f"{OLLAMA_URL}/api/generate"
    
    payload = {
        'model': OLLAMA_MODEL,
        'prompt': prompt,
        'stream': False,
        'options': {
            'temperature': 0.1,  # Low temperature for consistent extraction
            'top_p': 0.9,
            'num_predict': 500   # Limit output length
        }
    }
    
    try:
        response = requests.post(url, json=payload, timeout=180)
        response.raise_for_status()
        result = response.json()
        return result.get('response', '')
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Ollama API call failed: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"ERROR: Unexpected error calling Ollama: {e}", file=sys.stderr)
        return None

def parse_llm_response(response_text: str) -> Optional[Dict]:
    """Parse and validate LLM JSON response"""
    if not response_text:
        return None
    
    # Strip markdown code fences if present
    response_text = response_text.strip()
    if response_text.startswith('```'):
        # Remove opening ```json or ```
        response_text = re.sub(r'^```(?:json)?\s*\n', '', response_text)
        # Remove closing ```
        response_text = re.sub(r'\n```\s*$', '', response_text)
    
    response_text = response_text.strip()
    
    try:
        data = json.loads(response_text)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON from LLM: {e}", file=sys.stderr)
        print(f"Response was: {response_text[:200]}", file=sys.stderr)
        return None
    
    # Validate structure
    if 'positions' not in data:
        print(f"ERROR: Missing 'positions' key in LLM response", file=sys.stderr)
        return None
    
    if not isinstance(data['positions'], list):
        print(f"ERROR: 'positions' is not a list", file=sys.stderr)
        return None
    
    return data

def validate_position(position: Dict) -> Tuple[bool, Optional[str]]:
    """Validate position data against schema constraints"""
    required_fields = ['position_type', 'position_category', 'strength', 
                      'argument_summary', 'evidence_cited', 'specific_proposal']
    
    for field in required_fields:
        if field not in position:
            return False, f"Missing required field: {field}"
    
    # Validate position_type
    if position['position_type'] not in VALID_POSITION_TYPES:
        return False, f"Invalid position_type: {position['position_type']}"
    
    # Validate strength
    if position['strength'] not in VALID_STRENGTHS:
        return False, f"Invalid strength: {position['strength']}"
    
    # Validate types
    if not isinstance(position['argument_summary'], str):
        return False, "argument_summary must be string"
    
    if not isinstance(position['evidence_cited'], list):
        return False, "evidence_cited must be array"
    
    if not isinstance(position['specific_proposal'], str):
        return False, "specific_proposal must be string"
    
    return True, None

# ============================================================================
# Main Processing
# ============================================================================

def process_response(conn, response: Dict, domain: str, verbose: bool = False) -> Tuple[bool, str]:
    """Process a single response through LLM extraction"""
    response_id = response['id']
    full_text = response['full_text']
    
    if verbose:
        print(f"Processing response {response_id} ({response['country']}, {response['user_type']})...")
    
    # Load domain config
    domain_config = load_domain_config(conn, domain)
    
    # Extract domain-relevant text
    domain_text = extract_domain_text(full_text, domain_config)
    
    if not domain_text:
        return False, "No domain-relevant text found"
    
    if verbose:
        print(f"  Extracted {len(domain_text)} chars of domain-relevant text")
    
    # Build prompt
    prompt = build_extraction_prompt(domain, domain_text, response_id)
    
    # Call LLM
    if verbose:
        print(f"  Calling Ollama API...")
    
    llm_response = call_ollama(prompt)
    
    if not llm_response:
        return False, "LLM API call failed"
    
    # Parse response
    parsed = parse_llm_response(llm_response)
    
    if not parsed:
        return False, f"Failed to parse LLM response: {llm_response[:200]}"
    
    positions = parsed['positions']
    
    if not positions:
        if verbose:
            print(f"  No positions extracted (response may be neutral or off-topic)")
        # This is not an error - mark as successfully processed with no positions
        return True, "No positions found"
    
    if verbose:
        print(f"  Extracted {len(positions)} position(s)")
    
    # Validate and insert each position
    inserted_count = 0
    for i, position in enumerate(positions):
        valid, error = validate_position(position)
        
        if not valid:
            print(f"WARNING: Invalid position {i+1} for response {response_id}: {error}", 
                  file=sys.stderr)
            continue
        
        position_data = {
            'response_id': response_id,
            'domain': domain,
            'position_type': position['position_type'],
            'position_category': position['position_category'],
            'strength': position['strength'],
            'argument_summary': position['argument_summary'],
            'evidence_cited': position['evidence_cited'],
            'specific_proposal': position['specific_proposal']
        }
        
        if insert_position(conn, position_data):
            inserted_count += 1
            if verbose:
                print(f"    Position {i+1}: {position['position_type']} - "
                      f"{position['position_category']} ({position['strength']})")
        else:
            print(f"ERROR: Failed to insert position {i+1} for response {response_id}", 
                  file=sys.stderr)
    
    if inserted_count == 0:
        return False, "No positions could be inserted"
    
    return True, f"Inserted {inserted_count} position(s)"

def main():
    parser = argparse.ArgumentParser(
        description='Extract stakeholder positions from consultation responses using LLM'
    )
    parser.add_argument('--domain', required=True, 
                       choices=['taxation', 'procurement', 'sovereignty', 'vendor-lock', 'security'],
                       help='Policy domain to process')
    parser.add_argument('--test', action='store_true',
                       help='Test mode: process only 5 responses')
    parser.add_argument('--limit', type=int,
                       help='Limit number of responses to process')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output')
    parser.add_argument('--retry-failed', action='store_true',
                       help='Retry previously failed extractions')
    
    args = parser.parse_args()
    
    # Determine limit
    if args.test:
        limit = 5
    elif args.limit:
        limit = args.limit
    else:
        limit = None
    
    print(f"LLM Position Extractor - Domain: {args.domain}")
    print(f"Ollama URL: {OLLAMA_URL}")
    print(f"Model: {OLLAMA_MODEL}")
    if limit:
        print(f"Processing limit: {limit} responses")
    print()
    
    # Connect to database
    conn = get_db_connection()
    conn.autocommit = False  # Use transactions
    
    try:
        # Get unprocessed responses
        print(f"Fetching unprocessed responses for {args.domain}...")
        if args.retry_failed:
            print("Including previously failed extractions for retry...")
        responses = get_unprocessed_responses(conn, args.domain, limit, args.retry_failed)
        
        if not responses:
            print(f"No unprocessed responses found for domain: {args.domain}")
            return 0
        
        print(f"Found {len(responses)} unprocessed response(s)")
        print()
        
        # Process each response
        success_count = 0
        failure_count = 0
        
        for i, response in enumerate(responses, 1):
            print(f"[{i}/{len(responses)}] Response {response['id']}...", end=' ')
            
            try:
                success, message = process_response(conn, response, args.domain, args.verbose)
                
                if success:
                    mark_response_processed(conn, response['id'], True)
                    conn.commit()
                    success_count += 1
                    if not args.verbose:
                        print(f"✓ {message}")
                else:
                    mark_response_processed(conn, response['id'], False, message)
                    conn.commit()
                    failure_count += 1
                    print(f"✗ {message}")
                    
            except Exception as e:
                conn.rollback()
                error_msg = f"Unexpected error: {str(e)}"
                mark_response_processed(conn, response['id'], False, error_msg)
                conn.commit()
                failure_count += 1
                print(f"✗ {error_msg}")
        
        print()
        print("="*60)
        print(f"Processing complete for {args.domain}")
        print(f"Successful: {success_count}")
        print(f"Failed: {failure_count}")
        print(f"Total: {len(responses)}")
        print("="*60)
        
        return 0 if failure_count == 0 else 1
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        conn.rollback()
        return 130
    except Exception as e:
        print(f"\nFATAL ERROR: {e}", file=sys.stderr)
        conn.rollback()
        return 1
    finally:
        conn.close()

if __name__ == '__main__':
    sys.exit(main())
