# Makefile for documented-insights
# EU Open Digital Ecosystems Consultation Analysis

# ============================================================================
# CONFIGURATION
# ============================================================================

# Container names (from compose.yml)
POSTGRES_CONTAINER := documented-insights-postgres
OLLAMA_CONTAINER := documented-insights-ollama
EMBEDDINGS_CONTAINER := documented-insights-embeddings
PERL_CONTAINER := documented-insights-perl

# Database config (from .env)
POSTGRES_USER := sysadmin
POSTGRES_DB := documented_insights

# Domain list
DOMAINS := taxation procurement sovereignty vendor-lock security

.PHONY: help help-domains help-llm help-all

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "documented-insights - EU consultation analysis"
	@echo ""
	@echo "=== SETUP ==="
	@echo "  make reset              - Reset database to clean state"
	@echo "  make load               - Load JSON data into PostgreSQL"
	@echo "  make download-attachments - Download PDFs/DOCX from EC website"
	@echo "  make extract            - Extract text from attachments"
	@echo "  make index              - Build word frequency index"
	@echo "  make generate-embeddings - Generate semantic embeddings (30-40 min)"
	@echo ""
	@echo "=== PATTERN ANALYSIS ==="
	@echo "  make word-stats         - Show word frequency analysis"
	@echo "  make search WORD=X      - Search word co-occurrences"
	@echo "  make query-domain DOMAIN=X - Query database for domain"
	@echo "  make report DOMAIN=X    - Generate markdown report"
	@echo "  make html-report DOMAIN=X - Convert report to HTML"
	@echo ""
	@echo "=== LLM POSITION EXTRACTION ==="
	@echo "  make llm-schema         - Install LLM database schema"
	@echo "  make llm-extract DOMAIN=X - Extract positions for domain"
	@echo "  make llm-extract-all-bg - Background batch extraction (all domains)"
	@echo "  make llm-status         - Check extraction progress"
	@echo "  make llm-report DOMAIN=X - Generate LLM-enhanced report"
	@echo ""
	@echo "=== WORKFLOWS ==="
	@echo "  make overnight          - Run full pipeline (extract + index)"
	@echo "  make query-all-domains  - Quick query all domains"
	@echo "  make reports-all        - Generate all domain reports"
	@echo "  make llm-reports-all    - Generate all LLM-enhanced reports"
	@echo ""
	@echo "=== UTILITIES ==="
	@echo "  make db-stats           - Show database statistics"
	@echo "  make db-shell           - Open PostgreSQL shell"
	@echo "  make check-embeddings   - Check embedding coverage"
	@echo "  make clean              - Remove old files"
	@echo ""
	@echo "For detailed help: make help-all"

help-all: help help-domains help-llm

help-domains:
	@echo ""
	@echo "=== DOMAIN ANALYSIS SYSTEM ==="
	@echo ""
	@echo "Configuration & Testing:"
	@echo "  make test-domains           - Test all domain configurations"
	@echo "  make validate-domains       - Validate configurations"
	@echo "  make test-query-sql DOMAIN=X - Test SQL generation (no database)"
	@echo "  make list-domains           - List available domains"
	@echo "  make show-domain DOMAIN=X   - Show domain configuration details"
	@echo ""
	@echo "Analysis & Reporting:"
	@echo "  make query-domain DOMAIN=X  - Query database for domain"
	@echo "  make report DOMAIN=X        - Generate markdown report"
	@echo "  make html-report DOMAIN=X   - Convert markdown to HTML"
	@echo "  make query-all-domains      - Quick query all domains"
	@echo "  make reports-all            - Generate all domain reports"
	@echo ""
	@echo "Available domains:"
	@echo "  - taxation        Tax policy, levies, fiscal incentives"
	@echo "  - procurement     Public procurement practices and barriers"
	@echo "  - sovereignty     Digital sovereignty and strategic autonomy"
	@echo "  - vendor-lock     Vendor lock-in and switching costs"
	@echo "  - security        Cybersecurity, privacy, vulnerabilities"

