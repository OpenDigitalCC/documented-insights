#!/bin/bash
#
# identify_redundant_files.sh
# Identifies files that are likely redundant and safe to remove

echo "Documented Insights - Redundant File Analysis"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}DEVELOPMENT/PLANNING DIRECTORIES (Safe to remove)${NC}"
echo "These were used during development and are now superseded:"
echo ""
echo "  domain-config-system/  - Domain system development (now in domains/ and lib/)"
echo "  phase2-query-builder/  - Query builder development (now in lib/DomainQuery.pm)"
echo "  docs/                  - Empty directory"
echo ""

echo -e "${YELLOW}REDUNDANT SCRIPTS (Safe to remove)${NC}"
echo "These scripts are duplicates or have been replaced:"
echo ""

# Check if old batch script exists
if [ -f "scripts/batch_llm_extract.sh" ]; then
    echo "  scripts/batch_llm_extract.sh"
    echo "    → Replaced by: Makefile llm-extract-all target"
fi

# Check old LLM scripts
if [ -f "scripts/05_llm_batch_analysis.pl" ]; then
    echo "  scripts/05_llm_batch_analysis.pl"
    echo "    → Replaced by: 11_llm_batch_extract.pl"
fi

# Check duplicate example scripts
if [ -f "scripts/example_domain_usage.pl" ]; then
    echo "  scripts/example_domain_usage.pl"
    echo "    → Duplicate of: domain-config-system/scripts/example_domain_usage.pl"
fi

# Check test scripts
if [ -f "scripts/test_llm_positions_section.pl" ]; then
    echo "  scripts/test_llm_positions_section.pl"
    echo "    → Test script, not needed for production"
fi

# Check old CSV loader
if [ -f "scripts/01_load_csv.pl" ]; then
    echo "  scripts/01_load_csv.pl"
    echo "    → Check if replaced by 01_load_json.pl"
    echo "    → Validate: Does 01_load_json.pl load your data correctly? (Y/N)"
fi

# Check consultation question scripts
if [ -f "scripts/07_analyze_consultation_questions.pl" ]; then
    echo "  scripts/07_analyze_consultation_questions.pl"
    echo "  scripts/07_answer_consultation_questions.pl"
    echo "    → Are these still needed? (Check output/consultation_questions_analysis.md)"
fi

echo ""
echo -e "${YELLOW}OLD SQL FILES (Check before removing)${NC}"
echo ""

if [ -f "sql/01_create_database.sql" ] && [ -f "sql/02_create_schema.sql" ]; then
    echo "  sql/01_create_database.sql"
    echo "  sql/02_create_schema.sql"
    echo "    → Likely superseded by sql/00_reset_database.sql"
    echo "    → Validate: Does 00_reset_database.sql contain all needed schema?"
fi

echo ""
echo -e "${YELLOW}OUTPUT FILES (Can be regenerated)${NC}"
echo "These are generated files and can be deleted (will be recreated):"
echo ""

if [ -f "output/test_llm_positions_taxation.md" ]; then
    echo "  output/test_llm_positions_taxation.md  - Test output"
fi

if [ -f "output/domain_taxation_analysis.md" ]; then
    echo "  output/domain_taxation_analysis.md     - Old combined file (now use _pattern and _llm)"
fi

ls output/*.yaml 2>/dev/null | while read f; do
    echo "  $f  - Pandoc header files (regenerate if needed)"
done

echo ""
echo -e "${YELLOW}VALIDATION COMMANDS${NC}"
echo "Run these to validate before deletion:"
echo ""

echo "# Test current data loading works:"
echo "docker exec documented-insights-perl perl /app/scripts/01_load_json.pl"
echo ""

echo "# Test domain system works:"
echo "make test-domains"
echo ""

echo "# Test domain query works:"
echo "make query-domain DOMAIN=taxation"
echo ""

echo "# Test report generation works:"
echo "make report DOMAIN=taxation"
echo ""

echo "# Test LLM extraction works:"
echo "make llm-summary"
echo ""

echo -e "${GREEN}SAFE TO DELETE (After validation)${NC}"
cat > /tmp/files_to_delete.txt << 'EOF'
# Development directories (safe to delete after confirming production works)
domain-config-system/
phase2-query-builder/
docs/

# Redundant scripts (safe to delete)
scripts/batch_llm_extract.sh
scripts/05_llm_batch_analysis.pl
scripts/example_domain_usage.pl
scripts/test_llm_positions_section.pl

# Test output (can regenerate)
output/test_llm_positions_taxation.md

# Old combined report (use _pattern and _llm instead)
output/domain_taxation_analysis.md

# Optional: Old SQL (if 00_reset_database.sql is complete)
# sql/01_create_database.sql
# sql/02_create_schema.sql

# Optional: Consultation analysis (if no longer needed)
# scripts/07_analyze_consultation_questions.pl
# scripts/07_answer_consultation_questions.pl
# output/consultation_questions_analysis.md

# Optional: Old CSV loader (if JSON loader works)
# scripts/01_load_csv.pl
EOF

echo ""
echo "List saved to: /tmp/files_to_delete.txt"
echo ""

echo -e "${YELLOW}RECOMMENDED DELETION SCRIPT${NC}"
echo "After running validation commands above, execute:"
echo ""
echo "  bash scripts/clean_redundant_files.sh"
echo ""
