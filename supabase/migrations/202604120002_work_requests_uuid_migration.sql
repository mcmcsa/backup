-- Convert work_requests.id from TEXT to UUID while preserving the legacy text ID.
-- Child tables that reference work_requests are updated to UUID foreign keys.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  current_type TEXT;
  pk_name TEXT;
  rec RECORD;
BEGIN
  SELECT data_type
    INTO current_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'work_requests'
    AND column_name = 'id';

  IF current_type = 'text' THEN
    -- Add temporary UUID columns and a legacy text snapshot.
    ALTER TABLE public.work_requests
      ADD COLUMN IF NOT EXISTS id_uuid UUID DEFAULT gen_random_uuid();

    ALTER TABLE public.work_requests
      ADD COLUMN IF NOT EXISTS legacy_id TEXT;

    ALTER TABLE public.e_signatures
      ADD COLUMN IF NOT EXISTS work_request_id_uuid UUID;

    ALTER TABLE public.pre_inspection_reports
      ADD COLUMN IF NOT EXISTS work_request_id_uuid UUID;

    ALTER TABLE public.post_repair_reports
      ADD COLUMN IF NOT EXISTS work_request_id_uuid UUID;

    ALTER TABLE public.app_notifications
      ADD COLUMN IF NOT EXISTS work_request_id_uuid UUID;

    UPDATE public.work_requests
    SET
      id_uuid = COALESCE(id_uuid, gen_random_uuid()),
      legacy_id = COALESCE(legacy_id, id)
    WHERE id IS NOT NULL;

    UPDATE public.e_signatures es
    SET work_request_id_uuid = wr.id_uuid
    FROM public.work_requests wr
    WHERE es.work_request_id = wr.id
      AND es.work_request_id_uuid IS NULL;

    UPDATE public.pre_inspection_reports pr
    SET work_request_id_uuid = wr.id_uuid
    FROM public.work_requests wr
    WHERE pr.work_request_id = wr.id
      AND pr.work_request_id_uuid IS NULL;

    UPDATE public.post_repair_reports pr
    SET work_request_id_uuid = wr.id_uuid
    FROM public.work_requests wr
    WHERE pr.work_request_id = wr.id
      AND pr.work_request_id_uuid IS NULL;

    UPDATE public.app_notifications an
    SET work_request_id_uuid = wr.id_uuid
    FROM public.work_requests wr
    WHERE an.work_request_id = wr.id
      AND an.work_request_id_uuid IS NULL;

    -- Drop the old foreign keys that still point to work_requests(id TEXT).
    FOR rec IN
      SELECT tc.table_schema, tc.table_name, tc.constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema = kcu.table_schema
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
       AND ccu.table_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
        AND tc.table_name IN ('e_signatures', 'pre_inspection_reports', 'post_repair_reports', 'app_notifications')
        AND kcu.column_name = 'work_request_id'
        AND ccu.table_name = 'work_requests'
        AND ccu.column_name = 'id'
    LOOP
      EXECUTE format(
        'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I',
        rec.table_schema,
        rec.table_name,
        rec.constraint_name
      );
    END LOOP;

    -- Drop the current primary key on work_requests.id so the column can be swapped.
    SELECT tc.constraint_name
      INTO pk_name
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'work_requests'
      AND tc.constraint_type = 'PRIMARY KEY';

    IF pk_name IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.work_requests DROP CONSTRAINT IF EXISTS %I', pk_name);
    END IF;

    -- Swap work_requests.id to UUID and keep the original text value in legacy_id.
    ALTER TABLE public.work_requests DROP COLUMN IF EXISTS id;
    ALTER TABLE public.work_requests RENAME COLUMN id_uuid TO id;
    ALTER TABLE public.work_requests
      ALTER COLUMN id SET DEFAULT gen_random_uuid();
    ALTER TABLE public.work_requests
      ALTER COLUMN id SET NOT NULL;
    ALTER TABLE public.work_requests
      ADD PRIMARY KEY (id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_work_requests_legacy_id ON public.work_requests(legacy_id);

    -- Swap child foreign key columns to UUID.
    ALTER TABLE public.e_signatures DROP COLUMN IF EXISTS work_request_id;
    ALTER TABLE public.e_signatures RENAME COLUMN work_request_id_uuid TO work_request_id;
    ALTER TABLE public.e_signatures
      ALTER COLUMN work_request_id SET NOT NULL;
    ALTER TABLE public.e_signatures
      ADD CONSTRAINT e_signatures_work_request_id_fkey
      FOREIGN KEY (work_request_id) REFERENCES public.work_requests(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_e_signatures_work_request_id ON public.e_signatures(work_request_id);

    ALTER TABLE public.pre_inspection_reports DROP COLUMN IF EXISTS work_request_id;
    ALTER TABLE public.pre_inspection_reports RENAME COLUMN work_request_id_uuid TO work_request_id;
    ALTER TABLE public.pre_inspection_reports
      ALTER COLUMN work_request_id SET NOT NULL;
    ALTER TABLE public.pre_inspection_reports
      ADD CONSTRAINT pre_inspection_reports_work_request_id_fkey
      FOREIGN KEY (work_request_id) REFERENCES public.work_requests(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_pre_inspection_reports_work_request_id ON public.pre_inspection_reports(work_request_id);

    ALTER TABLE public.post_repair_reports DROP COLUMN IF EXISTS work_request_id;
    ALTER TABLE public.post_repair_reports RENAME COLUMN work_request_id_uuid TO work_request_id;
    ALTER TABLE public.post_repair_reports
      ALTER COLUMN work_request_id SET NOT NULL;
    ALTER TABLE public.post_repair_reports
      ADD CONSTRAINT post_repair_reports_work_request_id_fkey
      FOREIGN KEY (work_request_id) REFERENCES public.work_requests(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_post_repair_reports_work_request_id ON public.post_repair_reports(work_request_id);

    ALTER TABLE public.app_notifications DROP COLUMN IF EXISTS work_request_id;
    ALTER TABLE public.app_notifications RENAME COLUMN work_request_id_uuid TO work_request_id;
    ALTER TABLE public.app_notifications
      ADD CONSTRAINT app_notifications_work_request_id_fkey
      FOREIGN KEY (work_request_id) REFERENCES public.work_requests(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_app_notifications_work_request_id ON public.app_notifications(work_request_id);
  END IF;
END $$;
