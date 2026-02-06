# EU Consultation Analysis - Documented Insights

Automated analysis system for EU consultation responses with pattern detection, domain classification, and LLM-powered position extraction.

Status
: Research and Development proof-of-concept v2.0 - Laboratory use only

::: widebox
**Experimental Code - Use at Own Risk**

No comprehensive security evaluation performed. Intended for research and laboratory analysis only.
:::

## Quick Start

```bash
# 1. Clone and navigate
cd /srv/docker-vol/docker-services/documented-insights

# 2. Configure environment
cp .env.example .env
# Edit .env with your credentials

# 3. Start services
docker-compose up -d

# 4. Load data
make reset          # Create database schema
make load           # Load consultation responses (1,658 responses)

# 5. Run validation test (2 minutes)
bash scripts/test_system_end_to_end.sh

# 6. Generate your first report
make report DOMAIN=taxation

# 7. Generate PDF
make report-pdf DOMAIN=taxation
```

The validation test checks infrastructure, database schema, domain configurations, scripts, and data loading for functional correctness. All tests should pass before proceeding to analysis. This is not a security audit.

## Adapting to Other EU Consultations

This system is designed for the **EU Open Digital Ecosystems** consultation but can easily be adapted to other EU consultations or similar text analysis tasks. The architecture separates data-specific configuration (domain definitions, keywords) from the analysis pipeline (database, pattern detection, LLM extraction).

To adapt to a different consultation
: Replace the JSON data source, update domain configurations with relevant keywords, and adjust LLM prompts if needed. See REPURPOSING_GUIDE.md for detailed instructions.

Typical adaptation effort
: 80–90% of code is reusable. Main changes are domain `.conf` files and data loader.

## Contributing - Adding New Domains

New policy domains can be added by creating simple configuration files. No code changes required.

### Creating a Domain Configuration

#### 1. Create Domain File

Create `domains/your-domain.conf`:

```
[domain]
name = Your Domain Name
description = Brief description of what this domain covers

[keywords]
# Single words to match
keyword1
keyword2
keyword3

[keyphrases]
# Multi-word phrases to match (higher weight than keywords)
"exact phrase to match"
"another phrase"

[related_words]
# Words that often appear with domain topics (lower weight)
related1
related2
```

**Example** - Climate policy domain:

```
[domain]
name = Climate Policy
description = Climate change mitigation, carbon pricing, green transition

[keywords]
climate
carbon
emissions
renewable
sustainability
green
transition

[keyphrases]
"climate change"
"carbon pricing"
"net zero"
"renewable energy"
"green deal"
"emission reduction"

[related_words]
energy
environmental
sustainable
paris
temperature
fossil
```

#### 2. Keyword Selection Guidelines

**Use specific terms**
: "interoperability" not "compatibility"

**Include variations**
: "tax", "taxation", "fiscal" for tax domain

**Weight by specificity**
: Keyphrases (highest) → Keywords (medium) → Related words (lowest)

**Avoid generic terms**
: Don't use "policy", "government", "regulation" unless domain-specific

**Check for conflicts**
: Review other domains to avoid overlap

#### 3. Test Configuration

```bash
# Validate syntax
make test-domains

# Test database query (without running)
make test-query-sql DOMAIN=your-domain

# Run actual query
make query-domain DOMAIN=your-domain

# Check coverage
# Aim for 50-200 responses per domain
# Too few = domain too narrow
# Too many = domain too broad or generic terms
```

#### 4. Generate Report

```bash
# Pattern analysis report
make report DOMAIN=your-domain

# Check output
cat output/domain_your-domain_analysis_pattern.md
```

#### 5. Optional - LLM Extraction

```bash
# Extract LLM positions
make llm-extract DOMAIN=your-domain

# Generate enhanced report
make report DOMAIN=your-domain

# Create PDF
make report-pdf DOMAIN=your-domain
```

### Domain Configuration Best Practices

**Start narrow, expand later**
: Begin with highly specific terms, add broader terms if coverage too low

**Test incrementally**
: Add 5-10 keywords, test coverage, adjust, repeat

