-- PSU Maintenance Management System - Seed Lookups
-- Copy and run this script in your Supabase SQL Editor (https://supabase.com) to populate core lookups.

-- 1. Seed Departments
INSERT INTO public.departments (id, name) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'College of Information Technology'),
  ('a2222222-2222-2222-2222-222222222222', 'College of Engineering'),
  ('a3333333-3333-3333-3333-333333333333', 'College of Arts and Sciences'),
  ('a4444444-4444-4444-4444-444444444444', 'College of Business'),
  ('a5555555-5555-5555-5555-555555555555', 'College of Education')
ON CONFLICT (name) DO NOTHING;

-- 2. Seed Buildings
INSERT INTO public.buildings (id, name, code, department_id) VALUES
  ('b1111111-1111-1111-1111-111111111111', 'CIT Building', 'CITB', 'a1111111-1111-1111-1111-111111111111'),
  ('b2222222-2222-2222-2222-222222222222', 'Engineering Building A', 'EBA', 'a2222222-2222-2222-2222-222222222222'),
  ('b3333333-3333-3333-3333-333333333333', 'Science Complex', 'SC', 'a3333333-3333-3333-3333-333333333333'),
  ('b4444444-4444-4444-4444-444444444444', 'Administration Building', 'AB', NULL)
ON CONFLICT (code) DO NOTHING;

-- 3. Seed Room Types
INSERT INTO public.room_types (id, name) VALUES
  ('c1111111-1111-1111-1111-111111111111', 'Laboratory'),
  ('c2222222-2222-2222-2222-222222222222', 'Lecture Hall'),
  ('c3333333-3333-3333-3333-333333333333', 'Seminar Room'),
  ('c4444444-4444-4444-4444-444444444444', 'Office')
ON CONFLICT (name) DO NOTHING;

-- 4. Seed Floors
INSERT INTO public.floors (id, name) VALUES
  ('d1111111-1111-1111-1111-111111111111', '1st Floor'),
  ('d2222222-2222-2222-2222-222222222222', '2nd Floor'),
  ('d3333333-3333-3333-3333-333333333333', '3rd Floor')
ON CONFLICT (name) DO NOTHING;

-- 5. Seed Rooms
INSERT INTO public.rooms (id, code, name, building_id, department_id, floor_id, room_type_id, seats, status, qr_code_data) VALUES
  ('e1111111-1111-1111-1111-111111111111', 'RM101', 'Room 101 - IT Lab', 'b1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 40, 'available', 'ROOM-101-ITLAB'),
  ('e2222222-2222-2222-2222-222222222222', 'RM201', 'Room 201 - Engineering Lab', 'b2222222-2222-2222-2222-222222222222', 'a2222222-2222-2222-2222-222222222222', 'd2222222-2222-2222-2222-222222222222', 'c1111111-1111-1111-1111-111111111111', 35, 'available', 'ROOM-201-ENGLAB'),
  ('e3333333-3333-3333-3333-333333333333', 'RM301', 'Room 301 - Administration Office', 'b4444444-4444-4444-4444-444444444444', NULL, 'd3333333-3333-3333-3333-333333333333', 'c4444444-4444-4444-4444-444444444444', 15, 'available', 'ROOM-301-ADMOFF')
ON CONFLICT (code) DO NOTHING;

-- 6. Seed Request Types
INSERT INTO public.request_types (id, name) VALUES
  ('f1111111-1111-1111-1111-111111111111', 'Electrical'),
  ('f2222222-2222-2222-2222-222222222222', 'Plumbing'),
  ('f3333333-3333-3333-3333-333333333333', 'Air Conditioning / HVAC'),
  ('f4444444-4444-4444-4444-444444444444', 'Carpentry / Furniture'),
  ('f5555555-5555-5555-5555-555555555555', 'IT Hardware / Network'),
  ('f6666666-6666-6666-6666-666666666666', 'Ocular Inspection'),
  ('f7777777-7777-7777-7777-777777777777', 'Others')
ON CONFLICT (name) DO NOTHING;
