# Documented Insights - Project Summary

## Project Status

Version
: 2.0 (LLM Integration Complete)

Date
: 6 February 2026

Status
: Research and Development proof-of-concept, functional testing complete, laboratory use only

::: textbox
No comprehensive security evaluation performed. Use at own risk.
:::

## Current Capabilities

### Pattern Analysis

Fast analysis capabilities:

- Word frequency and co-occurrence analysis
- Stakeholder sentiment indicators
- Geographic and organisational distribution
- Domain coverage statistics

Generation time
: Approximately 30 seconds per domain

### LLM Position Extraction

Complete integration:

- Stakeholder positions (support/oppose/neutral/mixed)
- Position categories and strength assessment
- Argument summaries and evidence citations
- Policy proposals and recommendations

Processing time
: 2–3 minutes per response (CPU) or 5–15 seconds per response (GPU)

### Report Generation

Markdown format
: Pattern and LLM sections generated separately

Conversion
: HTML via Pandoc

Report types
: Combined or standalone reports

Processing status
: Indicators in LLM reports show completion percentage

## System Architecture

```
Data Flow:
CSV Input (1,658 responses)
  ↓
PostgreSQL Database
  ├→ Pattern Analysis (Perl)
  │   └→ domain_*_analysis_pattern.md
  └→ LLM Position Extraction (Python + Ollama)
      └→ domain_*_analysis_llm.md

Services (Docker Compose):
- postgres: PostgreSQL 16 + full-text search
- perl: Debian Bookworm + Perl 5.40 + all modules
- embeddings: Python 3.11 + psycopg2 + requests
- ollama: LLM inference (llama3.1:8b)
```

## Technology Stack

### Core Languages

Perl 5.40
: Data processing, pattern analysis, report generation

Python 3.11
: LLM API integration

SQL (PostgreSQL)
: Data storage, full-text search, views

### Infrastructure

Docker + Docker Compose
: Container orchestration

PostgreSQL 16
: Database with full-text search extensions

Ollama
: Local or remote LLM inference

### Perl Modules

All included in Dockerfile.perl:

- DBI, DBD::Pg for database connectivity
- JSON for data parsing
- Time::HiRes for high-resolution timing
- LWP for HTTP requests

### Python Modules

psycopg2
: PostgreSQL driver

requests
: HTTP API calls to Ollama

### Tools

Pandoc
: Markdown to HTML/PDF conversion

Make
: Build automation and task running

poppler-utils
: PDF text extraction (for attachments)

## Database Schema

### Core Tables

responses
: 1,658 consultation responses with full-text vectors

response_words
: Word frequency analysis

word_frequency
: Aggregate word statistics

position_analysis
: LLM-extracted positions and arguments

stopwords
: Multilingual stop word lists

### Views

position_extraction_progress
: Per-domain processing statistics

llm_processing_status
: Overall extraction progress

position_summary
: Position distribution summaries

position_stakeholders
: Stakeholder position breakdowns

## Domain Configuration System

### Policy Domains

Five domains configured:

1. Taxation - Tax policy, fiscal measures (542 responses)
2. Procurement - Public procurement processes (763 responses)
3. Sovereignty - Digital sovereignty, autonomy (418 responses)
4. Vendor Lock-in - Technology dependencies (289 responses)
5. Security - Cybersecurity, data protection (621 responses)

Configuration files
: `domains/*.conf`

Each domain defines:

- Keywords (single words)
- Keyphrases (multi-word terms)
- Sub-themes for detailed analysis
- Sentiment indicators

### Pattern Matching

Full-text search
: Uses PostgreSQL tsvector

Keyword matching
: Case-insensitive, handles hyphenation variants

Configuration
: Via `.conf` files

## Processing Pipeline

### Phase 1: Data Loading

Script
: `scripts/01_load_json.pl`

Actions:

- Loads CSV data into PostgreSQL
- Creates full-text search vectors
- Indexes responses for fast querying

### Phase 2: Word Analysis

Script
: `scripts/03_build_word_index.pl`

Actions:

- Extracts word frequencies
- Filters stop words (multilingual)
- Builds co-occurrence matrices
- Stores in word_frequency table

### Phase 3: Pattern Analysis

Script
: `scripts/09_generate_domain_report.pl <domain>`

Actions:

- Queries domain-specific responses
- Analyses word patterns and sentiment
- Generates stakeholder breakdowns

Output
: `domain_<n>_analysis_pattern.md`

### Phase 4: LLM Position Extraction

Script
: `scripts/10_llm_extract_positions.py --domain <domain>`

Actions:

- Fetches unprocessed responses for domain
- Calls Ollama API with structured prompt
- Extracts positions, arguments, evidence, proposals
- Stores in position_analysis table

Transaction safety
: Commits per response

### Phase 5: LLM Report Generation

Script
: `scripts/10_generate_llm_report.pl <domain>`

Actions:

- Queries position_analysis table
- Generates position summaries
- Shows stakeholder distributions
- Includes processing status

Output
: `domain_<n>_analysis_llm.md`

## File Organisation

### Root

compose.yml
: Docker Compose services

Dockerfile.perl
: Perl container (all dependencies)

.env
: Environment variables (not in git)

.env.example
: Configuration template

Makefile
: Command automation (50+ targets)

README.md
: User documentation

PROJECT_SUMMARY.md
: This file

### Data

data/european-open-digital-ecosystems-all-responses.csv
: Source consultation data

### Domain Configurations

domains/
: Directory containing:
    - taxation.conf
    - procurement.conf
    - sovereignty.conf
    - vendor-lock.conf
    - security.conf

### Perl Modules

lib/DomainConfig.pm
: Parse domain .conf files

lib/DomainQuery.pm
: Domain-based SQL queries

lib/LLMPositionReport.pm
: LLM report generation

### Scripts

Critical scripts:

- 01_load_json.pl
- 02_extract_attachments.pl
- 03_build_word_index.pl
- 04_generate_embeddings.py
- 08_domain_query.pl
- 09_generate_domain_report.pl
- 10_generate_llm_report.pl
- 10_llm_extract_positions.py
- 11_llm_batch_extract.pl
- 12_llm_processing_summary.pl
- test_domain_config.pl
- test_system_end_to_end.sh

### Database

sql/
: Directory containing:
    - 00_reset_database.sql
    - 04_word_analysis.sql
    - 05_add_multilingual_stopwords.sql
    - 06_add_position_analysis.sql

### Output

output/
: Directory containing:
    - domain_*_analysis_pattern.md
    - domain_*_analysis_llm.md
    - logs/

## Deployment

::: textbox
Research and Development environment only. Not evaluated for production use.
:::

### System Requirements

Minimum (Pattern Analysis Only):

- 4 CPU cores
- 8GB RAM
- 5GB disk space
- Docker + Docker Compose

Recommended (Full LLM Analysis - CPU):

- 8 CPU cores
- 32GB RAM
- 20GB disk space

Optimal (Remote GPU):

- Local: 4 cores, 8GB RAM
- Remote: GPU VPS with CUDA support

### Installation Steps

#### 1. Environment Setup

```bash
cp .env.example .env
# Edit .env with database credentials and Ollama configuration
```

#### 2. Start Services

```bash
docker-compose up -d
# Starts: postgres, perl, embeddings, ollama
```

#### 3. Initialise Database

```bash
make reset  # Create schema
make load   # Load 1,658 responses
```

#### 4. Validate System

```bash
bash scripts/test_system_end_to_end.sh
# Runs 36 validation tests, all should pass
```

#### 5. Generate Reports

```bash
make report DOMAIN=taxation  # Pattern + LLM (if data exists)
```

### Remote GPU Configuration

Performance improvement
: 10–20x faster LLM extraction

Setup steps:

1. Install Ollama on GPU VPS: `ollama pull llama3.1:8b`
2. Create SSH tunnel: `ssh -f -N -L 11434:localhost:11434 user@gpu-vps`
3. Update .env: `OLLAMA_HOST=http://localhost:11434`
4. Restart extraction: `make llm-extract-all-bg`

Speed comparison:

