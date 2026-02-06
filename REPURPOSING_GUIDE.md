# Repurposing Guide - Adapting for Other Data Analysis

## Overview

This consultation analysis system is built on generic components that can be repurposed for analysing any text-based dataset. The core pipeline (word analysis, domain classification, LLM position extraction, report generation) is data-source agnostic.

Purpose
: This guide explains how to adapt the system for different data sources whilst reusing 80–90% of existing code

Approach
: Create new "profiles" (loader + domain configs) for each data source, reuse everything else

Target audience
: Developers adapting this system for new datasets, AI assistants helping with adaptation

## System Architecture

### Generic Components (Reusable)

Core pipeline:

1. Data ingestion → PostgreSQL responses table
2. Full-text indexing → domain matching
3. Word frequency analysis → patterns
4. LLM position extraction → stakeholder insights
5. Report generation → markdown output

These components are **completely reusable** regardless of data source.

### Source-Specific Components (Adaptable)

Data loader
: Script that reads source data and populates responses table

Domain configurations
: Keyword/keyphrase definitions for topics of interest

LLM context
: Prompt text describing what the data represents

These components are **created new** for each data source.

## Reusability Breakdown

### Highly Reusable (No Changes Required)

Infrastructure
: Docker containers, PostgreSQL database, Ollama integration

Database schema
: `responses` table with full-text search, `position_analysis` table for LLM extractions, word frequency tables, domain matching views

Perl modules
: DomainConfig.pm (config parser), DomainQuery.pm (SQL generation), LLMPositionReport.pm (report formatting)

Python LLM integration
: API calls to Ollama, position extraction logic, JSON parsing

Report generation
: Markdown templates, stakeholder breakdowns, position summaries

Makefile orchestration
: Command patterns, pipeline coordination

Validation testing
: Test framework structure (specific tests adapt to new data)

### Requires Adaptation (Minor Changes)

Domain configurations
: New `.conf` files with relevant keywords/keyphrases for new subject matter

LLM prompts
: Context description in Python script (what the data represents)

Report headers
: Titles and descriptions in report templates

Validation tests
: Expected counts and data characteristics

### Requires Replacement (New Implementation)

Data loader
: Script to parse source format and populate responses table

Attachment handling
: If source has attachments (optional)

Source-specific processing
: Any unique data transformations needed

## Profile-Based Architecture

### Concept

A "profile" is a complete configuration for analysing a specific data source.

Profile components:

- Data loader script
- Domain configuration files
- LLM context description
- Profile metadata (name, description, expected fields)

### Profile Structure

```
profiles/
├── consultation/          # Current implementation
│   ├── loader.pl         # 01_load_json.pl
│   ├── domains/          # Domain .conf files
│   ├── llm_context.txt   # LLM prompt context
│   └── profile.yml       # Metadata
│
├── your-profile/         # New profile
│   ├── loader.pl         # Your data parser
│   ├── domains/          # Your topic keywords
│   ├── llm_context.txt   # What your data represents
│   └── profile.yml       # Profile configuration
```

### Profile Metadata Format

```yaml
# profile.yml
name: your-profile
description: Brief description of data source
version: 1.0

data_source:
  type: text_documents  # or: emails, modules, posts, etc.
  expected_fields:
    - title
    - content
    - author
    - date
  
loader:
  script: loader.pl
  format: csv  # or: json, xml, directory, api, etc.
  
domains:
  directory: domains/
  count: 5
  
llm:
  context_file: llm_context.txt
  model: llama3.1:8b
```

## Adapting the System

### Step 1: Understand Your Data

Questions to answer:

What format is your data?
: CSV, JSON, XML, directory of files, API, database, email archive

What are the text fields?
: Title, body, description, content, comments

What metadata exists?
: Author, date, category, tags, location

What topics interest you?
: What domains/themes to analyse

What questions do you want answered?
: What insights are you seeking

### Step 2: Create Data Loader

The loader must populate the `responses` table:

