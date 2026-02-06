-- Verification script for LLM position analysis schema
-- Run after: make llm-schema

\echo '================================'
\echo 'LLM Position Analysis Schema Test'
\echo '================================'
\echo ''

-- Check table exists
\echo 'Checking position_analysis table...'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables 
                     WHERE table_name = 'position_analysis') 
        THEN '✓ position_analysis table exists'
        ELSE '✗ position_analysis table NOT FOUND'
    END as status;

-- Check columns added to responses
\echo ''
\echo 'Checking responses table columns...'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                     WHERE table_name = 'responses' AND column_name = 'llm_extracted')
        THEN '✓ llm_extracted column exists'
        ELSE '✗ llm_extracted column NOT FOUND'
    END as status
UNION ALL
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                     WHERE table_name = 'responses' AND column_name = 'llm_extraction_failed')
        THEN '✓ llm_extraction_failed column exists'
        ELSE '✗ llm_extraction_failed column NOT FOUND'
    END
UNION ALL
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                     WHERE table_name = 'responses' AND column_name = 'llm_extraction_error')
        THEN '✓ llm_extraction_error column exists'
        ELSE '✗ llm_extraction_error column NOT FOUND'
    END;

-- Check indexes
\echo ''
\echo 'Checking indexes...'
SELECT 
    indexname,
    '✓ Index exists' as status
FROM pg_indexes
WHERE tablename = 'position_analysis'
ORDER BY indexname;

-- Check views
\echo ''
\echo 'Checking views...'
SELECT 
    table_name,
    '✓ View exists' as status
FROM information_schema.views
WHERE table_name IN (
    'position_extraction_progress',
    'position_summary',
    'position_stakeholders',
    'llm_processing_status'
)
ORDER BY table_name;

-- Check functions
\echo ''
\echo 'Checking functions...'
SELECT 
    routine_name,
    '✓ Function exists' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'FUNCTION'
  AND routine_name IN (
    'reset_llm_extraction',
    'mark_extraction_failed',
    'mark_extraction_success'
)
ORDER BY routine_name;

-- Check constraints
\echo ''
\echo 'Checking constraints...'
SELECT 
    constraint_name,
    '✓ Constraint exists' as status
FROM information_schema.table_constraints
WHERE table_name = 'position_analysis'
ORDER BY constraint_name;

-- Check initial processing status
\echo ''
\echo 'Initial processing status:'
SELECT * FROM llm_processing_status;

-- Show table structure
\echo ''
\echo 'position_analysis table structure:'
\d+ position_analysis

\echo ''
\echo '================================'
\echo 'Schema verification complete'
\echo '================================'
