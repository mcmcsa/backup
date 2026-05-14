-- Remove denormalized columns now that the app reads from relational joins.
-- Safe to run repeatedly.

BEGIN;

-- Snapshot columns were removed from the baseline schema.

COMMIT;