help-llm:
	@echo ""
	@echo "=== LLM POSITION EXTRACTION SYSTEM ==="
	@echo ""
	@echo "Setup:"
	@echo "  make llm-schema             - Install database schema (one-time)"
	@echo ""
	@echo "Position Extraction:"
	@echo "  make llm-extract DOMAIN=X   - Extract positions for one domain"
	@echo "  make llm-extract-all        - Batch extract all domains (foreground)"
	@echo "  make llm-extract-all-bg     - Batch extract all domains (background)"
	@echo "  make llm-retry-failed DOMAIN=X - Retry failed extractions"
	@echo "  make llm-retry-all-failed   - Retry all failures across all domains"
	@echo ""
	@echo "Status & Review:"
	@echo "  make llm-status             - Overall extraction progress"
	@echo "  make llm-summary            - Processing summary by domain"
	@echo "  make llm-progress           - Progress by domain"
	@echo "  make llm-positions DOMAIN=X - Position summary for domain"
	@echo "  make llm-stakeholders DOMAIN=X - Stakeholder breakdown"
	@echo "  make llm-proposals DOMAIN=X - Specific proposals mentioned"
	@echo "  make llm-evidence DOMAIN=X  - Evidence citations"
	@echo ""
	@echo "Report Generation:"
	@echo "  make llm-report DOMAIN=X    - Generate LLM-enhanced report"
	@echo "  make llm-reports-all        - Generate all LLM-enhanced reports"
	@echo ""
	@echo "Maintenance:"
	@echo "  make llm-reset DOMAIN=X     - Reset extraction for domain (careful!)"
	@echo ""
	@echo "Monitoring (during batch processing):"
	@echo "  tail -f output/logs/llm_extraction_*.log"
	@echo "  docker logs -f documented-insights-embeddings"

# ============================================================================
# DATABASE SETUP
# ============================================================================

reset:
	@echo "Resetting database..."
	docker exec -i $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d postgres < sql/00_reset_database.sql
	@echo "Database reset complete."

load:
	@echo "Loading JSON data..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/01_load_json.pl

# ============================================================================
# DATA EXTRACTION
# ============================================================================

download-attachments:
	@echo "Downloading attachments from EC website..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/02a_download_attachments.pl

extract:
	@echo "Extracting text from attachments..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/02_extract_attachments.pl

retry-extractions:
	@echo "Retrying failed extractions..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/02b_retry_failed_extractions.pl

redownload-corrupt:
	@echo "Re-downloading corrupt files..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/02d_redownload_corrupt.pl

# ============================================================================
# WORD FREQUENCY ANALYSIS
# ============================================================================

index:
	@echo "Building word frequency index..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/03_build_word_index.pl

word-stats:
	@echo "Word frequency analysis..."
	docker exec -i $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < sql/04_word_analysis.sql

search:
	@test -n "$(WORD)" || (echo "Usage: make search WORD=sovereignty" && exit 1)
	@echo "Searching co-occurrences for: $(WORD)"
	@docker exec $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -t -c \
	"SELECT w2.word || ' (' || COUNT(*) || ')' \
	 FROM response_words w1 \
	 JOIN response_words w2 ON w1.response_id = w2.response_id \
	 WHERE w1.word = '$(WORD)' AND w2.word != '$(WORD)' \
	 GROUP BY w2.word ORDER BY COUNT(*) DESC LIMIT 30;"

markdown-report:
	@echo "Generating word frequency Markdown report..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/06_generate_markdown_report.pl

word-html-report: markdown-report
	@echo "Converting to HTML..."
	docker exec $(PERL_CONTAINER) pandoc \
		-f markdown \
		-t html \
		-s \
		--self-contained \
		-o /app/output/word_frequency_analysis.html \
		/app/output/word_frequency_analysis.md
	@echo "Report available at: output/word_frequency_analysis.html"

