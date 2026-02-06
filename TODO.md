# TODO - Planned Improvements

## High Priority

### Input Data Encoding Normalization

**Issue**
: Source consultation responses have mixed character encodings (UTF-8, Latin-1, Windows-1252) from multiple submission sources.

**Current workaround**
: PDF generation script (`combine_reports_for_pdf.pl`) auto-detects and converts to UTF-8 at output stage.

**Proposed fix**
: Normalize all text to UTF-8 at first contact point - during JSON loading (`scripts/02_load_json.pl`).

**Implementation**:

```perl
# In scripts/02_load_json.pl
use Encode qw(decode encode);

# When loading response text
my $text = $response->{response_text};

# Detect and normalize encoding
eval {
    $text = decode('UTF-8', $text, Encode::FB_CROAK);
};
if ($@) {
    # Not UTF-8, try Latin-1
    $text = decode('ISO-8859-1', $text);
}

# Clean control characters
$text =~ s/[\x{0080}-\x{009F}]//g;

# Store as clean UTF-8
$insert_sth->execute(encode('UTF-8', $text));
```

**Benefits**:
- Database contains clean UTF-8 only
- Eliminates encoding issues in reports, PDFs, and search
- Simpler downstream processing
- Better full-text search accuracy

**Effort**: ~1 hour implementation + testing

**Priority**: High - Technical debt from initial rapid development

---

## Medium Priority

### Incremental LLM Position Updates

**Issue**
: Changing LLM prompts requires re-extraction of all responses for affected domains.

**Proposed fix**:
- Add `extraction_timestamp` and `prompt_version` columns to `position_analysis`  table
- Track which responses need re-extraction
- Only process responses with outdated or missing positions

**Benefits**:
- Faster iteration on prompt engineering
- Ability to update positions without full re-extraction
- Historical comparison of different prompt versions

**Effort**: ~4 hours

---

### Performance Optimization for CPU-based LLM

**Issue**
: CPU-based extraction takes 3–5 days for full dataset.

**Options**:
- Batch processing with parallel workers (4–6x speedup)
- Caching of common response patterns
- Progressive summarization for long responses

**Benefits**:
- Usable on CPU-only systems
- Reduced dependency on GPU infrastructure

**Effort**: ~8–12 hours

---

## Low Priority

### Multi-language Support

**Issue**
: Responses include German, French, and other EU languages. Currently optimized for English.

**Proposed approach**:
- Language detection at load time
- Separate domain configurations per language
- Language-aware LLM prompts

**Benefits**:
- Better coverage of non-English responses
- More accurate sentiment analysis
- Proper handling of language-specific terms

**Effort**: ~16 hours

---

### Enhanced Stakeholder Classification

**Issue**
: Current classification is basic (citizen, organization, public authority).

**Proposed enhancements**:
- Industry sector classification (tech, finance, healthcare, etc.)
- Organization size (SME, large enterprise, multinational)
- Geographic region (not just country)
- Interest group categorization

**Benefits**:
- More granular stakeholder analysis
- Better understanding of position patterns
- Enhanced report insights

**Effort**: ~6 hours

---

### Web Interface for Reports

**Issue**
: Reports currently only available as markdown/PDF files.

**Proposed solution**:
- Simple web UI for browsing domains
- Interactive filtering and search
- Visualization of word frequency and co-occurrence
- Export to multiple formats

**Benefits**:
- Non-technical users can access insights
- Interactive exploration of data
- Better presentation for stakeholders

**Effort**: ~20–30 hours

---

## Documentation Improvements

### User Guide

- Step-by-step tutorial with screenshots
- Common workflows documented
- Troubleshooting guide
- Video walkthrough

**Effort**: ~8 hours

### Developer Documentation

- Architecture diagrams
- Database schema visualization
- API documentation for Perl modules
- Code walkthrough for new contributors

**Effort**: ~12 hours

---

## Technical Debt

### Test Coverage

**Current**:
- Validation tests for infrastructure and data loading
- No unit tests for individual modules
- No integration tests for LLM extraction

**Needed**:
- Unit tests for DomainConfig, DomainQuery, LLMPositionReport modules
- Integration tests for complete report generation pipeline
- Mock LLM responses for deterministic testing

**Effort**: ~16 hours

### Error Handling

**Current**:
- Basic error handling in scripts
- Some retry logic for LLM calls
- Limited logging

**Needed**:
- Comprehensive error classification
- Structured logging with log levels
- Better user-facing error messages
- Automatic error reporting/aggregation

**Effort**: ~10 hours

---

## Security Hardening (Future Production Use)

**Required for production deployment**:
- Security audit of all scripts
- Input validation and sanitization
- SQL injection prevention review
- Access control implementation
- Secrets management (not .env files)
- Network security configuration
- Container hardening
- Dependency vulnerability scanning

**Effort**: ~40–60 hours + professional security review

**Note**: Current system is R&D/laboratory use only. Production deployment requires comprehensive security evaluation.

---

## Monitoring and Observability

### Metrics Collection

- LLM extraction performance (responses/hour, errors)
- Database query performance
- Disk space usage
- Memory consumption
- PDF generation success rate

### Alerting

- Failed LLM extractions
- Database connection issues
- Disk space warnings
- Long-running processes

**Effort**: ~10 hours

---

## Completed Items

✓ PDF generation with combined pattern + LLM reports  
✓ Encoding cleanup for mixed UTF-8/Latin-1 sources (workaround)  
✓ System validation test suite  
✓ Remote GPU support documentation  
✓ Domain configuration system  
✓ LLM position extraction pipeline  
✓ Makefile task orchestration  
✓ Docker containerization

---

## Priority for Next Development Cycle

1. **Input encoding normalization** (fixes technical debt)
2. **Incremental LLM updates** (improves development workflow)
3. **Enhanced test coverage** (improves reliability)
4. **User documentation** (improves accessibility)

---

Last updated: 2026-02-06
