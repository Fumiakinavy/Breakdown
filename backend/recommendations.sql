WITH target AS (
    SELECT embedding
    FROM user_profiles
    WHERE id = :user_id
),
related_tasks AS (
    SELECT t.id,
           t.title,
           sn.embedding <=> (SELECT embedding FROM target) AS distance
    FROM tasks t
    JOIN subtask_nodes sn ON sn.task_id = t.id
    WHERE sn.embedding IS NOT NULL
    ORDER BY sn.embedding <=> (SELECT embedding FROM target)
    LIMIT 10
)
SELECT r.id,
       r.title,
       jsonb_build_object(
           'confidence', 1 - r.distance,
           'reason', 'similar past tasks via pgvector'
       ) AS metadata
FROM related_tasks r;