# ============================================================================
# SEMANTIC EMBEDDINGS
# ============================================================================

generate-embeddings:
	@echo "Generating embeddings (this will take 30-40 minutes)..."
	@echo "Installing dependencies..."
	docker exec $(EMBEDDINGS_CONTAINER) pip install --break-system-packages sentence-transformers psycopg2-binary numpy 2>/dev/null || true
	@echo "Generating embeddings for all responses..."
	docker exec $(EMBEDDINGS_CONTAINER) python /app/scripts/04_generate_embeddings.py

check-embeddings:
	@echo "Checking embedding status..."
	@docker exec $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c \
	"SELECT COUNT(*) as total_responses, \
	        (SELECT COUNT(*) FROM response_embeddings) as with_embeddings, \
	        ROUND(100.0 * (SELECT COUNT(*) FROM response_embeddings) / COUNT(*), 1) as pct_complete \
	 FROM responses;"

# ============================================================================
# DOMAIN ANALYSIS SYSTEM
# ============================================================================

# Configuration and testing
test-domains:
	@echo "Testing domain configurations..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/test_domain_config.pl

validate-domains:
	@echo "Validating domain configurations..."
	@docker exec $(PERL_CONTAINER) perl /app/scripts/test_domain_config.pl
	@echo ""
	@echo "Validation complete. Review any warnings above."

test-query-sql:
	@test -n "$(DOMAIN)" || (echo "Usage: make test-query-sql DOMAIN=taxation" && exit 1)
	@echo "Testing SQL generation for domain: $(DOMAIN)"
	docker exec $(PERL_CONTAINER) perl /app/scripts/test_domain_query.pl $(DOMAIN)

list-domains:
	@echo "Available domains:"
	@docker exec $(PERL_CONTAINER) find /app/domains -name "*.conf" -exec basename {} .conf \;

show-domain:
	@test -n "$(DOMAIN)" || (echo "Usage: make show-domain DOMAIN=taxation" && exit 1)
	@echo "Domain configuration: $(DOMAIN)"
	@docker exec $(PERL_CONTAINER) cat /app/domains/$(DOMAIN).conf

# Database queries
query-domain:
	@test -n "$(DOMAIN)" || (echo "Usage: make query-domain DOMAIN=taxation" && exit 1)
	@echo "Querying domain: $(DOMAIN)"
	docker exec $(PERL_CONTAINER) perl /app/scripts/08_domain_query.pl $(DOMAIN)

query-all-domains:
	@echo "Querying all domains (quick overview)..."
	@for domain in $(DOMAINS); do \
		echo ""; \
		echo "=== $$domain ==="; \
		docker exec $(PERL_CONTAINER) perl /app/scripts/08_domain_query.pl $$domain 2>/dev/null | head -20; \
	done

# Report generation
report:
	@test -n "$(DOMAIN)" || (echo "Usage: make report DOMAIN=taxation" && exit 1)
	@echo "Generating reports for: $(DOMAIN)"
	@echo ""
	@echo "1. Pattern analysis report..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/09_generate_domain_report.pl $(DOMAIN)
	@echo ""
	@echo "2. LLM positions report..."
	docker exec $(PERL_CONTAINER) perl /app/scripts/10_generate_llm_report.pl $(DOMAIN)
	@echo ""
	@echo "Reports generated:"
	@echo "  Pattern:   output/domain_$(DOMAIN)_analysis_pattern.md"
	@echo "  LLM:       output/domain_$(DOMAIN)_analysis_llm.md"
	@echo ""
	@echo "Combine with: cat output/domain_$(DOMAIN)_analysis_*.md > output/domain_$(DOMAIN)_analysis.md"

