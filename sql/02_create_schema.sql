-- Schema for documented-insights
-- Run as: psql -U sysadmin -d documented_insights < sql/02_create_schema.sql

-- Responses table (main data)
CREATE TABLE IF NOT EXISTS responses (
    id INTEGER PRIMARY KEY,
    link TEXT,
    reference_initiative TEXT,
    date_feedback DATE,
    feedback TEXT,
    language TEXT,
    user_type TEXT,
    country TEXT,
    publication TEXT,
    status TEXT,
    first_name TEXT,
    surname TEXT,
    login TEXT,
    attachments TEXT,
    publication_id TEXT,
    is_my_feedback BOOLEAN,
    is_liked_by_me BOOLEAN,
    is_disliked_by_me BOOLEAN,
    publication_status TEXT,
    feedback_text_user_language TEXT,
    company_size TEXT,
    organization TEXT,
    tr_number TEXT,
    scope TEXT,
    governance_level TEXT,
    -- Extracted content
    attachment_text TEXT,
    full_text TEXT,
    -- Processing metadata
    has_attachment BOOLEAN DEFAULT FALSE,
    attachment_extracted BOOLEAN DEFAULT FALSE,
    embedding_generated BOOLEAN DEFAULT FALSE,
    llm_processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_responses_user_type ON responses(user_type);
CREATE INDEX IF NOT EXISTS idx_responses_country ON responses(country);
CREATE INDEX IF NOT EXISTS idx_responses_organization ON responses(organization);
CREATE INDEX IF NOT EXISTS idx_responses_language ON responses(language);
CREATE INDEX IF NOT EXISTS idx_responses_has_attachment ON responses(has_attachment);
CREATE INDEX IF NOT EXISTS idx_responses_llm_processed ON responses(llm_processed);

-- Embeddings table
CREATE TABLE IF NOT EXISTS response_embeddings (
    response_id INTEGER REFERENCES responses(id) ON DELETE CASCADE,
    embedding vector(384),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (response_id)
);

-- Analysis codes table
CREATE TABLE IF NOT EXISTS analysis_codes (
    id SERIAL PRIMARY KEY,
    response_id INTEGER REFERENCES responses(id) ON DELETE CASCADE,
    code_type TEXT NOT NULL,
    code_value TEXT NOT NULL,
    confidence REAL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_codes_response ON analysis_codes(response_id);
CREATE INDEX IF NOT EXISTS idx_codes_type_value ON analysis_codes(code_type, code_value);

-- Processing log
CREATE TABLE IF NOT EXISTS processing_log (
    id SERIAL PRIMARY KEY,
    response_id INTEGER REFERENCES responses(id) ON DELETE CASCADE,
    stage TEXT NOT NULL,
    status TEXT NOT NULL,
    error_message TEXT,
    duration_seconds REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_log_response ON processing_log(response_id);
CREATE INDEX IF NOT EXISTS idx_log_stage_status ON processing_log(stage, status);

-- Views
CREATE OR REPLACE VIEW response_summary AS
SELECT 
    COUNT(*) as total_responses,
    COUNT(CASE WHEN has_attachment THEN 1 END) as with_attachments,
    COUNT(CASE WHEN attachment_extracted THEN 1 END) as attachments_extracted,
    COUNT(CASE WHEN embedding_generated THEN 1 END) as embeddings_generated,
    COUNT(CASE WHEN llm_processed THEN 1 END) as llm_processed,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT organization) as organizations
FROM responses;

-- Function to update full_text
CREATE OR REPLACE FUNCTION update_full_text()
RETURNS TRIGGER AS $$
BEGIN
    NEW.full_text := CONCAT_WS(E'\n\n', NEW.feedback, NEW.attachment_text);
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_full_text ON responses;
CREATE TRIGGER trg_update_full_text
    BEFORE INSERT OR UPDATE OF feedback, attachment_text
    ON responses
    FOR EACH ROW
    EXECUTE FUNCTION update_full_text();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sysadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sysadmin;