Required fields:

- `id` - Unique identifier (auto-generated)
- `full_text` - All searchable text concatenated
- `response_text` - Main content
- `fts_vector` - Full-text search vector (auto-generated)

Optional fields (adapt as needed):

- `organisation_name` - Author, source, category
- `user_type` - Document type, category, classification
- `country` - Geographic location, version, grouping
- `first_name`, `surname` - Individual attribution
- `publication_url` - Source reference, URL, identifier

Example loader structure:

```perl
#!/usr/bin/env perl
# profiles/your-profile/loader.pl

use strict;
use warnings;
use DBI;

# Database connection
my $dbh = DBI->connect(...);

# Parse your data source
foreach my $item (parse_your_data()) {
    
    # Map to responses table
    my $full_text = join(" ", 
        $item->{title},
        $item->{content},
        # ... other text fields
    );
    
    # Insert into database
    my $sql = "INSERT INTO responses 
        (response_text, full_text, organisation_name, user_type) 
        VALUES (?, ?, ?, ?)";
    
    $dbh->do($sql, undef,
        $item->{content},
        $full_text,
        $item->{author},
        $item->{type}
    );
}
```

### Step 3: Define Domains

Create `.conf` files for topics you want to analyse.

Domain configuration format:

```ini
[domain]
name = Your Topic Name
description = What this topic covers

[keywords]
word1
word2
word3

[keyphrases]
multi word phrase
another phrase

[sub_themes]
subtopic1 = keyword1, keyword2
subtopic2 = phrase1, phrase2
```

Example domains:

- Technical topics (security, performance, integration)
- Organisational themes (governance, training, adoption)
- Functional areas (data management, workflows, reporting)
- Concern types (privacy, cost, complexity)

### Step 4: Adapt LLM Context

Update the LLM prompt context in `10_llm_extract_positions.py`:

Current context:
```python
"""
This is a response to an EU consultation about digital policy.
Analyse the stakeholder's position...
"""
```

Your context:
```python
"""
This is a [description of your data].
Analyse the [author/contributor]'s position...
"""
```

Keep the extraction structure (positions, arguments, evidence, proposals) - this is generic.

### Step 5: Test and Validate

Run validation suite:

```bash
# Load your data
make reset
./profiles/your-profile/loader.pl

# Check data loaded
make db-stats

# Test domain matching
make query-domain DOMAIN=your-domain

# Generate reports
make report DOMAIN=your-domain
```

Update test expectations in `test_system_end_to_end.sh` for your data characteristics.

## Information to Provide for Adaptation

When requesting AI assistance to adapt this system, provide:

### About Your Data

Data format
: CSV, JSON, directory of files, etc.

Sample records
: 3–5 examples showing structure

Field descriptions
: What each field contains

Volume
: Approximate number of records

Text location
: Which fields contain analysable text

Metadata available
: Author, date, category, tags, etc.

### About Your Analysis Goals

Topics of interest
: What domains/themes to analyse (3–10 suggested)

Questions to answer
: What insights you're seeking

Stakeholder types
: How to categorise authors/sources (if applicable)

Position types
: What kinds of positions/stances to extract

Output requirements
: Report format, key metrics needed

### Technical Context

Environment
: Existing infrastructure, constraints

Access method
: How to access the data (files, API, database)

Processing frequency
: One-time analysis or ongoing

Performance needs
: Dataset size, processing time constraints

## Components That May Need Updates

### Fast-Moving (May Require Updates)

LLM integration
: Ollama API may change, new models may emerge

Python dependencies
: psycopg2, requests versions

LLM prompt engineering
: Better prompts may be developed

Model selection
: Currently hardcoded to llama3.1:8b

### Stable (Unlikely to Change)

PostgreSQL schema
: Core table structure is stable

Perl modules
: DomainConfig, DomainQuery logic is generic

Full-text search
: PostgreSQL tsvector approach is standard

Report generation
: Markdown output format is stable