html-report:
	@test -n "$(DOMAIN)" || (echo "Usage: make html-report DOMAIN=taxation" && exit 1)
	@test -f output/domain_$(DOMAIN)_analysis_pattern.md || (echo "Pattern report not found. Run: make report DOMAIN=$(DOMAIN)" && exit 1)
	@echo "Converting to HTML: $(DOMAIN)"
	@echo ""
	@echo "Pattern report..."
	docker exec $(PERL_CONTAINER) pandoc \
		-f markdown \
		-t html \
		-s \
		--self-contained \
		-o /app/output/domain_$(DOMAIN)_analysis_pattern.html \
		/app/output/domain_$(DOMAIN)_analysis_pattern.md
	@if [ -f output/domain_$(DOMAIN)_analysis_llm.md ]; then \
		echo "LLM report..."; \
		docker exec $(PERL_CONTAINER) pandoc \
			-f markdown \
			-t html \
			-s \
			--self-contained \
			-o /app/output/domain_$(DOMAIN)_analysis_llm.html \
			/app/output/domain_$(DOMAIN)_analysis_llm.md; \
	fi
	@echo "HTML reports: output/domain_$(DOMAIN)_analysis_*.html"

reports-all:
	@echo "Generating all domain reports..."
	@for domain in $(DOMAINS); do \
		echo ""; \
		echo "Generating $$domain..."; \
		docker exec $(PERL_CONTAINER) perl /app/scripts/09_generate_domain_report.pl $$domain; \
		docker exec $(PERL_CONTAINER) perl /app/scripts/10_generate_llm_report.pl $$domain; \
	done
	@echo ""
	@echo "All reports generated in output/"
	@echo "Pattern reports: domain_*_analysis_pattern.md"
	@echo "LLM reports:     domain_*_analysis_llm.md"

# ============================================================================
# LLM POSITION EXTRACTION
# ============================================================================

# Schema setup (one-time)
llm-schema:
	@echo "Installing LLM position analysis schema..."
	docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-f /docker-entrypoint-initdb.d/06_add_position_analysis.sql
	@echo "Schema installation complete"

# Position extraction
llm-extract:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-extract DOMAIN=taxation" && exit 1)
	@echo "Extracting positions for DOMAIN=$(DOMAIN)..."
	docker exec -it $(EMBEDDINGS_CONTAINER) \
		python /app/scripts/10_llm_extract_positions.py \
		--domain $(DOMAIN)

llm-extract-all:
	@echo "Batch extracting positions for all domains..."
	@echo "Started: $$(date)"
	@for domain in taxation procurement sovereignty vendor-lock security; do \
		echo ""; \
		echo "========================================"; \
		echo "Processing domain: $$domain"; \
		echo "========================================"; \
		docker exec $(EMBEDDINGS_CONTAINER) \
			python /app/scripts/10_llm_extract_positions.py --domain $$domain; \
		if [ $$? -eq 0 ]; then \
			echo "✓ $$domain completed successfully"; \
		else \
			echo "⚠ $$domain completed with errors"; \
		fi; \
	done
	@echo ""
	@echo "========================================"
	@echo "Batch extraction complete"
	@echo "Finished: $$(date)"
	@echo "========================================"
	@echo ""
	@echo "Check results: make llm-status"

llm-extract-all-bg:
	@echo "Starting background batch extraction..."
	@nohup make llm-extract-all > output/logs/llm_extraction_$$(date +%Y%m%d_%H%M%S).log 2>&1 &
	@echo "Running in background. Check progress with:"
	@echo "  tail -f output/logs/llm_extraction_*.log"

llm-retry-failed:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-retry-failed DOMAIN=taxation" && exit 1)
	@echo "Retrying failed extractions for DOMAIN=$(DOMAIN)..."
	docker exec -it $(EMBEDDINGS_CONTAINER) \
		python /app/scripts/10_llm_extract_positions.py \
		--domain $(DOMAIN) --retry-failed

llm-retry-all-failed:
	@echo "Retrying all failed extractions across all domains..."
	@for domain in taxation procurement sovereignty vendor-lock security; do \
		echo "Retrying: $$domain"; \
		docker exec $(EMBEDDINGS_CONTAINER) \
			python /app/scripts/10_llm_extract_positions.py --domain $$domain --retry-failed; \
	done
	@echo "Retry pass complete"

