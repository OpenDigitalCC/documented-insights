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
```

The validation test checks infrastructure, database schema, domain configurations, scripts, and data loading for functional correctness. All tests should pass before proceeding to analysis. This is not a security audit.

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

# Convert to HTML
make html-report DOMAIN=taxation
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

# Convert to HTML
make html-report DOMAIN=taxation
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
```

Creates both: `domain_taxation_analysis_pattern.md` and `domain_taxation_analysis_llm.md`

For all domains (only after testing one):

```bash
# Run in background (3–5 days on CPU, 3–6 hours on GPU)
make llm-extract-all-bg

# Check progress periodically
make llm-summary
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

## Project Structure

```
documented-insights/
├── compose.yml              # Docker services
├── Dockerfile.perl          # Perl environment (all deps included)
├── .env                     # Environment config
├── Makefile                # All commands
│
├── data/                   # Source data
│   └── european-open-digital-ecosystems-all-responses.csv
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
│   ├── 01_load_json.pl
│   ├── 09_generate_domain_report.pl  # Pattern reports
│   ├── 10_generate_llm_report.pl     # LLM reports
│   ├── 10_llm_extract_positions.py   # LLM extraction
│   └── test_system_end_to_end.sh     # Validation
│
├── sql/                   # Database schema
│   └── 00_reset_database.sql
│
└── output/                # Generated reports
    ├── domain_*_analysis_pattern.md
    └── domain_*_analysis_llm.md
```

## Licence

AGPL-3.0 - See LICENCE file

Network Service Requirement
: If deployed as network service, must provide source code to users

## Support

Validation
: `bash scripts/test_system_end_to_end.sh`

Documentation
: PROJECT_SUMMARY.md for technical details

GitHub Issues
: Report bugs and requests
