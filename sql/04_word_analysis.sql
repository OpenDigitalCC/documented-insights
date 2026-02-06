-- sql/04_word_analysis.sql

\echo '=== CORPUS STATISTICS ==='
SELECT 
    COUNT(DISTINCT response_id) as total_responses,
    COUNT(DISTINCT word) as unique_words,
    SUM(count)::bigint as total_word_instances,
    ROUND(AVG(count), 2) as avg_word_frequency
FROM response_words;

\echo ''
\echo '=== TOP 50 WORDS BY FREQUENCY ==='
SELECT 
    word,
    total_count,
    document_count,
    ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct_docs,
    ROUND(avg_per_document, 2) as avg_per_doc
FROM word_frequency
ORDER BY total_count DESC
LIMIT 50;

\echo ''
\echo '=== DISTINCTIVE WORDS (appear often but not everywhere) ==='
-- High concentration = appears many times in fewer documents
SELECT 
    word,
    total_count,
    document_count,
    ROUND(total_count::numeric / document_count, 2) as concentration,
    ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as doc_pct
FROM word_frequency
WHERE document_count >= 10
  AND document_count < (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL) * 0.5
ORDER BY concentration DESC
LIMIT 30;

\echo ''
\echo '=== DOMAIN-SPECIFIC TERMS (technical/policy vocabulary) ==='
SELECT 
    word,
    total_count,
    document_count,
    ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as doc_pct
FROM word_frequency
WHERE LENGTH(word) > 8
  AND document_count > 20
  AND word !~ '[0-9]'
ORDER BY total_count DESC
LIMIT 40;

\echo ''
\echo '=== WORD CO-OCCURRENCE: sovereignty ==='
SELECT 
    w2.word,
    COUNT(*) as co_occur,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM response_words WHERE word = 'sovereignty'), 1) as pct
FROM response_words w1
JOIN response_words w2 ON w1.response_id = w2.response_id
WHERE w1.word = 'sovereignty'
  AND w2.word != 'sovereignty'
  AND w2.word NOT IN (SELECT word FROM stopwords)
GROUP BY w2.word
ORDER BY COUNT(*) DESC
LIMIT 20;

\echo ''
\echo '=== WORD CO-OCCURRENCE: procurement ==='
SELECT 
    w2.word,
    COUNT(*) as co_occur,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM response_words WHERE word = 'procurement'), 1) as pct
FROM response_words w1
JOIN response_words w2 ON w1.response_id = w2.response_id
WHERE w1.word = 'procurement'
  AND w2.word != 'procurement'
  AND w2.word NOT IN (SELECT word FROM stopwords)
GROUP BY w2.word
ORDER BY COUNT(*) DESC
LIMIT 20;

\echo ''
\echo '=== WORD CO-OCCURRENCE: security ==='
SELECT 
    w2.word,
    COUNT(*) as co_occur
FROM response_words w1
JOIN response_words w2 ON w1.response_id = w2.response_id
WHERE w1.word = 'security'
  AND w2.word != 'security'
  AND w2.word NOT IN (SELECT word FROM stopwords)
GROUP BY w2.word
ORDER BY COUNT(*) DESC
LIMIT 20;

\echo ''
\echo '=== WORD CO-OCCURRENCE: open-source ==='
SELECT 
    w2.word,
    COUNT(*) as co_occur
FROM response_words w1
JOIN response_words w2 ON w1.response_id = w2.response_id
WHERE w1.word = 'open-source'
  AND w2.word != 'open-source'
  AND w2.word NOT IN (SELECT word FROM stopwords)
GROUP BY w2.word
ORDER BY COUNT(*) DESC
LIMIT 20;

\echo ''
\echo '=== FULL TEXT SEARCH EXAMPLES ==='
\echo 'Example 1: vendor lock-in'
SELECT 
    id,
    country,
    user_type,
    organization,
    ts_rank(fts_vector, query) as relevance,
    substring(full_text from 1 for 150) || '...' as excerpt
FROM responses, 
     to_tsquery('english', 'vendor & (lock | lockin)') as query
WHERE fts_vector @@ query
ORDER BY relevance DESC
LIMIT 5;

\echo ''
\echo 'Example 2: public procurement barriers'
SELECT 
    id,
    country,
    user_type,
    ts_rank(fts_vector, query) as relevance,
    substring(full_text from 1 for 150) || '...' as excerpt
FROM responses,
     to_tsquery('english', 'public & procurement & (barrier | discrimination | unfair)') as query
WHERE fts_vector @@ query
ORDER BY relevance DESC
LIMIT 5;