# Status and review
llm-status:
	@echo "LLM Processing Status:"
	@docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT * FROM llm_processing_status;"

llm-summary:
	@docker exec $(PERL_CONTAINER) \
		perl /app/scripts/12_llm_processing_summary.pl

llm-progress:
	@echo "Extraction Progress by Domain:"
	@docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT * FROM position_extraction_progress;"

llm-positions:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-positions DOMAIN=taxation" && exit 1)
	@echo "Position Summary for $(DOMAIN):"
	@docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT * FROM position_summary WHERE domain = '$(DOMAIN)';"

llm-stakeholders:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-stakeholders DOMAIN=taxation" && exit 1)
	@echo "Stakeholder Distribution for $(DOMAIN):"
	@docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT * FROM position_stakeholders WHERE domain = '$(DOMAIN)' ORDER BY response_count DESC LIMIT 20;"

llm-proposals:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-proposals DOMAIN=taxation" && exit 1)
	@echo "Positions with Specific Proposals ($(DOMAIN)):"
	@docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT r.country, r.user_type, p.position_category, p.specific_proposal FROM position_analysis p JOIN responses r ON p.response_id = r.id WHERE p.domain = '$(DOMAIN)' AND p.specific_proposal IS NOT NULL LIMIT 20;"

llm-evidence:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-evidence DOMAIN=taxation" && exit 1)
	@echo "Positions with Evidence Citations ($(DOMAIN)):"
	@docker exec $(POSTGRES_CONTAINER) \
		psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT r.country, r.user_type, p.position_category, array_length(p.evidence_cited, 1) as citation_count FROM position_analysis p JOIN responses r ON p.response_id = r.id WHERE p.domain = '$(DOMAIN)' AND array_length(p.evidence_cited, 1) > 0 ORDER BY citation_count DESC LIMIT 20;"

# Report generation with LLM positions
llm-report:
	@echo "Note: LLM positions are now part of 'make report DOMAIN=X'"
	@echo "Running unified report generation..."
	@make report DOMAIN=$(DOMAIN)

llm-reports-all:
	@echo "Note: LLM positions are now part of 'make reports-all'"
	@echo "Running unified report generation..."
	@make reports-all

# Maintenance
llm-reset:
	@test -n "$(DOMAIN)" || (echo "Usage: make llm-reset DOMAIN=taxation" && exit 1)
	@echo "Resetting LLM extraction for domain: $(DOMAIN)"
	@echo "This will delete all positions and reset processing flags"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker exec $(POSTGRES_CONTAINER) \
			psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
			-c "SELECT * FROM reset_llm_extraction('$(DOMAIN)');"; \
	else \
		echo "Cancelled"; \
	fi

# ============================================================================
# WORKFLOWS
# ============================================================================

overnight: extract index
	@echo "Overnight processing complete"
	@echo "Next steps:"
	@echo "  1. Generate embeddings: make generate-embeddings"
	@echo "  2. Query domains: make query-all-domains"
	@echo "  3. Generate reports: make reports-all"

# ============================================================================
# UTILITIES
# ============================================================================

db-stats:
	@echo "Database Statistics:"
	@docker exec $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c \
	"SELECT 'Responses' as table_name, COUNT(*) as count FROM responses \
	 UNION ALL SELECT 'With attachments', COUNT(*) FROM responses WHERE has_attachment \
	 UNION ALL SELECT 'Attachments extracted', COUNT(*) FROM responses WHERE attachment_extracted \
	 UNION ALL SELECT 'Embeddings', COUNT(*) FROM response_embeddings \
	 UNION ALL SELECT 'Word frequency', COUNT(*) FROM word_frequency \
	 UNION ALL SELECT 'LLM positions', COUNT(*) FROM position_analysis;"

