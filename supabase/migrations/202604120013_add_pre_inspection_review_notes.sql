ALTER TABLE public.pre_inspection_reports
ADD COLUMN IF NOT EXISTS review_notes TEXT;

UPDATE public.pre_inspection_reports
SET review_notes = COALESCE(review_notes, notes)
WHERE review_notes IS NULL AND notes IS NOT NULL;
