-- Backfill QR history metadata to match current room information.
-- Keeps existing values when linked room/building/department data is unavailable.

UPDATE public.qr_code_history AS q
SET
  room_name = COALESCE(NULLIF(btrim(r.name), ''), q.room_name),
  building = COALESCE(NULLIF(btrim(b.name), ''), q.building),
  department = COALESCE(NULLIF(btrim(d.name), ''), q.department)
FROM public.rooms AS r
LEFT JOIN public.buildings AS b ON b.id = r.building_id
LEFT JOIN public.departments AS d ON d.id = r.department_id
WHERE q.room_id = r.id
  AND (
    q.room_name IS DISTINCT FROM COALESCE(NULLIF(btrim(r.name), ''), q.room_name)
    OR q.building IS DISTINCT FROM COALESCE(NULLIF(btrim(b.name), ''), q.building)
    OR q.department IS DISTINCT FROM COALESCE(NULLIF(btrim(d.name), ''), q.department)
  );
