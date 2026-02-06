#!/usr/bin/env python3
"""
Generate vector embeddings for semantic search
"""

import os
import psycopg2
from sentence_transformers import SentenceTransformer
import sys

# Configuration
db_config = {
    'dbname': os.getenv('POSTGRES_DB', 'documented_insights'),
    'user': os.getenv('POSTGRES_USER', 'sysadmin'),
    'password': os.getenv('POSTGRES_PASSWORD', 'changeme'),
    'host': os.getenv('POSTGRES_HOST', 'postgres'),
    'port': os.getenv('POSTGRES_PORT', '5432')
}

print("Generating embeddings for semantic search...")
print(f"Database: {db_config['dbname']}\n")

# Connect to database
conn = psycopg2.connect(**db_config)
cur = conn.cursor()

# Load embedding model
print("Loading sentence-transformers model (all-MiniLM-L6-v2)...")
model = SentenceTransformer('all-MiniLM-L6-v2')
print("Model loaded.\n")

# Fetch responses without embeddings
print("Fetching responses that need embeddings...")
cur.execute("""
    SELECT r.id, r.full_text 
    FROM responses r
    LEFT JOIN response_embeddings e ON r.id = e.response_id
    WHERE e.response_id IS NULL
    AND r.full_text IS NOT NULL
    AND r.full_text != ''
    ORDER BY r.id
""")

rows = cur.fetchall()
print(f"Found {len(rows)} responses to process\n")

if len(rows) == 0:
    print("No responses need embeddings. Done!")
    cur.close()
    conn.close()
    sys.exit(0)

# Process in batches
batch_size = 32
total = len(rows)
processed = 0

for i in range(0, total, batch_size):
    batch = rows[i:i+batch_size]
    ids = [row[0] for row in batch]
    texts = [row[1] for row in batch]
    
    # Generate embeddings
    print(f"Processing batch {i//batch_size + 1}/{(total + batch_size - 1)//batch_size} ({len(batch)} responses)...")
    embeddings = model.encode(texts, show_progress_bar=False)
    
    # Store in database
    for response_id, embedding in zip(ids, embeddings):
        cur.execute("""
            INSERT INTO response_embeddings (response_id, embedding)
            VALUES (%s, %s)
            ON CONFLICT (response_id) DO UPDATE
            SET embedding = EXCLUDED.embedding
        """, (response_id, embedding.tolist()))
    
    # Update processing flag
    cur.execute("""
        UPDATE responses
        SET embedding_generated = true
        WHERE id = ANY(%s)
    """, (ids,))
    
    conn.commit()
    processed += len(batch)
    print(f"  {processed}/{total} responses processed")

print("\n=== Embedding Generation Complete ===")
print(f"Total embeddings generated: {processed}")

# Create index for fast similarity search if it doesn't exist
print("\nCreating vector similarity index...")
cur.execute("""
    CREATE INDEX IF NOT EXISTS idx_embeddings_vector 
    ON response_embeddings 
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
""")
conn.commit()
print("Index created.")

# Show summary
cur.execute("SELECT * FROM response_summary")
summary = cur.fetchone()
print("\nDatabase summary:")
print(f"  Total responses: {summary[0]}")
print(f"  Embeddings generated: {summary[3]}")
print(f"  Coverage: {100*summary[3]/summary[0]:.1f}%")

cur.close()
conn.close()

print("\n✓ Embeddings ready for semantic search!")