**Use consultation language**
: Extract terms from actual consultation questions and responses

**Consider synonyms**
: "lock-in" vs "vendor lock-in", "OSS" vs "open source"

**Geographic variations**
: "digitalisation" (UK) vs "digitalization" (US)

**Check co-occurrence**
: Use `make search WORD=term` to find related terms

### Example - Adding "Data Governance" Domain

```bash
# 1. Create configuration
cat > domains/data-governance.conf << 'EOF'
[domain]
name = Data Governance
description = Data sharing, GDPR, privacy, data protection

[keywords]
data
privacy
GDPR
protection
sharing
governance
personal
consent

[keyphrases]
"data governance"
"data sharing"
"personal data"
"data protection"
"privacy regulation"
"GDPR compliance"
"data sovereignty"

[related_words]
regulation
compliance
controller
processor
rights
EOF

# 2. Test coverage
make query-domain DOMAIN=data-governance
# Check response count

# 3. Adjust if needed
nano domains/data-governance.conf

# 4. Generate report
make report DOMAIN=data-governance

# 5. Generate PDF
make report-pdf DOMAIN=data-governance
```

### Batch Report Generation

After adding multiple domains:

```bash
# Update DOMAINS list in Makefile
# Add your new domain to the list

# Generate all reports
make report-all

# Generate all PDFs
make report-pdf-all
```

### Troubleshooting

**Zero responses**
: Keywords too specific. Add broader terms or synonyms.

**Too many responses (>500)**
: Keywords too generic. Use more specific keyphrases.

**Overlap with other domains**
: Review keyword lists. Consider consolidating domains or using more distinctive terms.

**Poor relevance**
: Check actual responses with `make query-domain DOMAIN=X`. Adjust keywords based on real content.

## What It Does

Analyses 1,658 EU consultation responses across 5 policy domains.

### Pattern Analysis

Fast (minutes)
: Word frequency and term co-occurrence, stakeholder sentiment indicators, geographic and organisational distribution, domain coverage statistics

Generation time
: Approximately 30 seconds per domain

### LLM Position Extraction

Slower (hours or days)
: Stakeholder positions (support/oppose/neutral/mixed), position categories and strength scores, argument summaries and evidence citations, policy proposals and recommendations

Processing time
: 2–3 minutes per response (CPU) or 5–15 seconds per response (GPU)

Complete analysis
: 5 domains × approximately 500 responses = approximately 40 hours (CPU) or approximately 2 hours (GPU)

### PDF Report Generation

Combined reports
: Pattern analysis + LLM positions in single PDF

Generation time
: 10–20 seconds per domain

Output
: Professional LaTeX-formatted PDFs with table of contents, proper pagination, UTF-8 encoded

**Note**: Current implementation handles mixed-encoding source data (UTF-8/Latin-1/Windows-1252) and automatically converts to clean UTF-8 for PDF generation. See TODO.md for planned input normalization improvements.

## System Requirements

### Minimum (Pattern Analysis Only)

- 4 CPU cores
- 8GB RAM
- 5GB disk space
- Docker + Docker Compose

### Recommended (Full LLM Analysis)

CPU Mode
: 8 CPU cores, 32GB RAM, 20GB disk

GPU Mode
: Remote GPU VPS + 4 local cores, 8GB local RAM

## Installation

::: textbox
Laboratory use only. No security audit performed. Install at your own risk.
:::

### Prerequisites

```bash
# Docker and Docker Compose installed
docker --version
docker-compose --version

# Sufficient disk space
df -h /srv  # Need 20GB free
```

### Setup Steps

#### 1. Project Structure

```bash
cd /srv/docker-vol/docker-services
git clone <repository> documented-insights
cd documented-insights
```

#### 2. Environment Configuration

```bash
# Copy example configuration
cp .env.example .env

# Edit with your settings
nano .env
```

Required settings:

```bash
POSTGRES_USER=sysadmin
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=documented_insights
POSTGRES_HOST=postgres

# For local Ollama (default)
OLLAMA_HOST=http://ollama:11434
OLLAMA_MODEL=llama3.1:8b

# For remote GPU (see Remote GPU Setup below)
# OLLAMA_HOST=http://localhost:11434  # SSH tunnel
# OLLAMA_HOST=http://gpu-vps-ip:11434  # Direct
```

