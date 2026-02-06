#!/bin/bash
#
# test_system_end_to_end.sh
# Comprehensive system validation
#
# Tests all major components of the documented-insights system

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Function to run test
run_test() {
    local test_name=$1
    local command=$2
    
    echo -e "${BLUE}Testing: $test_name${NC}"
    echo "Command: $command"
    
    if eval "$command" > /tmp/test_output.txt 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
        echo ""
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "Output:"
        cat /tmp/test_output.txt
        FAILED=$((FAILED + 1))
        echo ""
        return 1
    fi
}

echo "=========================================="
echo "Documented Insights - End-to-End Testing"
echo "=========================================="
echo ""

# ============================================================================
# INFRASTRUCTURE
# ============================================================================

echo -e "${YELLOW}=== Infrastructure Tests ===${NC}"
echo ""

run_test "Docker containers running" \
    "docker ps | grep -E 'documented-insights-(postgres|perl|embeddings|ollama)'"

run_test "Database accessible" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -c 'SELECT 1' | grep -q '1 row'"

run_test "Perl container has DBI" \
    "docker exec documented-insights-perl perl -MDBI -e 'print \"OK\n\"' | grep -q OK"

run_test "Python has LLM extraction dependencies" \
    "docker exec documented-insights-embeddings python -c 'import psycopg2, requests; print(\"OK\")' | grep -q OK"

# ============================================================================
# DATABASE SCHEMA
# ============================================================================

echo -e "${YELLOW}=== Database Schema Tests ===${NC}"
echo ""

run_test "Responses table exists" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -c '\dt responses' | grep -q responses"

run_test "Embeddings table exists" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -c '\dt response_embeddings' | grep -q response_embeddings"

run_test "Position analysis table exists" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -c '\dt position_analysis' | grep -q position_analysis"

run_test "Domain stats view exists" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -c '\dv position_extraction_progress' | grep -q position_extraction_progress"

# ============================================================================
# DATA LOADING
# ============================================================================

echo -e "${YELLOW}=== Data Loading Tests ===${NC}"
echo ""

run_test "Responses loaded" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -t -c 'SELECT COUNT(*) FROM responses' | grep -E '[0-9]+' | grep -v '^0$'"

run_test "Source CSV file exists" \
    "test -f data/european-open-digital-ecosystems-all-responses.csv"

# ============================================================================
# DOMAIN CONFIGURATION
# ============================================================================

echo -e "${YELLOW}=== Domain Configuration Tests ===${NC}"
echo ""

run_test "Domain configurations valid" \
    "make test-domains 2>&1 | grep -q 'passed'"

run_test "Domain config files exist" \
    "ls domains/*.conf | wc -l | grep -q '[1-9]'"

run_test "DomainConfig module loads" \
    "docker exec documented-insights-perl perl -I/app/lib -MDomainConfig -e 'print \"OK\n\"' | grep -q OK"

run_test "DomainQuery module loads" \
    "docker exec documented-insights-perl perl -I/app/lib -MDomainQuery -e 'print \"OK\n\"' | grep -q OK"

# ============================================================================
# DOMAIN QUERIES
# ============================================================================

echo -e "${YELLOW}=== Domain Query Tests ===${NC}"
echo ""

run_test "Domain query - taxation" \
    "make query-domain DOMAIN=taxation 2>&1 | grep -q 'Matching responses'"

# Skip database query test - domain_config is file-based, not in database

# ============================================================================
# WORD ANALYSIS
# ============================================================================

echo -e "${YELLOW}=== Word Analysis Tests ===${NC}"
echo ""

run_test "Word frequency table exists" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -c '\dt word_frequency' | grep -q word_frequency"

run_test "Word frequency populated" \
    "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -t -c 'SELECT COUNT(*) FROM word_frequency' | grep -E '[0-9]+' | grep -v '^0$'"

# ============================================================================
# EMBEDDINGS
# ============================================================================

echo -e "${YELLOW}=== Embeddings Tests ===${NC}"
echo ""

echo -e "${YELLOW}=== Embeddings Tests (Optional) ===${NC}"
echo ""

# Check if embeddings exist (optional - not required for LLM extraction)
EMBEDDING_COUNT=$(docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -t -A -c 'SELECT COUNT(*) FROM response_embeddings' 2>/dev/null | tr -d ' ')

if [ "$EMBEDDING_COUNT" -gt 0 ]; then
    run_test "Embeddings generated" \
        "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -t -A -c 'SELECT COUNT(*) FROM response_embeddings' | grep -E '^[0-9]+$' | grep -v '^0$'"
