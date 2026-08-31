-- SQL Script to fix the RLS SELECT policy on the users table.
-- Run this in your Supabase SQL Editor.
-- This allows authenticated Faculty and Maintenance users to read the public profile info (such as names) of other participants, resolving the issue where the Admin's name appears as "User".

DROP POLICY IF EXISTS users_select_policy ON public.users;

CREATE POLICY users_select_policy ON public.users
FOR SELECT TO authenticated
USING (true);
