#!/bin/bash
#
# cleanup_redundant_files.sh
# Remove redundant/superseded files from the project
#
# ALWAYS creates backups before deletion

set -e

BACKUP_DIR="backup_redundant_$(date +%Y%m%d_%H%M%S)"

echo "Cleanup Redundant Files"
echo "======================="
echo ""
echo "This will remove:"
echo "  - Development directories: domain-config-system/, phase2-query-builder/"
echo "  - Redundant scripts: batch_llm_extract.sh, 05_llm_batch_analysis.pl, etc."
echo "  - Test outputs and old combined reports"
echo ""
echo "Backups will be created in: $BACKUP_DIR/"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo ""
echo "Creating backups..."

# ============================================================================
# BACKUP BEFORE DELETION
# ============================================================================

# Backup directories
for dir in domain-config-system phase2-query-builder docs; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$BACKUP_DIR/" 2>/dev/null || true
        echo "  ✓ Backed up $dir/"
    fi
done

# Backup redundant scripts
for script in \
    scripts/batch_llm_extract.sh \
    scripts/test_llm_positions_section.pl \
    scripts/05_llm_batch_analysis.pl \
    scripts/example_domain_usage.pl \
    scripts/test_domain_config.pl \
    scripts/test_domain_query.pl; do
    
    if [ -f "$script" ]; then
        cp "$script" "$BACKUP_DIR/" 2>/dev/null || true
        echo "  ✓ Backed up $script"
    fi
done

# Backup old output files
for file in \
    output/test_llm_positions_taxation.md \
    output/domain_taxation_analysis.md \
    output/consultation-questions-header.yaml \
    output/generic-header.yaml \
    output/word-frequency-header.yaml; do
    
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        echo "  ✓ Backed up $file"
    fi
done

echo ""
echo "Backups complete."
echo ""

# ============================================================================
# DELETION
# ============================================================================

echo "Removing redundant files..."
echo ""

DELETED_COUNT=0

# Remove development directories
for dir in domain-config-system phase2-query-builder; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "  ✓ Removed $dir/"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

# Remove empty docs directory
if [ -d "docs" ] && [ -z "$(ls -A docs)" ]; then
    rmdir docs
    echo "  ✓ Removed docs/ (empty)"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

# Remove superseded scripts
for script in \
    scripts/batch_llm_extract.sh \
    scripts/test_llm_positions_section.pl \
    scripts/05_llm_batch_analysis.pl \
    scripts/example_domain_usage.pl \
    scripts/test_domain_config.pl \
    scripts/test_domain_query.pl; do
    
    if [ -f "$script" ]; then
        rm "$script"
        echo "  ✓ Removed $script"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

# Remove old output files
for file in \
    output/test_llm_positions_taxation.md \
    output/domain_taxation_analysis.md \
    output/consultation-questions-header.yaml \
    output/generic-header.yaml \
    output/word-frequency-header.yaml; do
    
    if [ -f "$file" ]; then
        rm "$file"
        echo "  ✓ Removed $file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

echo ""
echo "Cleanup complete!"
echo ""
echo "Summary:"
echo "  - Removed: $DELETED_COUNT items"
echo "  - Backups saved to: $BACKUP_DIR/"
echo ""
echo "Verify everything works:"
echo "  make test-domains"
echo "  make report DOMAIN=taxation"
echo "  make llm-summary"
echo ""
echo "If everything works fine, you can delete the backup:"
echo "  rm -rf $BACKUP_DIR/"
echo ""
echo "To restore if needed:"
echo "  cp -r $BACKUP_DIR/* ."
echo ""
