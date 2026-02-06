-- Phase 1: LLM Position Analysis Schema
-- Add position extraction capability to documented_insights database

-- ============================================================================
-- SECTION 1: Add LLM Processing Flags to Responses Table
-- ============================================================================

-- Track LLM extraction status per response
ALTER TABLE responses 
ADD COLUMN IF NOT EXISTS llm_extracted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS llm_extraction_failed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS llm_extraction_error TEXT;

-- Create index for filtering processed/failed responses
CREATE INDEX IF NOT EXISTS idx_responses_llm_extracted 
ON responses(llm_extracted) WHERE llm_extracted = FALSE;

CREATE INDEX IF NOT EXISTS idx_responses_llm_failed 
ON responses(llm_extraction_failed) WHERE llm_extraction_failed = TRUE;

-- Add comment explaining processing flags
COMMENT ON COLUMN responses.llm_extracted IS 
'TRUE when LLM position extraction completed successfully';

COMMENT ON COLUMN responses.llm_extraction_failed IS 
'TRUE when LLM extraction failed (available for retry)';

COMMENT ON COLUMN responses.llm_extraction_error IS 
'Error message from failed LLM extraction attempt';

-- ============================================================================
-- SECTION 2: Position Analysis Table
-- ============================================================================

-- Store LLM-extracted positions from consultation responses
CREATE TABLE IF NOT EXISTS position_analysis (
    id SERIAL PRIMARY KEY,
    response_id INTEGER NOT NULL REFERENCES responses(id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    position_type TEXT NOT NULL,
    position_category TEXT,
    strength TEXT,
    argument_summary TEXT,
    evidence_cited TEXT[],
    specific_proposal TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_response 
        FOREIGN KEY (response_id) REFERENCES responses(id) ON DELETE CASCADE,
    CONSTRAINT valid_position_type 
        CHECK (position_type IN ('support', 'oppose', 'neutral', 'mixed')),
    CONSTRAINT valid_strength 
        CHECK (strength IN ('strong', 'moderate', 'weak'))
);

-- Add table comment
COMMENT ON TABLE position_analysis IS 
'LLM-extracted stakeholder positions from consultation responses';

-- Add column comments
COMMENT ON COLUMN position_analysis.response_id IS 
'Foreign key to responses table';

COMMENT ON COLUMN position_analysis.domain IS 
'Policy domain (taxation, procurement, sovereignty, vendor-lock, security)';

COMMENT ON COLUMN position_analysis.position_type IS 
'Stance: support, oppose, neutral, or mixed';

COMMENT ON COLUMN position_analysis.position_category IS 
'Type of position (e.g., public_funding, tax_incentive, levy, procurement_preference)';

COMMENT ON COLUMN position_analysis.strength IS 
'Advocacy intensity: strong, moderate, or weak';

COMMENT ON COLUMN position_analysis.argument_summary IS 
'Core argument in 1-2 sentences';

COMMENT ON COLUMN position_analysis.evidence_cited IS 
'Array of citations, examples, or precedents mentioned';

COMMENT ON COLUMN position_analysis.specific_proposal IS 
'Concrete policy ask if mentioned';

-- ============================================================================
-- SECTION 3: Indexes for Performance
-- ============================================================================

-- Index for domain-based queries
CREATE INDEX IF NOT EXISTS idx_position_domain 
ON position_analysis(domain);

-- Index for position category grouping
CREATE INDEX IF NOT EXISTS idx_position_category 
ON position_analysis(position_category);

-- Index for position type filtering
CREATE INDEX IF NOT EXISTS idx_position_type 
ON position_analysis(position_type);

-- Index for strength filtering
CREATE INDEX IF NOT EXISTS idx_position_strength 
ON position_analysis(strength);

-- Composite index for domain + category queries (most common)
CREATE INDEX IF NOT EXISTS idx_position_domain_category 
ON position_analysis(domain, position_category);

-- Index for response_id lookups
CREATE INDEX IF NOT EXISTS idx_position_response 
ON position_analysis(response_id);

-- ============================================================================
-- SECTION 4: Aggregation Views
-- ============================================================================

-- Summary of position extraction by domain
CREATE OR REPLACE VIEW position_extraction_progress AS
SELECT 
    domain,
    COUNT(DISTINCT response_id) as responses_with_positions,
    COUNT(*) as total_positions,
    COUNT(DISTINCT position_category) as distinct_categories,
    ROUND(AVG(CASE 
        WHEN strength = 'strong' THEN 3 
        WHEN strength = 'moderate' THEN 2 
        WHEN strength = 'weak' THEN 1 
    END), 2) as avg_strength_score,
    COUNT(CASE WHEN position_type = 'support' THEN 1 END) as support_count,
    COUNT(CASE WHEN position_type = 'oppose' THEN 1 END) as oppose_count,
    COUNT(CASE WHEN position_type = 'neutral' THEN 1 END) as neutral_count,
    COUNT(CASE WHEN position_type = 'mixed' THEN 1 END) as mixed_count
FROM position_analysis
GROUP BY domain
ORDER BY domain;

COMMENT ON VIEW position_extraction_progress IS 
'Overview of LLM position extraction by domain';

-- Summary of positions by domain and category
CREATE OR REPLACE VIEW position_summary AS
SELECT 
    p.domain,
    p.position_category,
    p.position_type,
    COUNT(*) as response_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY p.domain), 1) as pct_of_domain,
    COUNT(DISTINCT r.user_type) as stakeholder_types,
    COUNT(DISTINCT r.country) as countries,
    ROUND(100.0 * COUNT(CASE WHEN p.strength='strong' THEN 1 END) / COUNT(*), 1) as pct_strong,
    ROUND(100.0 * COUNT(CASE WHEN p.strength='moderate' THEN 1 END) / COUNT(*), 1) as pct_moderate,
    ROUND(100.0 * COUNT(CASE WHEN p.strength='weak' THEN 1 END) / COUNT(*), 1) as pct_weak,
    COUNT(CASE WHEN p.specific_proposal IS NOT NULL AND p.specific_proposal != '' THEN 1 END) as with_proposals,
    COUNT(CASE WHEN array_length(p.evidence_cited, 1) > 0 THEN 1 END) as with_evidence
