# Domain Configuration Files

## Overview

Domain configuration files define keyword sets for focused analysis of EU consultation responses. Each file represents a policy area that the European Commission wants to understand through structured queries.

## Available Domains

- **taxation.conf** - Tax policy, levies, fiscal incentives
- **procurement.conf** - Public procurement practices and barriers
- **sovereignty.conf** - Digital sovereignty and strategic autonomy
- **vendor-lock.conf** - Vendor lock-in and switching costs
- **security.conf** - Cybersecurity, privacy, vulnerability management

## Usage

### Test All Configurations

```bash
perl scripts/test_domain_config.pl
```

### Test with Verbose Output

```bash
VERBOSE=1 perl scripts/test_domain_config.pl
```

### Generate Analysis Report

```bash
# Single domain
make report DOMAIN=taxation

# All domains
make reports-all
```

## Creating New Domains

1. Copy an existing `.conf` file as template
2. Follow the format specified in `DOMAIN_CONFIG_SPEC.md`
3. Test with `test_domain_config.pl`
4. Run analysis with `make report DOMAIN=yourname`

## File Format

See `DOMAIN_CONFIG_SPEC.md` for complete specification.

### Quick Example

```
[domain]
name = Your Domain Name
description = Brief description of policy area

[keywords]
word1
word2

[keyphrases]
multi word phrase
another phrase

[sub-themes]
theme1 = term1, term2, term3
theme2 = term4, term5
```

## Validation

The parser checks for:

- Required fields: domain name, description
- At least one keyword or keyphrase
- Valid section names
- Proper field formatting

Warnings (non-fatal):
- Duplicate terms
- Very short keywords (< 3 characters)
- Empty sub-themes

## Query Behaviour

**Keywords**: Single words matched with word boundaries
- Case-insensitive
- Stemming applied (tax → taxes, taxation)

**Keyphrases**: Multi-word phrases with flexible matching
- Case-insensitive
- Handles variations in punctuation/whitespace
- "vendor lock-in" matches "vendor lock in", "vendor-lock-in", etc.

**Sub-themes**: Optional groupings for deeper analysis
- Each creates a separate section in reports
- Responses can appear in multiple sub-themes

## Integration with Analysis Pipeline

Domain configurations feed into:

1. **Query builder** - Generates PostgreSQL queries
2. **Analysis functions** - Frequency, co-occurrence, stakeholder breakdown
3. **Report generator** - Commission-perspective insights
4. **Semantic search** - Embedding-based similarity queries

## Maintenance

When updating configurations:

1. Test parsing with `test_domain_config.pl`
2. Review query results on small dataset
3. Regenerate reports for affected domains
4. Update this README if adding new domains
