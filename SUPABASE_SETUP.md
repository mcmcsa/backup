# Supabase Setup Guide

This guide walks you through the complete Supabase setup for the PSU Maintenance System.

---

## Step 1: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up/log in.
2. Click **New Project** and fill in:
   - **Project Name**: `psu-maintsystem`
   - **Database Password**: a strong password
   - **Region**: closest to your users
3. Click **Create new project** and wait ~2 minutes for initialization.

---

## Step 2: Get Your API Keys

1. Go to **Settings → API**.
2. Copy:
   - **Project URL** (e.g. `https://xxxx.supabase.co`)
   - **anon / public** key

---

## Step 3: Configure Credentials

**Option A – `.env` file (recommended)**

Create `.env` in the project root:
```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

**Option B – edit the config file directly**

Open `lib/config/supabase_config.dart` and replace the placeholder values:
```dart
const String supabaseUrl = 'https://your-project-id.supabase.co';
const String supabaseAnonKey = 'your-anon-key';
```

The app will use the `.env` values when present and fall back to the config file.

---

## Step 4: Run the Database Migration

1. In the Supabase dashboard, open **SQL Editor → New Query**.
2. Copy and paste the contents of:
   ```
   supabase/migrations/001_initial_schema.sql
   ```
3. Click **Run**.

This creates the following tables, triggers, indexes, and Row Level Security policies:

### Tables

| Table | Description |
|-------|-------------|
| `profiles` | User profiles (extends Supabase `auth.users`). Auto-created by trigger on sign-up. |
| `work_requests` | Maintenance/repair tickets submitted by students, teachers, or staff. |
| `rooms` | Physical rooms (labs, lecture halls, seminar rooms). |
| `room_schedules` | Time-slot reservations for each room. |

### Relationships

```
auth.users ──< profiles          (1-to-1, cascade delete)
rooms      ──< room_schedules    (1-to-many, cascade delete)
```

### Column summary

**`profiles`**
```
id UUID PK (→ auth.users), email, name,
role TEXT ('admin' | 'student_teacher' | 'maintenance'),
campus, department, position, profile_image,
created_at, updated_at
```

**`work_requests`**
```
id UUID PK, title, description,
status TEXT ('pending' | 'ongoing' | 'done' | 'cancelled'),
priority TEXT ('low' | 'medium' | 'high'),
campus, building_name, department, office_room, type_of_request,
date_submitted, date_completed,
requestor_name, requestor_position,
approved_by, approved_date,
reported_by, work_evidence, maintenance_notes,
created_at, updated_at
```

**`rooms`**
```
id UUID PK, name, building, floor, seats, department,
room_type TEXT ('Laboratory' | 'Lecture Hall' | 'Seminar Room' | 'Office' | 'Other'),
status TEXT ('available' | 'reserved' | 'maintenance'),
image_url, description, created_at, updated_at
```

**`room_schedules`**
```
id UUID PK, room_id UUID FK → rooms,
subject_name, instructor, scheduled_date DATE,
start_time TEXT, end_time TEXT,
is_maintenance_window BOOLEAN,
notes, status TEXT ('scheduled' | 'confirmed' | 'cancelled'),
created_at, updated_at
```

### Row Level Security (RLS)

| Table | Authenticated users | Admins | Maintenance |
|-------|---------------------|--------|-------------|
| `profiles` | Read/update own row | Read all | — |
| `work_requests` | Read all, insert | Read/update/delete | Read/update |
| `rooms` | Read | Full CRUD | — |
| `room_schedules` | Read | Full CRUD | — |

---

## Step 5: Enable Email/Password Authentication

1. Go to **Authentication → Providers**.
2. Ensure **Email** is enabled.
3. (Optional) Disable "Confirm email" during development under **Authentication → Settings**.

---

## Step 6: (Optional) Create an Admin User

Run this SQL to promote an existing user to admin after they sign up:

```sql
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'your-admin@email.com';
```

---

## Step 7: Install Dependencies and Run

```bash
flutter pub get
flutter run
```


## Step 1: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up or log in
2. Click "New Project" in the dashboard
3. Fill in the project details:
   - **Project Name**: `psu-maintsystem` (or your preferred name)
   - **Database Password**: Create a strong password
   - **Region**: Choose your closest region
4. Click "Create new project" and wait for initialization (2-3 minutes)

## Step 2: Get Your API Keys

1. Once your project is created, go to **Settings** > **API**
2. Copy your project credentials:
   - **Project URL** (under "Project URL")
   - **Anonymous Key** (under "Your anon key is")

## Step 3: Configure Environment Variables

1. Create a `.env` file in the project root (copy from `.env.example`):
   ```bash
   cp .env.example .env
   ```

2. Replace the placeholders with your actual credentials:
   ```
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-anonymous-key-here
   ```

## Step 4: Get Dependencies

Run the following command to install all dependencies:

```bash
flutter pub get
```

## Step 5: Set Up Authentication (Optional but Recommended)

### Enable Email/Password Auth:
1. In Supabase dashboard, go to **Authentication** > **Providers**
2. Make sure "Email" provider is enabled
3. Configure email settings in **Email Templates** if desired

### Enable Google Sign-In (Optional):
1. Set up OAuth credentials in Google Cloud Console
2. Add credentials to Supabase Authentication

## Step 6: Create Database Tables

If you want to store maintenance records, create tables in Supabase SQL editor:

```sql
-- Users table (extends Supabase auth)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT UNIQUE,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Maintenance tickets table (example)
CREATE TABLE public.maintenance_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'open',
  priority TEXT DEFAULT 'medium',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Set up Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_requests ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own profile
CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Allow users to read their own maintenance requests
CREATE POLICY "Users can read own requests" ON public.maintenance_requests
  FOR SELECT USING (auth.uid() = user_id);

-- Allow anyone to create maintenance requests
CREATE POLICY "Anyone can create requests" ON public.maintenance_requests
  FOR INSERT WITH CHECK (true);
```

## Step 7: Run the App

```bash
flutter run
```

The app will now use Supabase for authentication and data operations.

## Available Methods in SupabaseService

### Authentication
- `signUp(email, password)` - Create a new user account
- `signIn(email, password)` - Log in a user
- `signOut()` - Log out the current user
- `resetPassword(email)` - Send password reset email
- `authStateChanges()` - Stream of auth state changes
- `isAuthenticated` - Check if user is logged in
- `currentUser` - Get current user object

### Database Operations
- `insert(table, data)` - Insert data into a table
- `select(table, query)` - Get data from a table
- `update(table, data, where, value)` - Update records
- `delete(table, where, value)` - Delete records

### File Storage
- `uploadFile(bucket, path, fileBytes)` - Upload a file
- `downloadFile(bucket, path)` - Download a file
- `getSignedUrl(bucket, path, expiresIn)` - Get a signed URL

## Example Usage

```dart
import 'package:psu_maintsystem/config/supabase_service.dart';

// Sign up
try {
  await SupabaseService.signUp(
    email: 'user@example.com',
    password: 'securepassword',
  );
  print('Sign up successful!');
} catch (e) {
  print('Sign up failed: $e');
}

// Insert data
await SupabaseService.insert(
  table: 'maintenance_requests',
  data: {
    'title': 'Fix broken door',
    'description': 'Main entrance door lock is broken',
    'status': 'open',
  },
);

// Get data
final requests = await SupabaseService.select(
  table: 'maintenance_requests',
  query: '*',
);
```

## Troubleshooting

### "Failed to initialize Supabase"
- Check that your `.env` file has the correct URL and API key
- Verify the .env file is included in `pubspec.yaml` assets

### "401 Unauthorized"
- Make sure you're using the anonymous key, not the service role key
- Check that Row Level Security policies are correctly configured

### "Cannot find .env file"
- Ensure `.env` file exists in the project root (not in lib folder)
- Run `flutter pub get` after creating the file

## Next Steps

- Set up row-level security policies for your tables
- Configure email templates for authentication emails
- Set up backup and monitoring in Supabase dashboard
- Consider adding more authentication providers (Google, GitHub, etc.)

## Resources

- [Supabase Flutter Documentation](https://supabase.com/docs/reference/flutter/introduction)
- [Supabase Authentication Guide](https://supabase.com/docs/guides/auth)
- [Supabase Database Guide](https://supabase.com/docs/guides/database)
