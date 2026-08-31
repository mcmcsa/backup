-- Migration: Add duplicate_of_id column to work_requests table (Phase 2 - Step 4)
-- Date: 2026-08-27

ALTER TABLE public.work_requests 
  ADD COLUMN IF NOT EXISTS duplicate_of_id uuid REFERENCES public.work_requests(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_work_requests_duplicate_of_id ON public.work_requests(duplicate_of_id);
