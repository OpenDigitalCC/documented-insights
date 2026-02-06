#!/bin/bash
#
# Batch LLM Position Extraction - All Domains
# Processes all consultation responses across all policy domains
# with automatic retry of failed extractions
#
# Usage:
#   ./scripts/batch_llm_extract.sh [--retry-failed]
#
# Features:
# - Processes all 5 domains sequentially
# - Logs progress to file
# - Automatic retry pass for failures
# - Resume capability (safe to interrupt and restart)
# - Email notification on completion (optional)

set -e  # Exit on error (but we'll handle errors ourselves)

# Configuration
DOMAINS=("taxation" "procurement" "sovereignty" "vendor-lock" "security")
LOG_DIR="/app/output/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/llm_extraction_${TIMESTAMP}.log"
SUMMARY_FILE="$LOG_DIR/llm_extraction_${TIMESTAMP}_summary.txt"

# Create log directory
mkdir -p "$LOG_DIR"

# Parse arguments
RETRY_FLAG=""
if [[ "$1" == "--retry-failed" ]]; then
    RETRY_FLAG="--retry-failed"
    echo "Retry mode: Will include previously failed extractions" | tee -a "$LOG_FILE"
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to extract statistics
get_stats() {
    local domain=$1
    python3 <<EOF
import psycopg2
import os

conn = psycopg2.connect(
    host=os.getenv('POSTGRES_HOST', 'postgres'),
    database=os.getenv('POSTGRES_DB', 'documented_insights'),
    user=os.getenv('POSTGRES_USER', 'sysadmin'),
    password=os.getenv('POSTGRES_PASSWORD', 'changeme')
)

cur = conn.cursor()

# Get processing stats for domain
cur.execute("""
    SELECT 
        COUNT(DISTINCT CASE WHEN p.domain = %s THEN r.id END) as processed,
        COUNT(DISTINCT CASE WHEN r.llm_extraction_failed = TRUE THEN r.id END) as failed,
        COUNT(DISTINCT p.id) as positions_extracted
    FROM responses r
    LEFT JOIN position_analysis p ON r.id = p.response_id
""", (domain,))

processed, failed, positions = cur.fetchone()
print(f"{processed},{failed},{positions}")

conn.close()
EOF
}

# Start banner
log "=========================================="
log "Batch LLM Position Extraction"
log "Started: $(date)"
log "Domains: ${DOMAINS[*]}"
log "Log file: $LOG_FILE"
log "=========================================="
log ""

# Track totals
TOTAL_PROCESSED=0
TOTAL_FAILED=0
TOTAL_POSITIONS=0

# Process each domain
for domain in "${DOMAINS[@]}"; do
    log "=========================================="
    log "Processing domain: $domain"
    log "=========================================="
    
    # Get initial stats
    STATS_BEFORE=$(get_stats "$domain")
    IFS=',' read -r PROC_BEFORE FAIL_BEFORE POS_BEFORE <<< "$STATS_BEFORE"
    log "Before: $PROC_BEFORE responses processed, $FAIL_BEFORE failed, $POS_BEFORE positions"
    
    # Run extraction
    log "Starting extraction..."
    
    if python3 /app/scripts/10_llm_extract_positions.py \
        --domain "$domain" \
        $RETRY_FLAG \
        2>&1 | tee -a "$LOG_FILE"; then
        log "✓ Domain $domain completed successfully"
    else
        log "⚠ Domain $domain completed with errors (see log)"
    fi
    
    # Get final stats
    STATS_AFTER=$(get_stats "$domain")
    IFS=',' read -r PROC_AFTER FAIL_AFTER POS_AFTER <<< "$STATS_AFTER"
    
    # Calculate changes
    PROC_CHANGE=$((PROC_AFTER - PROC_BEFORE))
    FAIL_CHANGE=$((FAIL_AFTER - FAIL_BEFORE))
    POS_CHANGE=$((POS_AFTER - POS_BEFORE))
    
    log "After:  $PROC_AFTER responses processed, $FAIL_AFTER failed, $POS_AFTER positions"
    log "Change: +$PROC_CHANGE processed, +$FAIL_CHANGE failed, +$POS_CHANGE positions"
    
    # Update totals
    TOTAL_PROCESSED=$((TOTAL_PROCESSED + PROC_CHANGE))
    TOTAL_FAILED=$((TOTAL_FAILED + FAIL_CHANGE))
    TOTAL_POSITIONS=$((TOTAL_POSITIONS + POS_CHANGE))
    
    log ""
done

# Retry pass if failures occurred and not already in retry mode
if [[ -z "$RETRY_FLAG" && $TOTAL_FAILED -gt 0 ]]; then
    log "=========================================="
    log "Retry Pass - Processing Failed Extractions"
    log "=========================================="
    log "Total failures to retry: $TOTAL_FAILED"
    log ""
    
    # Run retry pass
    for domain in "${DOMAINS[@]}"; do
        log "Retrying failed extractions for: $domain"
        
        if python3 /app/scripts/10_llm_extract_positions.py \
            --domain "$domain" \
            --retry-failed \
            2>&1 | tee -a "$LOG_FILE"; then
            log "✓ Retry for $domain completed"
        else
            log "⚠ Retry for $domain completed with errors"
        fi
        
        log ""
    done
fi

# Final summary
log "=========================================="
log "Batch Extraction Complete"
log "Finished: $(date)"
log "=========================================="
log ""
log "Summary:"
log "  Responses processed: $TOTAL_PROCESSED"
log "  New failures: $TOTAL_FAILED"
log "  Positions extracted: $TOTAL_POSITIONS"
log ""
log "View full log: $LOG_FILE"

# Generate summary file
cat > "$SUMMARY_FILE" <<EOF
LLM Position Extraction - Batch Summary
Generated: $(date)

Overall Statistics
==================
Responses processed: $TOTAL_PROCESSED
New failures: $TOTAL_FAILED
Positions extracted: $TOTAL_POSITIONS

Per-Domain Breakdown
====================
EOF

for domain in "${DOMAINS[@]}"; do
    STATS=$(get_stats "$domain")
    IFS=',' read -r PROC FAIL POS <<< "$STATS"
    echo "" >> "$SUMMARY_FILE"
    echo "$domain:" >> "$SUMMARY_FILE"
    echo "  Processed: $PROC" >> "$SUMMARY_FILE"
    echo "  Failed: $FAIL" >> "$SUMMARY_FILE"
    echo "  Positions: $POS" >> "$SUMMARY_FILE"
done

cat >> "$SUMMARY_FILE" <<EOF

Log Files
=========
Full log: $LOG_FILE
Summary: $SUMMARY_FILE

Next Steps
==========
1. Review failed extractions:
   make llm-status

2. Generate enhanced reports:
   make llm-report DOMAIN=taxation
   make llm-reports-all

3. Check position quality:
   make llm-positions DOMAIN=taxation
   make llm-stakeholders DOMAIN=taxation
EOF

log ""
log "Summary written to: $SUMMARY_FILE"
log ""

# Display summary
cat "$SUMMARY_FILE"

# Optional: Send email notification
# Uncomment and configure if desired
# echo "Batch extraction complete. See attached summary." | \
#     mail -s "LLM Extraction Complete" -a "$SUMMARY_FILE" admin@example.com

log "Done!"
