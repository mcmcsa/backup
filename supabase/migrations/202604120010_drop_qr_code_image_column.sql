-- Remove unused qr_code_image column from qr_code_history.
-- Safe to run repeatedly.

BEGIN;

ALTER TABLE public.qr_code_history DROP COLUMN IF EXISTS qr_code_image CASCADE;

COMMIT;