else
    echo -e "${BLUE}Testing: Embeddings generated${NC}"
    echo "Command: [skipped]"
    echo -e "${YELLOW}SKIPPED: No embeddings found (optional for LLM extraction)${NC}"
    echo ""
fi

# ============================================================================
# LLM POSITION EXTRACTION
# ============================================================================

echo -e "${YELLOW}=== LLM Position Extraction Tests ===${NC}"
echo ""

echo -e "${YELLOW}=== LLM Position Extraction Tests ===${NC}"
echo ""

# Check if LLM positions exist (may be in progress)
POSITION_COUNT=$(docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -t -A -c 'SELECT COUNT(*) FROM position_analysis' 2>/dev/null | tr -d ' ')

if [ "$POSITION_COUNT" -gt 0 ]; then
    run_test "LLM positions extracted" \
        "docker exec documented-insights-postgres psql -U sysadmin -d documented_insights -t -A -c 'SELECT COUNT(*) FROM position_analysis' | grep -E '^[1-9][0-9]*$'"
else
    echo -e "${BLUE}Testing: LLM positions extracted${NC}"
    echo "Command: [skipped]"
    echo -e "${YELLOW}SKIPPED: No positions yet (extraction may be in progress)${NC}"
    echo ""
    # Check if extraction is running
    if ps aux | grep -q "[1]0_llm_extract_positions.py"; then
        echo -e "${YELLOW}Note: LLM extraction is currently running${NC}"
        echo ""
    fi
fi

if [ "$POSITION_COUNT" -gt 0 ]; then
    run_test "LLM processing summary works" \
        "make llm-summary 2>&1 | grep -q 'responses processed'"
    
    run_test "LLM status query works" \
        "make llm-status 2>&1 | grep -q 'total_responses'"
    
    run_test "LLM progress query works" \
        "make llm-progress 2>&1 | grep -q 'domain'"
else
    echo -e "${YELLOW}Skipping LLM summary/status tests (no data yet)${NC}"
    echo ""
fi

run_test "LLMPositionReport module loads" \
    "docker exec documented-insights-perl perl -I/app/lib -MLLMPositionReport -e 'print \"OK\n\"' | grep -q OK"

# ============================================================================
# REPORT GENERATION
# ============================================================================

echo -e "${YELLOW}=== Report Generation Tests ===${NC}"
echo ""

run_test "Pattern report generation" \
    "make report DOMAIN=taxation 2>&1 | grep -q 'domain_taxation_analysis_pattern.md'"

run_test "Pattern report file created" \
    "test -f output/domain_taxation_analysis_pattern.md"

run_test "LLM report generation" \
    "test -f output/domain_taxation_analysis_llm.md"

run_test "Pattern report has content" \
    "test $(wc -l < output/domain_taxation_analysis_pattern.md) -gt 100"

run_test "LLM report has content" \
    "test $(wc -l < output/domain_taxation_analysis_llm.md) -gt 10"

# ============================================================================
# MAKEFILE TARGETS
# ============================================================================

echo -e "${YELLOW}=== Makefile Targets Tests ===${NC}"
echo ""

run_test "Makefile exists and is valid" \
    "make -n help > /dev/null 2>&1"

run_test "db-stats target works" \
    "make db-stats 2>&1 | grep -q 'Database Statistics'"

run_test "list-domains target works" \
    "make list-domains 2>&1 | grep -q 'taxation'"

# ============================================================================
# SCRIPTS EXECUTABLE
# ============================================================================

echo -e "${YELLOW}=== Scripts Accessibility Tests ===${NC}"
echo ""

CRITICAL_SCRIPTS=(
    "scripts/01_load_json.pl"
    "scripts/02_extract_attachments.pl"
    "scripts/03_build_word_index.pl"
    "scripts/04_generate_embeddings.py"
    "scripts/08_domain_query.pl"
    "scripts/09_generate_domain_report.pl"
    "scripts/10_generate_llm_report.pl"
    "scripts/10_llm_extract_positions.py"
    "scripts/11_llm_batch_extract.pl"
    "scripts/12_llm_processing_summary.pl"
)

for script in "${CRITICAL_SCRIPTS[@]}"; do
    run_test "Script exists: $script" \
        "test -f $script"
done

# ============================================================================
# SUMMARY
# ============================================================================

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! System is operational.${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Review output above.${NC}"
    exit 1
fi
