BEGIN;

-- Keep the latest attendance row per (user_id, event_id).
WITH ranked_attendance AS (
    SELECT attendance_id,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, event_id
               ORDER BY check_in_time DESC NULLS LAST, created_at DESC NULLS LAST, attendance_id DESC
           ) AS rn
    FROM attendance
)
DELETE FROM attendance
WHERE attendance_id IN (
    SELECT attendance_id
    FROM ranked_attendance
    WHERE rn > 1
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_attendance_user_event'
          AND conrelid = 'attendance'::regclass
    ) THEN
        ALTER TABLE attendance
            ADD CONSTRAINT uq_attendance_user_event UNIQUE (user_id, event_id);
    END IF;
END $$;

COMMIT;

-- Verify:
-- SELECT user_id, event_id, COUNT(*) FROM attendance GROUP BY user_id, event_id HAVING COUNT(*) > 1;