Docker infrastructure
: Container architecture is stable

### Monitoring for Changes

Check periodically:

- Ollama API documentation: https://github.com/ollama/ollama/blob/main/docs/api.md
- PostgreSQL full-text search: https://www.postgresql.org/docs/current/textsearch.html
- Python dependencies: Check `requirements-llm.txt` for security updates

Update frequency
: Review every 6–12 months for major changes

## Example Adaptation Workflow

### Initial Request to AI Assistant

```
I want to adapt the consultation analysis system to analyse [your data type].

Data format: [description]
Sample records: [paste 3-5 examples]
Topics of interest: [list domains]
Analysis goals: [what you want to learn]

Please create:
1. A data loader for this format
2. Domain configuration files for these topics
3. Updated LLM context for this data type
4. Validation tests for expected data characteristics
```

### AI Response Will Include

- New loader script in `profiles/your-name/loader.pl`
- Domain `.conf` files in `profiles/your-name/domains/`
- Updated LLM context in `10_llm_extract_positions.py`
- Modified test expectations in `test_system_end_to_end.sh`
- Profile metadata in `profiles/your-name/profile.yml`

### Iteration Process

1. Review loader - does it correctly parse your data?
2. Test with small dataset - does data load correctly?
3. Review domains - do keywords match your topics?
4. Test domain matching - do queries return expected results?
5. Review LLM context - does it describe your data correctly?
6. Test LLM extraction - do positions make sense?
7. Review reports - do they answer your questions?

## Common Adaptation Patterns

### Pattern 1: Directory of Text Files

Data source
: Directory containing .txt, .md, or similar files

Loader approach
: Iterate directory, read files, extract metadata from filenames/headers

Example mapping
: filename → `id`, file content → `response_text`, subdirectory → `user_type`

### Pattern 2: Structured Documents (CSV/JSON)

Data source
: Structured data with defined fields

Loader approach
: Parse format, map fields to responses table

Example mapping
: title + description → `full_text`, category → `user_type`, author → `organisation_name`

### Pattern 3: Threaded Discussions

Data source
: Forum posts, email threads, issue comments

Loader approach
: Parse thread structure, optionally collapse threads or keep individual

Example mapping
: thread_id → grouping, author → `organisation_name`, post_date → metadata

### Pattern 4: API-Sourced Data

Data source
: REST API, GraphQL endpoint

Loader approach
: Fetch via HTTP, paginate through results, transform to responses table

Example mapping
: API fields → responses columns, rate limiting considerations

## Best Practices

### Start Small

Initial dataset
: Test with 100–500 records before processing thousands

Domain count
: Begin with 3–5 domains, expand based on results

LLM extraction
: Test on one domain before running all

Iterate
: Refine domains and prompts based on initial results

### Maintain Separation

Keep profile-specific code separate
: Don't modify core pipeline unless necessary

Document adaptations
: Explain what changed and why

Version profiles
: Track profile versions separately from system version

Test independently
: Validate each profile doesn't break others

### Performance Considerations

Large datasets
: Plan for processing time (LLM extraction is slow)

Batch processing
: Use background processing for long-running extractions

Domain selectivity
: Overly broad domains match too many records

LLM rate limits
: Factor in API/model limitations

## Maintenance

### Regular Updates

Check for security updates
: Python dependencies, Docker base images

Monitor LLM developments
: New models, improved prompts

Update documentation
: Keep profile-specific docs current

Review domain definitions
: Refine keywords based on results

### Version Compatibility

System version
: Track which profile works with which system version

Profile metadata
: Include compatibility information

Breaking changes
: Document if updates require profile modifications

## Getting Help

When requesting adaptation assistance:

Be specific
: Provide concrete examples of your data

Include goals
: Explain what insights you're seeking

Share constraints
: Note any limitations or requirements

Provide feedback
: Iterate on initial implementations

This system is designed to be adapted. The core pipeline is robust and generic - creating a new profile is straightforward once you understand your data and goals.