#### 3. Start Services

```bash
# Build and start containers
docker-compose up -d

# Verify all containers running
docker ps
```

Expected containers:

- documented-insights-postgres
- documented-insights-perl  
- documented-insights-embeddings
- documented-insights-ollama

#### 4. Database Setup

```bash
# Create schema
make reset

# Load consultation data
make load

# Verify data loaded
make db-stats
```

Expected output shows 1658 responses across 5 domains.

#### 5. Run Validation Tests

```bash
# Comprehensive system validation (2–3 minutes)
bash scripts/test_system_end_to_end.sh
```

Expected output: "All tests passed! System is operational."

If tests fail:

Infrastructure tests
: Check `docker ps`, verify containers running

Database tests
: Check `make db-stats`, verify data loaded

Domain tests
: Check `make test-domains`, verify configs valid

Script tests
: Check file permissions with `ls -l scripts/*.pl`

#### 6. Generate Initial Reports

```bash
# Pattern analysis (fast - 30 seconds each)
make report DOMAIN=taxation
make report DOMAIN=procurement

# View reports
ls -lh output/domain_*_analysis_pattern.md

# Generate PDFs
make report-pdf DOMAIN=taxation
make report-pdf DOMAIN=procurement

# View PDFs
ls -lh output/pdf/
```

## Remote GPU Setup (10–20x Faster)

For large-scale LLM extraction, use a remote GPU VPS.

### Why Remote GPU?

CPU mode
: 2–3 minutes per response = 3–5 days for full analysis

GPU mode
: 5–15 seconds per response = 3–6 hours for full analysis

Cost comparison
: Approximately £1/hour GPU rental versus 5 days of local CPU

### Setup Steps

#### 1. On GPU VPS

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull the same model
ollama pull llama3.1:8b

# Verify
ollama list
```

#### 2. Secure Connection

Choose one of these options:

::: textbox
Never expose Ollama to public internet - it has no authentication
:::

Option A: SSH Tunnel (Recommended - Most Secure)

```bash
# On your Docker host, create tunnel:
ssh -f -N -L 11434:localhost:11434 user@gpu-vps

# Tunnel stays open in background
# Remote Ollama now accessible at localhost:11434
```

Option B: Tailscale VPN (Best for Production)

```bash
# Install Tailscale on both machines
# Use Tailscale IP in configuration
```

Option C: Direct Connection (Private Network Only)

```bash
# On GPU VPS firewall:
sudo ufw allow from YOUR_DOCKER_HOST_IP to any port 11434
```

#### 3. Update Configuration

```bash
cd /srv/docker-vol/docker-services/documented-insights

# Edit .env
nano .env
```

For SSH tunnel:

```bash
OLLAMA_HOST=http://localhost:11434
```

For direct connection:

```bash
OLLAMA_HOST=http://gpu-vps-ip:11434
```

For Tailscale:

```bash
OLLAMA_HOST=http://100.x.x.x:11434
```

#### 4. Test Connection

```bash
# Test from embeddings container
docker exec documented-insights-embeddings python -c "
import os
import requests
url = os.getenv('OLLAMA_HOST', 'http://ollama:11434')
resp = requests.get(f'{url}/api/tags')
print(f'Connected to: {url}')
print(f'Status: {resp.status_code}')
"
```

Expected output: "Connected to: http://... Status: 200"

#### 5. Restart LLM Extraction

```bash
# Stop current extraction (if running)
pkill -f "10_llm_extract_positions.py"

# Start with remote GPU
make llm-extract-all-bg

# Monitor progress (should be 10–20x faster)
tail -f output/logs/llm_extraction_*.log
make llm-summary  # Check every 10 minutes
```

## Usage

### Pattern Analysis

No LLM required.

```bash
# Query domain responses
make query-domain DOMAIN=taxation

