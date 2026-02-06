-- sql/00_reset_database.sql
-- Complete database reset with word frequency analysis and embeddings support

DROP DATABASE IF EXISTS documented_insights;
CREATE DATABASE documented_insights OWNER sysadmin;

\c documented_insights

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Main responses table
CREATE TABLE responses (
    id SERIAL PRIMARY KEY,
    ec_id INTEGER UNIQUE,
    -- Response metadata
    country TEXT,
    organization TEXT,
    user_type TEXT,
    language TEXT,
    date_feedback TIMESTAMP,
    -- Content
    feedback TEXT,
    attachment_path TEXT,
    attachment_text TEXT,
    full_text TEXT,
    fts_vector tsvector,
    -- Processing tracking
    has_attachment BOOLEAN DEFAULT false,
    attachment_extracted BOOLEAN DEFAULT false,
    embedding_generated BOOLEAN DEFAULT false,
    llm_processed BOOLEAN DEFAULT false,
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_responses_country ON responses(country);
CREATE INDEX idx_responses_org ON responses(organization);
CREATE INDEX idx_responses_user_type ON responses(user_type);
CREATE INDEX idx_responses_language ON responses(language);
CREATE INDEX idx_responses_has_attachment ON responses(has_attachment);
CREATE INDEX idx_responses_attachment_extracted ON responses(attachment_extracted);
CREATE INDEX idx_responses_embedding_generated ON responses(embedding_generated);
CREATE INDEX idx_responses_llm_processed ON responses(llm_processed);
CREATE INDEX idx_responses_fts ON responses USING GIN(fts_vector);

-- Word frequency tables
CREATE TABLE word_frequency (
    word TEXT PRIMARY KEY,
    total_count INTEGER NOT NULL,
    document_count INTEGER NOT NULL,
    avg_per_document NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_word_freq_count ON word_frequency(total_count DESC);
CREATE INDEX idx_word_freq_docs ON word_frequency(document_count DESC);

-- Per-response word counts
CREATE TABLE response_words (
    response_id INTEGER REFERENCES responses(id) ON DELETE CASCADE,
    word TEXT NOT NULL,
    count INTEGER NOT NULL,
    position_first INTEGER,
    PRIMARY KEY (response_id, word)
);

CREATE INDEX idx_response_words_word ON response_words(word);
CREATE INDEX idx_response_words_response ON response_words(response_id);

-- Stopwords
CREATE TABLE stopwords (
    word TEXT PRIMARY KEY,
    language TEXT DEFAULT 'english'
);

-- Load common English stopwords
INSERT INTO stopwords (word, language) VALUES
    ('the','english'),('be','english'),('to','english'),('of','english'),
    ('and','english'),('a','english'),('in','english'),('that','english'),
    ('have','english'),('it','english'),('for','english'),('not','english'),
    ('on','english'),('with','english'),('as','english'),('you','english'),
    ('do','english'),('at','english'),('this','english'),('but','english'),
    ('by','english'),('from','english'),('they','english'),('we','english'),
    ('her','english'),('or','english'),('an','english'),('will','english'),
    ('my','english'),('one','english'),('all','english'),('would','english'),
    ('there','english'),('their','english'),('what','english'),('so','english'),
    ('up','english'),('out','english'),('if','english'),('about','english'),
    ('who','english'),('which','english'),('when','english'),('make','english'),
    ('can','english'),('like','english'),('no','english'),('just','english'),
    ('know','english'),('take','english'),('into','english'),('your','english'),
    ('some','english'),('could','english'),('them','english'),('see','english'),
    ('than','english'),('now','english'),('only','english'),('its','english'),
    ('over','english'),('also','english'),('after','english'),('use','english'),
    ('two','english'),('how','english'),('our','english'),('well','english'),
    ('even','english'),('new','english'),('because','english'),('any','english'),
    ('these','english'),('give','english'),('most','english'),('us','english'),
    ('very','english'),('such','english'),('been','english'),('has','english'),
    ('had','english'),('may','english'),('should','english'),('being','english'),
    ('does','english'),('more','english'),('much','english'),('through','english'),
    ('however','english'),('therefore','english'),('furthermore','english'),
    ('moreover','english'),('nevertheless','english'),('are','english'),
    ('where','english'),('here','english'),('both','english'),('either','english'),
    ('neither','english'),('within','english'),('often','english'),('always','english'),
    ('never','english'),('via','english'),('per','english'),('among','english'),
    ('whilst','english'),('including','english'),('regarding','english'),
    ('concerning','english'),('towards','english'),('upon','english'),
    ('across','english'),('along','english'),('around','english'),
    ('beyond','english'),('despite','english'),('during','english'),
    ('following','english'),('next','english'),('previous','english'),
    ('using','english'),('given','english'),('become','english'),
    ('becomes','english'),('becoming','english'),('became','english'),
    ('else','english'),('elsewhere','english'),('hereby','english'),
    ('herein','english'),('thereof','english'),('whereby','english'),
    ('wherein','english'),('throughout','english'),('unless','english'),
    ('whether','english');

-- Vector embeddings table
CREATE TABLE response_embeddings (
    response_id INTEGER PRIMARY KEY REFERENCES responses(id) ON DELETE CASCADE,
    embedding vector(384),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_response_embeddings_vector ON response_embeddings 
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Analysis codes table (for LLM processing)
CREATE TABLE analysis_codes (
    id SERIAL PRIMARY KEY,
    response_id INTEGER REFERENCES responses(id) ON DELETE CASCADE,
    code_type TEXT NOT NULL,
    code_value TEXT NOT NULL,
    confidence REAL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_codes_response ON analysis_codes(response_id);
CREATE INDEX idx_codes_type_value ON analysis_codes(code_type, code_value);

-- Processing log
CREATE TABLE processing_log (
    id SERIAL PRIMARY KEY,
    response_id INTEGER REFERENCES responses(id) ON DELETE CASCADE,
    stage TEXT NOT NULL,
    status TEXT NOT NULL,
    error_message TEXT,
    duration_seconds REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_log_response ON processing_log(response_id);
CREATE INDEX idx_log_stage_status ON processing_log(stage, status);

-- Summary view
CREATE OR REPLACE VIEW response_summary AS
SELECT 
    COUNT(*) as total_responses,
    COUNT(CASE WHEN has_attachment THEN 1 END) as with_attachments,
    COUNT(CASE WHEN attachment_extracted THEN 1 END) as attachments_extracted,
    COUNT(CASE WHEN embedding_generated THEN 1 END) as embeddings_generated,
    COUNT(CASE WHEN llm_processed THEN 1 END) as llm_processed,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT organization) as organizations,
    COUNT(CASE WHEN full_text IS NOT NULL THEN 1 END) as with_text
FROM responses;

-- Trigger to maintain full_text and updated_at
CREATE OR REPLACE FUNCTION update_response_metadata()
RETURNS TRIGGER AS $$
BEGIN
    -- Combine feedback and attachment text
    NEW.full_text := CONCAT_WS(E'\n\n', NEW.feedback, NEW.attachment_text);
    
    -- Update timestamp
    NEW.updated_at := CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_response_metadata ON responses;
CREATE TRIGGER trg_update_response_metadata
    BEFORE INSERT OR UPDATE OF feedback, attachment_text
    ON responses
    FOR EACH ROW
    EXECUTE FUNCTION update_response_metadata();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sysadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sysadmin;

-- Show setup complete
SELECT 'Database reset complete' as status;
SELECT * FROM response_summary;