FROM position_analysis p
JOIN responses r ON p.response_id = r.id
GROUP BY p.domain, p.position_category, p.position_type
ORDER BY p.domain, response_count DESC;

COMMENT ON VIEW position_summary IS 
'Aggregated position statistics by domain, category, and type';

-- Stakeholder breakdown by position category
CREATE OR REPLACE VIEW position_stakeholders AS
SELECT 
    p.domain,
    p.position_category,
    r.user_type,
    COUNT(*) as response_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY p.domain, p.position_category), 1) as pct_of_category,
    COUNT(CASE WHEN p.position_type = 'support' THEN 1 END) as support_count,
    COUNT(CASE WHEN p.position_type = 'oppose' THEN 1 END) as oppose_count,
    ROUND(100.0 * COUNT(CASE WHEN p.strength='strong' THEN 1 END) / COUNT(*), 1) as pct_strong_advocacy
FROM position_analysis p
JOIN responses r ON p.response_id = r.id
GROUP BY p.domain, p.position_category, r.user_type
ORDER BY p.domain, p.position_category, response_count DESC;

COMMENT ON VIEW position_stakeholders IS 
'Position distribution by stakeholder type';

-- Overall processing status across all responses
CREATE OR REPLACE VIEW llm_processing_status AS
SELECT 
    COUNT(*) as total_responses,
    COUNT(CASE WHEN llm_extracted = TRUE THEN 1 END) as extracted_success,
    COUNT(CASE WHEN llm_extraction_failed = TRUE THEN 1 END) as extracted_failed,
    COUNT(CASE WHEN llm_extracted = FALSE AND llm_extraction_failed = FALSE THEN 1 END) as not_attempted,
    ROUND(100.0 * COUNT(CASE WHEN llm_extracted = TRUE THEN 1 END) / COUNT(*), 1) as pct_complete,
    COUNT(DISTINCT CASE WHEN llm_extracted = TRUE THEN id END) as responses_with_positions
FROM responses;

COMMENT ON VIEW llm_processing_status IS 
'Overall LLM extraction progress across all responses';

-- ============================================================================
-- SECTION 5: Helper Functions
-- ============================================================================

-- Function to reset LLM processing for a domain (for re-extraction)
CREATE OR REPLACE FUNCTION reset_llm_extraction(p_domain TEXT)
RETURNS TABLE(
    responses_reset INTEGER,
    positions_deleted INTEGER
) AS $$
DECLARE
    v_responses_reset INTEGER;
    v_positions_deleted INTEGER;