# Generate pattern report
make report DOMAIN=taxation
```

Creates: `domain_taxation_analysis_pattern.md`

```bash
# Generate all domain reports
make reports-all

# Generate PDFs
make report-pdf DOMAIN=taxation
make report-pdf-all
```

### LLM Position Extraction

Test on one domain first before running all domains.

```bash
# Check current status
make llm-summary

# Extract positions for one domain (test - approximately 20 hours on CPU)
make llm-extract DOMAIN=taxation

# Monitor progress
make llm-status      # Overall statistics
make llm-progress    # Per-domain breakdown

# Generate LLM-enhanced report
make report DOMAIN=taxation

# Generate PDF
make report-pdf DOMAIN=taxation
```

Creates both: `domain_taxation_analysis_pattern.md` and `domain_taxation_analysis_llm.md`, combined into `domain_taxation_analysis.pdf`

For all domains (only after testing one):

```bash
# Run in background (3–5 days on CPU, 3–6 hours on GPU)
make llm-extract-all-bg

# Check progress periodically
make llm-summary

# Generate all reports and PDFs
make report-full-all
```

## Key Commands Reference

### System Management

```bash
make help          # Show all available commands
make db-stats      # Database statistics
make db-shell      # PostgreSQL shell
bash scripts/test_system_end_to_end.sh  # Validate system
```

### Domain System

```bash
make test-domains             # Validate domain configurations
make list-domains             # Show available domains
make query-domain DOMAIN=X    # Query domain responses
```

### Pattern Analysis

```bash
make report DOMAIN=X          # Generate pattern report
make reports-all              # Generate all domain reports
make html-report DOMAIN=X     # Convert to HTML
```

### LLM Position Extraction

```bash
make llm-summary              # Processing status by domain
make llm-extract DOMAIN=X     # Extract one domain
make llm-extract-all-bg       # Extract all domains (background)
make llm-positions DOMAIN=X   # View extracted positions
```

### PDF Generation

```bash
make report-pdf DOMAIN=X      # Generate combined PDF (pattern + LLM)
make report-pdf-all           # Generate all PDFs
make report-full DOMAIN=X     # Markdown + PDF in one command
make report-full-all          # Everything for all domains
make clean-pdf                # Remove generated PDFs
```

## Known Issues and Limitations

### Current Limitations

**No security audit**
: Laboratory use only. Not evaluated for production deployment.

**Mixed source encodings**
: Input data contains UTF-8, Latin-1, and Windows-1252 from multiple submission sources. Currently handled at PDF generation stage. See TODO.md for planned input normalization.

**Single language optimization**
: Optimized for English consultation responses. German and other EU language responses present.

**CPU processing slow**
: LLM extraction takes 3–5 days on CPU. Use remote GPU for production analysis.

**No incremental LLM updates**
: Changing LLM prompts requires re-extraction of all responses for that domain.

### Workarounds

Mixed encodings
: Automatic conversion to UTF-8 during PDF generation via `combine_reports_for_pdf.pl`. Works correctly but adds processing overhead.

Slow CPU processing
: Use remote GPU setup (reduces 3–5 days to 3–6 hours).

Incremental updates
: Track extraction timestamps in database for future optimization.

## Troubleshooting

### Validation Tests Failing

```bash
# Re-run tests
bash scripts/test_system_end_to_end.sh

# Check infrastructure
docker ps

# Check database
make db-stats

# Check domain configs
make test-domains
```

### LLM Extraction Not Processing

```bash
# Check if extraction is running
ps aux | grep llm_extract

# Check Ollama connection
docker exec documented-insights-embeddings curl http://ollama:11434/api/tags

# Restart extraction
pkill -f "10_llm_extract_positions.py"
make llm-extract DOMAIN=taxation
```

### Remote GPU Not Connecting

```bash
# Test SSH tunnel
ssh user@gpu-vps curl http://localhost:11434/api/tags

# Test from container
docker exec documented-insights-embeddings curl $OLLAMA_HOST/api/tags

# Verify model loaded
ssh user@gpu-vps ollama list
```

### PDF Generation Errors

```bash
# Test Pandoc installation
make test-pandoc