CPU mode
: 2–3 minutes per response = 3–5 days for full dataset

GPU mode
: 5–15 seconds per response = 3–6 hours for full dataset

Security note
: Always use SSH tunnel or VPN. Never expose Ollama to public internet (no authentication).

## Key Commands

### System Validation

```bash
bash scripts/test_system_end_to_end.sh  # Full system test (2–3 minutes)
make test-domains                       # Validate domain configs
make db-stats                           # Database statistics
```

### Pattern Analysis

```bash
make query-domain DOMAIN=taxation       # Query domain responses
make report DOMAIN=taxation             # Generate reports
make reports-all                        # All domains
make html-report DOMAIN=taxation        # Convert to HTML
```

### LLM Extraction

```bash
make llm-summary                        # Processing status
make llm-extract DOMAIN=taxation        # Extract one domain
make llm-extract-all-bg                 # All domains (background)
make llm-status                         # Overall progress
make llm-positions DOMAIN=taxation      # View positions
```

## Performance Metrics

### Pattern Analysis

Query execution
: Less than 1 second

Report generation
: 20–40 seconds per domain

HTML conversion
: 5–10 seconds

### LLM Extraction

CPU mode
: 2–3 minutes per response

GPU mode
: 5–15 seconds per response

Full dataset (1,658 responses)
: 3–5 days (CPU) or 3–6 hours (GPU)

### Database

Responses table
: 1,658 rows

Position analysis
: 0–5,000 positions (when complete)

Word frequency
: Approximately 50,000 unique words

Full-text search
: Less than 100ms for domain queries

## Testing and Validation

Automated test suite
: `scripts/test_system_end_to_end.sh`

Tests 36 components for functional correctness:

- Infrastructure (Docker containers, database)
- Schema (tables, views, indexes)
- Data loading (responses, word frequency)
- Domain system (configs, queries)
- LLM extraction (optional - if data exists)
- Report generation (pattern and LLM)
- Module loading (Perl and Python)
- Script accessibility

Expected result
: All 36 tests pass

Test execution time
: 2–3 minutes

Scope
: Functional correctness only. Not a security audit.

## Known Limitations

1. Language - English-centric analysis (multilingual stop words supported)
2. LLM Speed - CPU extraction very slow (use GPU for production)
3. Model - Currently hardcoded to llama3.1:8b
4. Embeddings - Not used (table exists but empty - future enhancement)

## Future Enhancements

### Near-term

- Parallel LLM processing (multiple domains simultaneously)
- Resume capability for interrupted extraction
- Position quality scoring
- Cross-domain position comparison

### Medium-term

- Multi-language LLM prompts
- Alternative LLM models (Claude, GPT-4)
- Temporal analysis (track position evolution)
- Enhanced report templates

### Long-term

- Real-time consultation monitoring
- Predictive position analysis
- Automated response clustering
- Interactive visualisation dashboard

## Development Notes

### Code Organisation

Perl scripts
: Function-based, testable, single responsibility

Database
: Normalised schema, indexed for performance

Modules
: Reusable components in lib/

Configuration
: File-based (.conf, .env), not hardcoded

### Best Practices

Transaction safety
: Each response processed atomically

Error handling
: Graceful failures, logged to database

Testing
: Comprehensive validation suite

Documentation
: Inline comments, README, this summary

### Deployment

Containerised
: Easy deployment, reproducible environment

Environment-driven
: All configuration via .env

Make-based
: Simple command interface

Validated
: Automated testing before production

## Licence

AGPL-3.0

Network Service Requirement
: If deployed as network service accessible over network, must provide source code to users

## Contributors

Development
: Stuart (Technical consultant, system architect)

Documentation
: Complete (README.md, PROJECT_SUMMARY.md, inline comments)

## Version History

- v1.0 (Jan 2026): Pattern analysis system
- v2.0 (Feb 2026): LLM position extraction integrated
- Current: R&D proof-of-concept, functional tests passing, laboratory use only

For deployment
: See README.md

For validation
: Run `bash scripts/test_system_end_to_end.sh`

For operations
: See Makefile targets (`make help`)