BEGIN
    -- Get matching response IDs for domain
    WITH domain_responses AS (
        SELECT DISTINCT response_id 
        FROM position_analysis 
        WHERE domain = p_domain
    )
    -- Delete positions for this domain
    DELETE FROM position_analysis 
    WHERE domain = p_domain;
    
    GET DIAGNOSTICS v_positions_deleted = ROW_COUNT;
    
    -- Reset processing flags for responses that had positions in this domain
    WITH domain_responses AS (
        SELECT DISTINCT response_id 
        FROM position_analysis 
        WHERE domain = p_domain
    )
    UPDATE responses 
    SET llm_extracted = FALSE,
        llm_extraction_failed = FALSE,
        llm_extraction_error = NULL
    WHERE id IN (SELECT response_id FROM domain_responses);
    
    GET DIAGNOSTICS v_responses_reset = ROW_COUNT;
    
    RETURN QUERY SELECT v_responses_reset, v_positions_deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reset_llm_extraction(TEXT) IS 
'Reset LLM extraction for a specific domain (deletes positions, resets flags)';

-- Function to mark response as extraction failed
CREATE OR REPLACE FUNCTION mark_extraction_failed(
    p_response_id INTEGER,
    p_error_message TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE responses
    SET llm_extraction_failed = TRUE,
        llm_extraction_error = p_error_message,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_response_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mark_extraction_failed(INTEGER, TEXT) IS 
'Mark a response as failed LLM extraction with error message';

-- Function to mark response as extraction successful
CREATE OR REPLACE FUNCTION mark_extraction_success(p_response_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE responses
    SET llm_extracted = TRUE,
        llm_extraction_failed = FALSE,
        llm_extraction_error = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_response_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mark_extraction_success(INTEGER) IS 
'Mark a response as successful LLM extraction';

-- ============================================================================
-- SECTION 6: Sample Queries (for testing)
-- ============================================================================

-- Sample queries commented out but available for testing after data population

/*
-- View extraction progress by domain
SELECT * FROM position_extraction_progress;

-- View position summary for a domain
SELECT * FROM position_summary WHERE domain = 'taxation';

-- View stakeholder breakdown for a position category
SELECT * FROM position_stakeholders 
WHERE domain = 'taxation' AND position_category = 'public_funding';

-- Overall processing status
SELECT * FROM llm_processing_status;

-- Find responses with strong support positions
SELECT r.id, r.country, r.user_type, p.position_category, p.argument_summary
FROM position_analysis p
JOIN responses r ON p.response_id = r.id
WHERE p.domain = 'taxation' 
  AND p.position_type = 'support' 
  AND p.strength = 'strong'
ORDER BY r.country, r.user_type;

-- Find positions with specific proposals
SELECT r.id, r.country, r.user_type, p.position_category, p.specific_proposal
FROM position_analysis p
JOIN responses r ON p.response_id = r.id
WHERE p.domain = 'taxation' 
  AND p.specific_proposal IS NOT NULL
ORDER BY r.country;

-- Find positions citing evidence
SELECT r.id, r.country, r.user_type, p.position_category, p.evidence_cited
FROM position_analysis p
JOIN responses r ON p.response_id = r.id
WHERE p.domain = 'taxation' 
  AND array_length(p.evidence_cited, 1) > 0
ORDER BY array_length(p.evidence_cited, 1) DESC;

-- Count positions per response (multiple positions possible)
SELECT r.id, r.country, r.user_type, COUNT(p.id) as position_count
FROM responses r
LEFT JOIN position_analysis p ON r.id = p.response_id
WHERE p.domain = 'taxation'
GROUP BY r.id, r.country, r.user_type
ORDER BY COUNT(p.id) DESC;

-- Reset extraction for a domain (use with caution)
SELECT * FROM reset_llm_extraction('taxation');
*/

-- ============================================================================
-- SECTION 7: Grants and Permissions
-- ============================================================================

-- Grant SELECT on views to sysadmin (if not already inherited)
GRANT SELECT ON position_extraction_progress TO sysadmin;
GRANT SELECT ON position_summary TO sysadmin;
GRANT SELECT ON position_stakeholders TO sysadmin;
GRANT SELECT ON llm_processing_status TO sysadmin;

-- Grant EXECUTE on functions to sysadmin
GRANT EXECUTE ON FUNCTION reset_llm_extraction(TEXT) TO sysadmin;
GRANT EXECUTE ON FUNCTION mark_extraction_failed(INTEGER, TEXT) TO sysadmin;
GRANT EXECUTE ON FUNCTION mark_extraction_success(INTEGER) TO sysadmin;

-- ============================================================================
-- Schema Installation Complete
-- ============================================================================

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE 'LLM Position Analysis schema installed successfully';
    RAISE NOTICE 'Tables: position_analysis';
    RAISE NOTICE 'Views: position_extraction_progress, position_summary, position_stakeholders, llm_processing_status';
    RAISE NOTICE 'Functions: reset_llm_extraction, mark_extraction_failed, mark_extraction_success';
    RAISE NOTICE 'Ready for Phase 2: Python LLM extraction script';
END $$;