# Check encoding of markdown files
file -i output/domain_taxation_analysis_pattern.md

# Verify header template exists
ls -l pandoc-header-template.yaml

# Check LaTeX packages
docker exec documented-insights-perl xelatex --version
```

## Project Structure

```
documented-insights/
├── compose.yml              # Docker services
├── Dockerfile.perl          # Perl environment (all deps included)
├── .env                     # Environment config
├── Makefile                # All commands
│
├── data/                   # Source data
│   └── all.json            # JSON source (canonical)
│
├── domains/                # Domain configurations
│   ├── taxation.conf
│   ├── procurement.conf
│   ├── sovereignty.conf
│   ├── vendor-lock.conf
│   └── security.conf
│
├── lib/                    # Perl modules
│   ├── DomainConfig.pm
│   ├── DomainQuery.pm
│   └── LLMPositionReport.pm
│
├── scripts/               # Processing pipeline
│   ├── 02_load_json.pl
│   ├── 09_generate_domain_report.pl  # Pattern reports
│   ├── 10_generate_llm_report.pl     # LLM reports
│   ├── 10_llm_extract_positions.py   # LLM extraction
│   ├── combine_reports_for_pdf.pl    # PDF generation helper
│   └── test_system_end_to_end.sh     # Validation
│
├── sql/                   # Database schema
│   └── 01_initial_schema.sql
│
├── output/                # Generated reports
│   ├── domain_*_analysis_pattern.md
│   ├── domain_*_analysis_llm.md
│   └── pdf/               # Generated PDFs
│       └── domain_*_analysis.pdf
│
├── pandoc-header-template.yaml  # PDF styling
│
├── README.md              # This file
├── PROJECT_SUMMARY.md     # Technical reference
├── AI_DISCLOSURE.md       # Development process
├── REPURPOSING_GUIDE.md   # Adapting to other datasets
└── TODO.md                # Planned improvements
```

## Development and Testing

### Validation Tests

```bash
# Full system test (36 tests, ~2 minutes)
bash scripts/test_system_end_to_end.sh

# Individual test categories
bash scripts/test_infrastructure.sh       # Docker, containers
bash scripts/test_database_schema.sh      # PostgreSQL schema
bash scripts/test_domain_configs.sh       # Domain .conf files
bash scripts/test_perl_scripts.sh         # Perl dependencies
bash scripts/test_data_loading.sh         # JSON → PostgreSQL
```

### Adding Test Coverage

Tests validate
: Functional correctness, data integrity, configuration validity, dependency availability

Tests do not validate
: Security vulnerabilities, performance under load, data privacy compliance

## Licence

AGPL-3.0-or-later

Open source infrastructure analysis. Derived works must also be open source under AGPL.

## Acknowledgements

Human Direction
: Stuart - Architectural decisions, requirements specification, functional testing, and approval for R&D use

AI Implementation
: Claude (Anthropic) - Code implementation, documentation, testing infrastructure

Project Status
: Research and Development proof-of-concept for laboratory use only. No comprehensive security evaluation performed. Use at your own risk.

See AI_DISCLOSURE.md for detailed human-AI collaboration information.

## See Also

**Core Documentation**
- README.md (this file) - Installation, usage, quick start
- PROJECT_SUMMARY.md - Technical architecture and deployment details  
- AI_DISCLOSURE.md - Human-AI collaboration in development
- TODO.md - Planned improvements and known technical debt

**Guides**
- REPURPOSING_GUIDE.md - Adapting system to other consultations/datasets
- COMBINED_PDF_QUICKSTART.md - PDF generation quick start
- ENCODING_FIX_COMPLETE.md - Character encoding technical details

**For Issues**
- Check validation tests first: `bash scripts/test_system_end_to_end.sh`
- Check domain configurations: `make test-domains`
- Review TODO.md for known limitations

## Support

Validation
: `bash scripts/test_system_end_to_end.sh`

Documentation
: PROJECT_SUMMARY.md for technical details, REPURPOSING_GUIDE.md for adaptation

GitHub Issues
: Report bugs and requests