db-shell:
	@echo "Opening PostgreSQL shell..."
	docker exec -it $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

logs:
	@echo "Showing container logs..."
	docker compose logs --tail=50

clean:
	@echo "Cleaning old output files..."
	@find output -name "*.html" -mtime +7 -delete
	@find output/logs -name "*.log" -mtime +7 -delete
	@echo "Cleanup complete"

# ============================================================================
# PHONY TARGETS
# ============================================================================

.PHONY: reset load download-attachments extract retry-extractions redownload-corrupt \
        index word-stats search markdown-report word-html-report \
        generate-embeddings check-embeddings \
        test-domains validate-domains test-query-sql list-domains show-domain \
        query-domain query-all-domains report html-report reports-all \
        llm-schema llm-extract llm-extract-all llm-extract-all-bg \
        llm-retry-failed llm-retry-all-failed \
        llm-status llm-summary llm-progress llm-positions llm-stakeholders llm-proposals llm-evidence \
        llm-report llm-reports-all llm-reset \
        overnight db-stats db-shell logs clean
# Makefile snippet - Add to Reports section
# Supports both: make report-all  AND  make report DOMAIN=all

# List of all domains (update if you add more)
ALL_DOMAINS = taxation procurement sovereignty vendor-lock security

# Generate reports for all domains
.PHONY: report-all
report-all:
	@echo "Generating reports for all domains..."
	@for domain in $(ALL_DOMAINS); do \
		echo ""; \
		echo "============================================================="; \
		echo "Processing: $$domain"; \
		echo "============================================================="; \
		docker exec documented-insights-perl perl /app/scripts/09_generate_domain_report.pl $$domain || echo "⚠ Pattern report failed for $$domain"; \
		docker exec documented-insights-perl perl /app/scripts/10_generate_llm_report.pl $$domain || echo "⚠ LLM report failed for $$domain"; \
	done
	@echo ""
	@echo "============================================================="; 
	@echo "Report generation complete"
	@echo "============================================================="; 
	@ls -lh output/domain_*_analysis_*.md 2>/dev/null || echo "No reports found in output/"

# Update your existing 'report' target to handle DOMAIN=all
# Find the 'report:' target and replace with this:
.PHONY: report
report:
ifeq ($(DOMAIN),all)
	@$(MAKE) report-all
else ifndef DOMAIN
	@echo "Error: DOMAIN not specified"
	@echo ""
	@echo "Usage: make report DOMAIN=<domain-name>"
	@echo "   or: make report DOMAIN=all"
	@echo ""
	@echo "Available domains:"
	@ls domains/*.conf | sed 's/domains\//  - /' | sed 's/\.conf//'
else
	@echo "Generating reports for domain: $(DOMAIN)"
	docker exec documented-insights-perl perl /app/scripts/09_generate_domain_report.pl $(DOMAIN)
	docker exec documented-insights-perl perl /app/scripts/10_generate_llm_report.pl $(DOMAIN)
	@echo "✓ Reports generated for $(DOMAIN)"
	@ls -lh output/domain_$(DOMAIN)_analysis_*.md 2>/dev/null
endif

# Bonus: Pattern reports only (fast - no LLM required)
.PHONY: report-all-pattern
report-all-pattern:
	@echo "Generating pattern reports only (fast)..."
	@for domain in $(ALL_DOMAINS); do \
		echo "Pattern report: $$domain"; \
		docker exec documented-insights-perl perl /app/scripts/09_generate_domain_report.pl $$domain; \
	done
	@ls -lh output/domain_*_analysis_pattern.md

# Bonus: LLM reports only (requires LLM extraction complete)
.PHONY: report-all-llm
report-all-llm:
	@echo "Generating LLM reports only..."
	@for domain in $(ALL_DOMAINS); do \
		echo "LLM report: $$domain"; \
		docker exec documented-insights-perl perl /app/scripts/10_generate_llm_report.pl $$domain; \
	done
	@ls -lh output/domain_*_analysis_llm.md
